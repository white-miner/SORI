-- 083: E1 — case_bookmarks SSOT + toggle + feed bookmark signal

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) case_bookmarks
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.case_bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  chart_id uuid not null references public.customer_charts (id) on delete cascade,
  folder text not null default 'default',
  created_at timestamptz not null default now(),
  unique (user_id, chart_id)
);

create index if not exists idx_case_bookmarks_user
  on public.case_bookmarks (user_id, created_at desc);

create index if not exists idx_case_bookmarks_chart
  on public.case_bookmarks (chart_id, created_at desc);

comment on table public.case_bookmarks is
  'User-scoped case bookmarks (보관함 SSOT).';

alter table public.case_bookmarks enable row level security;
drop policy if exists "mvp_case_bookmarks_all" on public.case_bookmarks;
create policy "mvp_case_bookmarks_all"
  on public.case_bookmarks for all using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) toggle_case_bookmark
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.toggle_case_bookmark(
  p_chart_id uuid,
  p_folder text default 'default'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_folder text := coalesce(nullif(trim(p_folder), ''), 'default');
  v_shop uuid;
  v_nickname text;
  v_bookmarked boolean;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_chart_id is null then
    raise exception 'chart_id required';
  end if;
  if not exists (select 1 from public.customer_charts where id = p_chart_id) then
    raise exception 'chart not found';
  end if;

  if exists (
    select 1 from public.case_bookmarks
    where user_id = v_uid and chart_id = p_chart_id
  ) then
    delete from public.case_bookmarks
    where user_id = v_uid and chart_id = p_chart_id;
    v_bookmarked := false;
  else
    insert into public.case_bookmarks (user_id, chart_id, folder)
    values (v_uid, p_chart_id, v_folder)
    on conflict (user_id, chart_id) do nothing;
    v_bookmarked := true;

    select cc.shop_id into v_shop
    from public.customer_charts cc where cc.id = p_chart_id;

    select coalesce(nullif(trim(p.nickname), ''), '팔로워')
    into v_nickname
    from public.profiles p where p.id = v_uid;

    if v_shop is not null then
      insert into public.shop_notifications (
        shop_id, kind, title, body, payload
      ) values (
        v_shop,
        'case_bookmark',
        '케이스 저장 알림',
        format('%s님이 케이스를 보관함에 저장했습니다', v_nickname),
        jsonb_build_object(
          'chart_id', p_chart_id,
          'user_id', v_uid,
          'folder', v_folder
        )
      );
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'chart_id', p_chart_id,
    'bookmarked', v_bookmarked,
    'folder', v_folder
  );
end;
$$;

grant execute on function public.toggle_case_bookmark(uuid, text)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) list_my_case_bookmark_ids
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_my_case_bookmark_ids(p_limit int default 200)
returns table (
  chart_id uuid,
  folder text,
  created_at timestamptz
)
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
    raise exception 'auth required';
  end if;

  return query
  select b.chart_id, b.folder, b.created_at
  from public.case_bookmarks b
  where b.user_id = v_uid
  order by b.created_at desc
  limit v_limit;
end;
$$;

grant execute on function public.list_my_case_bookmark_ids(int)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) get_chart_bookmark_counts — batch public counts
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.get_chart_bookmark_counts(
  p_chart_ids uuid[]
)
returns table (
  chart_id uuid,
  bookmark_count int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    b.chart_id,
    count(*)::int as bookmark_count
  from public.case_bookmarks b
  where b.chart_id = any (coalesce(p_chart_ids, '{}'::uuid[]))
  group by b.chart_id;
$$;

grant execute on function public.get_chart_bookmark_counts(uuid[])
  to anon, authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) Feed scoring — bookmark signal (+0.08 max)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_boost_candidates_scored(
  p_segment text default 'case',
  p_limit int default 200
)
returns table (
  placement_id uuid,
  target_type text,
  target_id uuid,
  source text,
  points_spent int,
  starts_at timestamptz,
  ends_at timestamptz,
  fandom_echo int,
  paid_ratio numeric,
  recency numeric,
  fan_bonus numeric,
  score numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_seg text := lower(trim(coalesce(p_segment, 'case')));
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
  v_tau double precision := 12.0;
begin
  perform public.expire_stale_boost_placements();
  perform public.expire_stale_premium_overlays();

  return query
  with active as (
    select bp.*
    from public.boost_placements bp
    where bp.status = 'active'
      and bp.ends_at > now()
      and public.boost_feed_segment(bp.target_type, bp.target_id) = v_seg
  ),
  fandom as (
    select
      bp.target_type,
      bp.target_id,
      sum(bp.points_spent)::int as echo_sum
    from public.boost_placements bp
    where bp.source = 'fan_boost'
    group by bp.target_type, bp.target_id
  ),
  overlay as (
    select
      o.target_type,
      o.target_id,
      max(case o.tier when 'platinum' then 0.22 when 'gold' then 0.12 else 0 end)::numeric
        as tier_bonus
    from public.boost_premium_overlays o
    where o.status = 'active' and o.ends_at > now()
    group by o.target_type, o.target_id
  ),
  bookmarks as (
    select
      b.chart_id as tid,
      count(*)::int as cnt
    from public.case_bookmarks b
    group by b.chart_id
  )
  select
    a.id,
    a.target_type,
    a.target_id,
    a.source,
    a.points_spent,
    a.starts_at,
    a.ends_at,
    coalesce(f.echo_sum, 0)::int as fandom_echo,
    (case when a.source = 'fan_boost' then 0.85 else 0.55 end)::numeric
      as paid_ratio,
    (exp(
      - greatest(0, extract(epoch from (now() - a.starts_at)) / 3600.0) / v_tau
    ))::numeric as recency,
    (case when a.source = 'fan_boost' then 1.0 else 0.45 end)::numeric
      as fan_bonus,
    (
      0.36 * least(
        1.0,
        ln(1 + coalesce(f.echo_sum, 0)::double precision) / ln(1 + 5000)
      )
      + 0.22 * (case when a.source = 'fan_boost' then 0.85 else 0.55 end)
      + 0.18 * exp(
        - greatest(0, extract(epoch from (now() - a.starts_at)) / 3600.0) / v_tau
      )
      + 0.14 * (case when a.source = 'fan_boost' then 1.0 else 0.45 end)
      + 0.10 * least(
        1.0,
        ln(1 + coalesce(bk.cnt, 0)::double precision) / ln(1 + 200)
      )
      + coalesce(ov.tier_bonus, 0)
    )::numeric as score
  from active a
  left join fandom f
    on f.target_type = a.target_type
   and f.target_id = a.target_id
  left join overlay ov
    on ov.target_type = a.target_type
   and ov.target_id = a.target_id
  left join bookmarks bk
    on a.target_type = 'chart'
   and bk.tid = a.target_id
  order by score desc, a.starts_at desc
  limit v_limit;
end;
$$;
