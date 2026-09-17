-- 052: Ecosystem integrity — gold_plus RLS/safe feed, transactional case publish, affiliate conversions

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Viewer tier helpers + gold_plus RLS + safe list RPC
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.shop_tier_rank(p_badge text)
returns int
language sql
immutable
as $$
  select case lower(trim(replace(coalesce(p_badge, 'none'), ' ', '_')))
    when 'iron' then 1
    when 'bronze' then 2
    when 'silver' then 3
    when 'gold' then 4
    when 'platinum' then 5
    when 'diamond' then 6
    when 'mentor' then 7
    when 'master' then 8
    when 'grand_master' then 9
    when 'grand_director' then 10
    else 0
  end;
$$;

create or replace function public.viewer_shop_tier_rank()
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select public.shop_tier_rank(s.tier_badge::text)
      from public.shops s
      where s.owner_user_id = auth.uid()
      order by s.updated_at desc nulls last
      limit 1
    ),
    0
  );
$$;

create or replace function public.viewer_owns_shop(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.shops s
    where s.id = p_shop_id
      and s.owner_user_id is not null
      and s.owner_user_id = auth.uid()
  );
$$;

create or replace function public.can_view_community_post_full(
  p_visibility text,
  p_shop_id uuid,
  p_author_user_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if coalesce(p_visibility, 'public') is distinct from 'gold_plus' then
    return true;
  end if;
  if auth.uid() is not null and p_author_user_id is not null
     and p_author_user_id = auth.uid() then
    return true;
  end if;
  if public.viewer_owns_shop(p_shop_id) then
    return true;
  end if;
  return public.viewer_shop_tier_rank() >= 4; -- gold+
end;
$$;

comment on function public.can_view_community_post_full(text, uuid, uuid) is
  'gold_plus 본문 열람: 작성자/소유 샵/뷰어 티어≥gold';

-- Base table: gold_plus full row only for unlocked viewers.
-- Listing of locked cards goes through list_community_posts_safe (security definer).
drop policy if exists "mvp_community_posts_select" on public.community_posts;
drop policy if exists "community_posts_select_visible" on public.community_posts;
create policy "community_posts_select_visible"
  on public.community_posts
  for select
  using (
    public.can_view_community_post_full(visibility, shop_id, author_user_id)
  );

-- Keep write policies open for MVP (auth tightening later).
drop policy if exists "mvp_community_posts_insert" on public.community_posts;
drop policy if exists "mvp_community_posts_update" on public.community_posts;
drop policy if exists "mvp_community_posts_delete" on public.community_posts;
create policy "mvp_community_posts_insert"
  on public.community_posts for insert with check (true);
create policy "mvp_community_posts_update"
  on public.community_posts for update using (true);
create policy "mvp_community_posts_delete"
  on public.community_posts for delete using (true);

-- Media: only when parent body is unlocked.
drop policy if exists "mvp_post_media_all" on public.post_media;
drop policy if exists "post_media_select_unlocked" on public.post_media;
drop policy if exists "post_media_write_mvp" on public.post_media;
create policy "post_media_select_unlocked"
  on public.post_media
  for select
  using (
    exists (
      select 1
      from public.community_posts p
      where p.id = post_id
        and public.can_view_community_post_full(
          p.visibility, p.shop_id, p.author_user_id
        )
    )
  );
create policy "post_media_write_mvp"
  on public.post_media for all using (true) with check (true);

-- Safe feed RPC: always returns title/author; masks body+media when locked.
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
          when public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id
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
          p.visibility, p.shop_id, p.author_user_id
        ),
        'shops', jsonb_build_object(
          'id', s.id,
          'name', s.name,
          'owner_name', s.owner_name,
          'tier_badge', s.tier_badge::text,
          'profile_image_url', s.profile_image_url
        ),
        'post_media', case
          when public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id
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
  'Community 피드 SSOT — gold_plus 본문/미디어 마스킹 + is_body_locked.';

grant execute on function public.shop_tier_rank(text) to anon, authenticated, public;
grant execute on function public.viewer_shop_tier_rank() to anon, authenticated, public;
grant execute on function public.viewer_owns_shop(uuid) to anon, authenticated, public;
grant execute on function public.can_view_community_post_full(text, uuid, uuid)
  to anon, authenticated, public;
grant execute on function public.list_community_posts_safe(text, int)
  to anon, authenticated, public;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Transactional chart share → case_share
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.save_chart_and_publish_case(
  p_chart_id uuid,
  p_shop_id uuid,
  p_publish boolean default true,
  p_title text default null,
  p_body text default null,
  p_image_urls text[] default '{}',
  p_author_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chart public.customer_charts%rowtype;
  v_post_id uuid;
  v_title text;
  v_body text;
  v_urls text[];
  v_url text;
  v_ord int := 0;
  v_existing uuid;
begin
  if p_chart_id is null or p_shop_id is null then
    raise exception 'chart_id and shop_id required';
  end if;

  select * into v_chart
  from public.customer_charts
  where id = p_chart_id
  for update;

  if not found then
    raise exception 'chart not found: %', p_chart_id;
  end if;

  if v_chart.shop_id is distinct from p_shop_id then
    raise exception 'shop_id mismatch for chart';
  end if;

  if not coalesce(p_publish, false) then
    update public.customer_charts
    set is_case_shared = false,
        case_shared = false,
        updated_at = now()
    where id = p_chart_id;
    return jsonb_build_object(
      'chart_id', p_chart_id,
      'published', false,
      'post_id', null
    );
  end if;

  -- All-or-nothing publish flag + case_share row
  update public.customer_charts
  set is_case_shared = true,
      case_shared = true,
      updated_at = now()
  where id = p_chart_id;

  select p.id into v_existing
  from public.community_posts p
  where p.source_chart_id = p_chart_id
    and p.post_type = 'case_share'
  order by p.created_at desc
  limit 1;

  if v_existing is not null then
    return jsonb_build_object(
      'chart_id', p_chart_id,
      'published', true,
      'post_id', v_existing,
      'deduped', true
    );
  end if;

  v_title := nullif(trim(coalesce(p_title, '')), '');
  if v_title is null then
    v_title := trim(coalesce(v_chart.care_name, '')) || ' · 임상 케이스';
    if trim(coalesce(v_chart.care_name, '')) = '' then
      v_title := '시술 케이스 · 임상 케이스';
    end if;
  end if;

  v_body := nullif(trim(coalesce(p_body, '')), '');
  if v_body is null then
    v_body := trim(both E'\n' from concat_ws(
      E'\n\n',
      nullif(trim(coalesce(v_chart.treatment_summary, '')), ''),
      nullif(trim(coalesce(v_chart.director_insight, '')), '')
    ));
    if v_body is null or v_body = '' then
      v_body := coalesce(nullif(trim(v_chart.care_name), ''), '시술')
        || ' 임상 기록 공유 (고객 정보는 비식별화되었습니다)';
    end if;
  end if;

  insert into public.community_posts (
    shop_id,
    author_user_id,
    post_type,
    title,
    body,
    style_tags,
    visibility,
    status,
    source_chart_id
  ) values (
    p_shop_id,
    p_author_user_id,
    'case_share',
    v_title,
    v_body,
    array['케이스공유', '비식별']::text[],
    'public',
    'published',
    p_chart_id
  )
  returning id into v_post_id;

  v_urls := coalesce(p_image_urls, '{}'::text[]);
  if coalesce(array_length(v_urls, 1), 0) = 0 then
    v_urls := array_remove(array[
      nullif(trim(coalesce(v_chart.before_image_url, '')), ''),
      nullif(trim(coalesce(v_chart.after_image_url, '')), '')
    ], null);
  end if;

  foreach v_url in array coalesce(v_urls, '{}'::text[])
  loop
    if v_url is null or length(trim(v_url)) = 0 then
      continue;
    end if;
    if v_url not like 'http%' and v_url not like 'data:%' then
      continue;
    end if;
    insert into public.post_media (post_id, image_url, sort_order)
    values (v_post_id, trim(v_url), v_ord);
    v_ord := v_ord + 1;
  end loop;

  return jsonb_build_object(
    'chart_id', p_chart_id,
    'published', true,
    'post_id', v_post_id,
    'deduped', false
  );
exception
  when others then
    -- Entire function runs in one transaction; re-raise to abort chart flag too.
    raise;
end;
$$;

comment on function public.save_chart_and_publish_case(uuid, uuid, boolean, text, text, text[], uuid) is
  '차트 is_case_shared + case_share 발행 All-or-Nothing.';

grant execute on function public.save_chart_and_publish_case(uuid, uuid, boolean, text, text, text[], uuid)
  to anon, authenticated, public;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Affiliate conversions + confirmed→paid settlement ledger
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.affiliate_conversions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  link_id uuid references public.affiliate_links (id) on delete set null,
  click_id uuid references public.affiliate_clicks (id) on delete set null,
  commission_id uuid references public.affiliate_commissions (id) on delete set null,
  post_id uuid references public.community_posts (id) on delete set null,
  order_ref text not null default '',
  gross_amount int not null default 0,
  commission_amount int not null default 0,
  currency text not null default 'KRW',
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'paid', 'void')),
  note text not null default '',
  confirmed_by uuid references public.profiles (id) on delete set null,
  confirmed_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_affiliate_conversions_shop_status
  on public.affiliate_conversions (shop_id, status, created_at desc);

comment on table public.affiliate_conversions is
  '구매 전환 정산 — Admin이 confirmed→paid 로 수수료 원장 확정.';

alter table public.affiliate_conversions enable row level security;
drop policy if exists "mvp_affiliate_conversions_all" on public.affiliate_conversions;
create policy "mvp_affiliate_conversions_all"
  on public.affiliate_conversions for all using (true) with check (true);

create or replace function public.sync_affiliate_conversion_commission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_commission_id uuid := new.commission_id;
  v_link_id uuid := new.link_id;
begin
  -- Ensure a commission row exists for confirmed/paid conversions.
  if new.status in ('confirmed', 'paid') then
    if v_commission_id is null then
      if v_link_id is null then
        insert into public.affiliate_links (
          shop_id, destination_url, label, commission_per_click, status
        ) values (
          new.shop_id,
          'conversion://' || new.id::text,
          coalesce(nullif(trim(new.order_ref), ''), '전환 정산'),
          greatest(new.commission_amount, 0),
          'active'
        )
        returning id into v_link_id;
        new.link_id := v_link_id;
      end if;

      insert into public.affiliate_commissions (
        shop_id,
        link_id,
        click_id,
        amount,
        currency,
        status,
        note
      ) values (
        new.shop_id,
        v_link_id,
        new.click_id,
        greatest(new.commission_amount, 0),
        new.currency,
        new.status,
        coalesce(nullif(trim(new.note), ''), 'from conversion ' || new.id::text)
      )
      returning id into v_commission_id;
      new.commission_id := v_commission_id;
    else
      update public.affiliate_commissions
      set amount = greatest(new.commission_amount, 0),
          status = new.status,
          updated_at = now(),
          note = case
            when nullif(trim(new.note), '') is null then note
            else new.note
          end
      where id = v_commission_id;
    end if;
  elsif new.status = 'void' and v_commission_id is not null then
    update public.affiliate_commissions
    set status = 'void', updated_at = now()
    where id = v_commission_id;
  end if;

  new.updated_at := now();
  if new.status = 'confirmed' and new.confirmed_at is null then
    new.confirmed_at := now();
  end if;
  if new.status = 'paid' and new.paid_at is null then
    new.paid_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_affiliate_conversion_settle on public.affiliate_conversions;
create trigger trg_affiliate_conversion_settle
  before insert or update of status, commission_amount, note
  on public.affiliate_conversions
  for each row execute function public.sync_affiliate_conversion_commission();

create or replace function public.record_affiliate_conversion(
  p_shop_id uuid,
  p_commission_amount int,
  p_order_ref text default '',
  p_gross_amount int default 0,
  p_link_id uuid default null,
  p_click_id uuid default null,
  p_post_id uuid default null,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.affiliate_conversions%rowtype;
begin
  insert into public.affiliate_conversions (
    shop_id,
    link_id,
    click_id,
    post_id,
    order_ref,
    gross_amount,
    commission_amount,
    status,
    note
  ) values (
    p_shop_id,
    p_link_id,
    p_click_id,
    p_post_id,
    coalesce(p_order_ref, ''),
    coalesce(p_gross_amount, 0),
    coalesce(p_commission_amount, 0),
    'pending',
    coalesce(p_note, '')
  )
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

create or replace function public.settle_affiliate_conversion(
  p_conversion_id uuid,
  p_to_status text,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.affiliate_conversions%rowtype;
  v_status text := lower(trim(coalesce(p_to_status, '')));
begin
  if v_status not in ('confirmed', 'paid', 'void', 'pending') then
    raise exception 'invalid status: %', p_to_status;
  end if;

  update public.affiliate_conversions
  set status = v_status,
      confirmed_by = coalesce(p_actor_user_id, confirmed_by),
      updated_at = now()
  where id = p_conversion_id
  returning * into v_row;

  if not found then
    raise exception 'conversion not found: %', p_conversion_id;
  end if;

  return to_jsonb(v_row);
end;
$$;

grant execute on function public.record_affiliate_conversion(
  uuid, int, text, int, uuid, uuid, uuid, text
) to anon, authenticated, public;
grant execute on function public.settle_affiliate_conversion(uuid, text, uuid)
  to anon, authenticated, public;
