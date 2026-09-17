-- 065_whisper_community_posts.sql
-- Whisper = targeted community_posts in feed (not separate Inbox/DM).
-- Reuses resolve_whisper_audience_users + whisper_audience_presets from 064.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Extend community_posts
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.community_posts
  add column if not exists is_whisper boolean not null default false,
  add column if not exists audience_spec jsonb,
  add column if not exists audience_op text
    check (audience_op is null or audience_op in ('union', 'intersect')),
  add column if not exists whisper_recipient_count int not null default 0
    check (whisper_recipient_count >= 0);

create index if not exists idx_community_posts_whisper_feed
  on public.community_posts (created_at desc)
  where is_whisper = true and status = 'published';

comment on column public.community_posts.is_whisper is
  'True = 속삭임 포스트. 피드에 노출되나 수신자만 본문 열람.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Materialized recipients (post-scoped)
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.community_whisper_recipients (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  atom_bits int not null default 0,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create index if not exists community_whisper_recipients_user_idx
  on public.community_whisper_recipients (user_id, created_at desc);

create index if not exists community_whisper_recipients_post_idx
  on public.community_whisper_recipients (post_id);

comment on table public.community_whisper_recipients is
  'Whisper post audience snapshot at publish. atom_bits: A1=1 A2=2 A3=4 A4=8 A5=16.';

alter table public.community_whisper_recipients enable row level security;

drop policy if exists community_whisper_recipients_select on public.community_whisper_recipients;
create policy community_whisper_recipients_select
  on public.community_whisper_recipients for select
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.community_posts p
      where p.id = post_id and p.author_user_id = auth.uid()
    )
  );

grant select on public.community_whisper_recipients to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Visibility helper
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.can_view_whisper_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select
        p.is_whisper = true
        and p.status = 'published'
        and (
          p.author_user_id = auth.uid()
          or exists (
            select 1
            from public.community_whisper_recipients r
            where r.post_id = p.id and r.user_id = auth.uid()
          )
        )
      from public.community_posts p
      where p.id = p_post_id
    ),
    false
  );
$$;

comment on function public.can_view_whisper_post(uuid) is
  'Whisper posts visible only to author + materialized recipients.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) send_whisper_post — publish to community_posts feed
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.send_whisper_post(
  p_body text,
  p_op text default 'union',
  p_atoms text[] default '{}',
  p_explicit_user_ids uuid[] default '{}',
  p_explicit_shop_ids uuid[] default '{}',
  p_shop_id uuid default null,
  p_max int default 500
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_op text := lower(trim(coalesce(p_op, 'union')));
  v_body text := left(trim(coalesce(p_body, '')), 2000);
  v_max int := greatest(1, least(coalesce(p_max, 500), 500));
  v_post_id uuid;
  v_count int := 0;
  v_full int := 0;
  v_truncated boolean := false;
  v_day_count int;
  v_spec jsonb;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if length(v_body) < 1 then
    raise exception 'body required';
  end if;
  if coalesce(array_length(p_atoms, 1), 0) < 1 then
    raise exception 'at least one audience atom required';
  end if;
  if v_op not in ('union', 'intersect') then
    v_op := 'union';
  end if;

  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;
  if v_shop is null
     or not exists (
       select 1 from public.shops s
       where s.id = v_shop
         and (
           s.owner_user_id = v_uid
           or exists (
             select 1 from public.shop_memberships m
             where m.shop_id = s.id and m.user_id = v_uid
           )
         )
     ) then
    raise exception 'shop access denied';
  end if;

  select count(*)::int into v_day_count
  from public.community_posts p
  where p.author_user_id = v_uid
    and p.is_whisper = true
    and p.status = 'published'
    and p.created_at > now() - interval '1 day';
  if coalesce(v_day_count, 0) >= 20 then
    raise exception 'daily whisper limit reached';
  end if;

  select count(*)::int into v_full
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, v_op, p_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, 501
  );
  if v_full > v_max then
    v_truncated := true;
  end if;

  v_spec := jsonb_build_object(
    'op', v_op,
    'atoms', to_jsonb(p_atoms),
    'explicit_user_ids', to_jsonb(coalesce(p_explicit_user_ids, '{}'::uuid[])),
    'explicit_shop_ids', to_jsonb(coalesce(p_explicit_shop_ids, '{}'::uuid[])),
    'shop_id', v_shop,
    'caps', jsonb_build_object('max_recipients', v_max)
  );

  insert into public.community_posts (
    shop_id,
    author_user_id,
    post_type,
    title,
    body,
    visibility,
    status,
    is_whisper,
    audience_spec,
    audience_op,
    whisper_recipient_count
  ) values (
    v_shop,
    v_uid,
    'case_share',
    '',
    v_body,
    'directors_only',
    'published',
    true,
    v_spec,
    v_op,
    0
  )
  returning id into v_post_id;

  insert into public.community_whisper_recipients (post_id, user_id, atom_bits)
  select v_post_id, r.user_id, r.atom_bits
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, v_op, p_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, v_max
  ) r
  on conflict (post_id, user_id) do nothing;

  get diagnostics v_count = row_count;

  if v_count < 1 then
    delete from public.community_posts where id = v_post_id;
    raise exception 'no recipients matched';
  end if;

  update public.community_posts
  set whisper_recipient_count = v_count, updated_at = now()
  where id = v_post_id;

  return jsonb_build_object(
    'ok', true,
    'post_id', v_post_id,
    'whisper_id', v_post_id,
    'recipient_count', v_count,
    'truncated', v_truncated,
    'op', v_op,
    'atoms', to_jsonb(p_atoms)
  );
end;
$$;

comment on function public.send_whisper_post(text, text, text[], uuid[], uuid[], uuid, int) is
  'Publish whisper as community_posts row + materialized recipients.';

grant execute on function public.send_whisper_post(text, text, text[], uuid[], uuid[], uuid, int)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) Patch list_community_posts_safe — whisper filter + metadata
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_community_posts_safe(
  p_post_type text default null,
  p_limit int default 40
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_result jsonb;
begin
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
          when p.is_whisper and not public.can_view_whisper_post(p.id) then ''
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
        'is_whisper', coalesce(p.is_whisper, false),
        'audience_spec', coalesce(p.audience_spec, '{}'::jsonb),
        'audience_op', p.audience_op,
        'whisper_recipient_count', coalesce(p.whisper_recipient_count, 0),
        'is_body_locked', case
          when p.is_whisper then not public.can_view_whisper_post(p.id)
          else not public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id, p.id
          )
        end,
        'unlock_cost', 500,
        'shops', jsonb_build_object(
          'id', s.id,
          'name', s.name,
          'owner_name', s.owner_name,
          'tier_badge', s.tier_badge::text,
          'profile_image_url', s.profile_image_url
        ),
        'post_media', case
          when p.is_whisper then '[]'::jsonb
          when public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id, p.id
          ) then coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', m.id,
                'post_id', m.post_id,
                'image_url', m.image_url,
                'sort_order', m.sort_order,
                'post_tags', coalesce((
                  select jsonb_agg(
                    jsonb_build_object(
                      'id', t.id,
                      'media_id', t.media_id,
                      'tag_kind', t.tag_kind,
                      'label', t.label,
                      'norm_x', t.norm_x,
                      'norm_y', t.norm_y,
                      'partner_id', t.partner_id,
                      'external_url', t.external_url,
                      'metadata', t.metadata
                    )
                    order by t.created_at
                  )
                  from public.post_tags t
                  where t.media_id = m.id
                ), '[]'::jsonb)
              )
              order by m.sort_order asc
            )
            from public.post_media m
            where m.post_id = p.id
          ), '[]'::jsonb)
          else '[]'::jsonb
        end,
        'device_reviews', coalesce((
          select jsonb_agg(to_jsonb(d))
          from public.device_reviews d
          where d.post_id = p.id
        ), '[]'::jsonb),
        'market_listings', coalesce((
          select jsonb_agg(to_jsonb(l))
          from public.market_listings l
          where l.post_id = p.id
        ), '[]'::jsonb)
      ) as row_data
    from public.community_posts p
    left join public.shops s on s.id = p.shop_id
    where p.status = 'published'
      and (
        coalesce(p.is_whisper, false) = false
        or public.can_view_whisper_post(p.id)
      )
      and (
        p_post_type is null
        or p_post_type = ''
        or p.post_type = p_post_type
      )
    order by p.created_at desc
    limit v_limit
  ) q;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

comment on function public.list_community_posts_safe(text, int) is
  'Community feed with Echo paywall + whisper audience filtering.';

grant execute on function public.list_community_posts_safe(text, int)
  to authenticated;
