-- 063_discover_subscriptions.sql
-- Discover / Following: subscriptions SSOT + following feed RPC.
-- Legacy shop_followers kept for CRM/tier; backfilled into subscriptions.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) subscriptions
-- ═══════════════════════════════════════════════════════════════════════════

-- Ensure is_seed exists (062) before discover directory join
alter table public.profiles
  add column if not exists is_seed boolean not null default false;

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  follower_user_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null
    check (target_type in ('shop', 'director')),
  target_shop_id uuid references public.shops (id) on delete cascade,
  target_user_id uuid references public.profiles (id) on delete cascade,
  source text not null default 'discover'
    check (source in (
      'discover', 'shop_page', 'chart', 'seed', 'legacy_backfill'
    )),
  notify_level text not null default 'all'
    check (notify_level in ('all', 'highlights', 'mute')),
  created_at timestamptz not null default now(),
  constraint subscriptions_target_check check (
    (
      target_type = 'shop'
      and target_shop_id is not null
    )
    or (
      target_type = 'director'
      and target_user_id is not null
    )
  )
);

create unique index if not exists subscriptions_follower_shop_uidx
  on public.subscriptions (follower_user_id, target_shop_id)
  where target_type = 'shop' and target_shop_id is not null;

create unique index if not exists subscriptions_follower_director_uidx
  on public.subscriptions (follower_user_id, target_user_id)
  where target_type = 'director' and target_user_id is not null;

create index if not exists subscriptions_follower_idx
  on public.subscriptions (follower_user_id, created_at desc);

create index if not exists subscriptions_shop_idx
  on public.subscriptions (target_shop_id)
  where target_shop_id is not null;

create index if not exists subscriptions_director_idx
  on public.subscriptions (target_user_id)
  where target_user_id is not null;

comment on table public.subscriptions is
  'Phase 11 Discover: user→shop|director follow. shop_followers remains CRM mirror.';

alter table public.subscriptions enable row level security;

drop policy if exists subscriptions_select_own on public.subscriptions;
create policy subscriptions_select_own
  on public.subscriptions for select
  using (
    follower_user_id = auth.uid()
    or target_user_id = auth.uid()
    or exists (
      select 1 from public.shops s
      where s.id = target_shop_id and s.owner_user_id = auth.uid()
    )
  );

drop policy if exists subscriptions_insert_own on public.subscriptions;
create policy subscriptions_insert_own
  on public.subscriptions for insert
  with check (follower_user_id = auth.uid());

drop policy if exists subscriptions_delete_own on public.subscriptions;
create policy subscriptions_delete_own
  on public.subscriptions for delete
  using (follower_user_id = auth.uid());

grant select, insert, delete on public.subscriptions to authenticated;
grant select on public.subscriptions to anon;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Backfill from shop_followers (customer.user_id → follower)
-- ═══════════════════════════════════════════════════════════════════════════

insert into public.subscriptions (
  follower_user_id, target_type, target_shop_id, source, created_at
)
select
  c.user_id,
  'shop',
  f.shop_id,
  'legacy_backfill',
  f.created_at
from public.shop_followers f
join public.customers c on c.id = f.customer_id
where c.user_id is not null
on conflict do nothing;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Dual-write: shop subscription ↔ shop_followers (best-effort)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.sync_subscription_to_shop_followers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
begin
  if tg_op = 'INSERT'
     and new.target_type = 'shop'
     and new.target_shop_id is not null then
    select c.id into v_customer_id
    from public.customers c
    where c.user_id = new.follower_user_id
      and c.shop_id = new.target_shop_id
    order by c.created_at desc
    limit 1;
    if v_customer_id is null then
      select c.id into v_customer_id
      from public.customers c
      where c.user_id = new.follower_user_id
      order by c.created_at desc
      limit 1;
    end if;
    if v_customer_id is not null then
      insert into public.shop_followers (shop_id, customer_id)
      values (new.target_shop_id, v_customer_id)
      on conflict (shop_id, customer_id) do nothing;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE'
     and old.target_type = 'shop'
     and old.target_shop_id is not null then
    delete from public.shop_followers f
    using public.customers c
    where f.shop_id = old.target_shop_id
      and f.customer_id = c.id
      and c.user_id = old.follower_user_id;
    return old;
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_sync_subscription_shop_followers on public.subscriptions;
create trigger trg_sync_subscription_shop_followers
  after insert or delete on public.subscriptions
  for each row
  execute function public.sync_subscription_to_shop_followers();

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) RPCs
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.set_subscription(
  p_target_type text,
  p_target_shop_id uuid default null,
  p_target_user_id uuid default null,
  p_following boolean default true,
  p_source text default 'discover'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_type text := lower(trim(coalesce(p_target_type, '')));
  v_src text := lower(trim(coalesce(p_source, 'discover')));
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if v_type not in ('shop', 'director') then
    raise exception 'invalid target_type';
  end if;
  if v_src not in ('discover', 'shop_page', 'chart', 'seed', 'legacy_backfill') then
    v_src := 'discover';
  end if;

  if not coalesce(p_following, true) then
    if v_type = 'shop' then
      delete from public.subscriptions
      where follower_user_id = v_uid
        and target_type = 'shop'
        and target_shop_id = p_target_shop_id;
    else
      delete from public.subscriptions
      where follower_user_id = v_uid
        and target_type = 'director'
        and target_user_id = p_target_user_id;
    end if;
    return jsonb_build_object('ok', true, 'following', false);
  end if;

  if v_type = 'shop' then
    if p_target_shop_id is null then
      raise exception 'target_shop_id required';
    end if;
    insert into public.subscriptions (
      follower_user_id, target_type, target_shop_id, source
    ) values (v_uid, 'shop', p_target_shop_id, v_src)
    on conflict do nothing;
  else
    if p_target_user_id is null then
      raise exception 'target_user_id required';
    end if;
    if p_target_user_id = v_uid then
      raise exception 'cannot follow self';
    end if;
    insert into public.subscriptions (
      follower_user_id, target_type, target_user_id, target_shop_id, source
    ) values (
      v_uid, 'director', p_target_user_id,
      (
        select s.id from public.shops s
        where s.owner_user_id = p_target_user_id
        order by s.created_at asc
        limit 1
      ),
      v_src
    )
    on conflict do nothing;
  end if;

  return jsonb_build_object('ok', true, 'following', true);
end;
$$;

create or replace function public.list_my_subscriptions(
  p_limit int default 200
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(s) order by s.created_at desc)
    from (
      select *
      from public.subscriptions
      where follower_user_id = v_uid
      order by created_at desc
      limit v_limit
    ) s
  ), '[]'::jsonb);
end;
$$;

-- Following feed: community posts from subscribed shops / directors
create or replace function public.list_following_feed(
  p_limit int default 40
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_result jsonb;
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_data order by sort_created desc), '[]'::jsonb)
  into v_result
  from (
    select
      p.created_at as sort_created,
      jsonb_build_object(
        'id', p.id,
        'shop_id', p.shop_id,
        'author_user_id', p.author_user_id,
        'post_type', p.post_type,
        'title', p.title,
        'body', case
          when public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id, p.id
          ) then p.body
          else ''
        end,
        'style_tags', p.style_tags,
        'region_code', p.region_code,
        'visibility', p.visibility,
        'status', p.status,
        'like_count', p.like_count,
        'comment_count', p.comment_count,
        'save_count', p.save_count,
        'source_chart_id', p.source_chart_id,
        'created_at', p.created_at,
        'updated_at', p.updated_at,
        'is_body_locked', not public.can_view_community_post_full(
          p.visibility, p.shop_id, p.author_user_id, p.id
        ),
        'unlock_cost', 500,
        'shops', jsonb_build_object(
          'id', s.id,
          'name', s.name,
          'owner_name', s.owner_name,
          'tier_badge', s.tier_badge::text,
          'profile_image_url', s.profile_image_url,
          'slug', s.slug,
          'is_official', s.is_official
        ),
        'author_nickname', coalesce(
          nullif(trim(ap.nickname), ''),
          nullif(trim(ap.name), ''),
          nullif(trim(s.owner_name), ''),
          'SORI'
        ),
        'post_media', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', m.id,
              'post_id', m.post_id,
              'image_url', m.image_url,
              'sort_order', m.sort_order
            )
            order by m.sort_order asc
          )
          from public.post_media m
          where m.post_id = p.id
        ), '[]'::jsonb)
      ) as row_data
    from public.community_posts p
    join public.shops s on s.id = p.shop_id
    left join public.profiles ap on ap.id = p.author_user_id
    where p.status = 'published'
      and exists (
        select 1
        from public.subscriptions sub
        where sub.follower_user_id = v_uid
          and (
            (sub.target_type = 'shop' and sub.target_shop_id = p.shop_id)
            or (
              sub.target_type = 'director'
              and sub.target_user_id is not null
              and (
                sub.target_user_id = p.author_user_id
                or sub.target_user_id = s.owner_user_id
              )
            )
          )
      )
    order by p.created_at desc
    limit v_limit
  ) q;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

-- Discover directory: public shops with owner nickname
create or replace function public.list_discover_directors(
  p_limit int default 40,
  p_query text default ''
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_q text := lower(trim(coalesce(p_query, '')));
begin
  return coalesce((
    select jsonb_agg(row_data order by sort_followers desc, sort_name)
    from (
      select
        coalesce(s.follower_count, 0) as sort_followers,
        lower(s.name) as sort_name,
        jsonb_build_object(
          'shop_id', s.id,
          'shop_name', s.name,
          'owner_user_id', s.owner_user_id,
          'owner_name', s.owner_name,
          'nickname', coalesce(
            nullif(trim(p.nickname), ''),
            nullif(trim(p.name), ''),
            nullif(trim(s.owner_name), ''),
            s.name
          ),
          'avatar_url', coalesce(
            nullif(trim(p.avatar_url), ''),
            nullif(trim(s.profile_image_url), '')
          ),
          'bio', left(coalesce(s.bio, ''), 120),
          'address', coalesce(s.address, ''),
          'follower_count', coalesce(s.follower_count, 0),
          'shared_case_count', coalesce(s.shared_case_count, 0),
          'is_official', coalesce(s.is_official, false),
          'slug', coalesce(s.slug, ''),
          'is_seed', coalesce(p.is_seed, false)
        ) as row_data
      from public.shops s
      left join public.profiles p on p.id = s.owner_user_id
      where coalesce(s.is_official, false) = false
        and (
          v_q = ''
          or lower(s.name) like '%' || v_q || '%'
          or lower(coalesce(s.owner_name, '')) like '%' || v_q || '%'
          or lower(coalesce(p.nickname, '')) like '%' || v_q || '%'
          or lower(coalesce(p.name, '')) like '%' || v_q || '%'
          or lower(coalesce(s.address, '')) like '%' || v_q || '%'
        )
      order by coalesce(s.follower_count, 0) desc, s.name asc
      limit v_limit
    ) q
  ), '[]'::jsonb);
end;
$$;

grant execute on function public.set_subscription(text, uuid, uuid, boolean, text)
  to authenticated;
grant execute on function public.list_my_subscriptions(int)
  to authenticated, anon;
grant execute on function public.list_following_feed(int)
  to authenticated, anon;
grant execute on function public.list_discover_directors(int, text)
  to authenticated, anon;
