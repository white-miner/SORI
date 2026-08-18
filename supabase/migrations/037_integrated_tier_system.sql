-- 037: 1~10등급 통합 티어 · 메트릭 동기화 · 에스크로 변동 수수료 · 그랜드 디렉터 연간 갱신

-- 1) 메트릭 컬럼
alter table public.shops
  add column if not exists total_likes int not null default 0,
  add column if not exists shared_case_count int not null default 0,
  add column if not exists seminar_request_count int not null default 0,
  add column if not exists completed_seminar_count int not null default 0,
  add column if not exists follower_count int not null default 0;

alter table public.shops
  add column if not exists total_funding_amount int not null default 0,
  add column if not exists total_seminar_count int not null default 0,
  add column if not exists tier_badge text not null default 'none';

comment on column public.shops.total_likes is '공유 차트 누적 좋아요 (chart_likes)';
comment on column public.shops.shared_case_count is '동의 완료 공유 차트 수';
comment on column public.shops.seminar_request_count is '내 차트에 쌓인 세미나 요청 수';
comment on column public.shops.completed_seminar_count is 'status=completed 세미나 클래스 수';
comment on column public.shops.follower_count is 'shop_followers 카운트 캐시';

-- 2) 차트 좋아요 (total_likes 원천)
create table if not exists public.chart_likes (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.customer_charts (id) on delete cascade,
  liker_key text not null default '',
  created_at timestamptz not null default now(),
  unique (chart_id, liker_key)
);

create index if not exists idx_chart_likes_chart
  on public.chart_likes (chart_id);

alter table public.chart_likes enable row level security;
drop policy if exists "mvp_chart_likes_all" on public.chart_likes;
create policy "mvp_chart_likes_all"
  on public.chart_likes for all using (true) with check (true);

-- 3) 기존 티어 값 → 10단계 소문자 매핑
update public.shops
set tier_badge = case lower(trim(tier_badge))
  when 'bronze' then 'bronze'
  when 'silver' then 'silver'
  when 'gold' then 'gold'
  when 'master' then 'master'
  when 'iron' then 'iron'
  when 'platinum' then 'platinum'
  when 'diamond' then 'diamond'
  when 'mentor' then 'mentor'
  when 'grand_master' then 'grand_master'
  when 'grandmaster' then 'grand_master'
  when 'grand_director' then 'grand_director'
  when 'granddirector' then 'grand_director'
  else 'none'
end;

-- 4) PG enum (none + 10등급)
do $$
begin
  if not exists (select 1 from pg_type where typname = 'shop_tier_badge') then
    create type public.shop_tier_badge as enum (
      'none',
      'iron',
      'bronze',
      'silver',
      'gold',
      'platinum',
      'diamond',
      'mentor',
      'master',
      'grand_master',
      'grand_director'
    );
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'shops'
      and column_name = 'tier_badge'
      and udt_name = 'text'
  ) then
    alter table public.shops alter column tier_badge drop default;
    alter table public.shops
      alter column tier_badge type public.shop_tier_badge
      using (
        case lower(trim(tier_badge::text))
          when 'iron' then 'iron'
          when 'bronze' then 'bronze'
          when 'silver' then 'silver'
          when 'gold' then 'gold'
          when 'platinum' then 'platinum'
          when 'diamond' then 'diamond'
          when 'mentor' then 'mentor'
          when 'master' then 'master'
          when 'grand_master' then 'grand_master'
          when 'grand_director' then 'grand_director'
          else 'none'
        end
      )::public.shop_tier_badge;
    alter table public.shops
      alter column tier_badge set default 'none'::public.shop_tier_badge;
  end if;
end $$;

comment on column public.shops.tier_badge is
  '통합 티어: none | iron~diamond(소셜) | mentor~grand_director(비즈니스)';

-- 5) 메트릭 재집계
create or replace function public.sync_shop_tier_metrics(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_likes int;
  v_shared int;
  v_requests int;
  v_completed int;
  v_funding int;
  v_followers int;
begin
  if p_shop_id is null then
    return;
  end if;

  select count(*)::int into v_shared
  from public.customer_charts c
  where c.shop_id = p_shop_id
    and c.is_case_shared = true
    and (
      coalesce(c.signature_url, '') <> ''
      or coalesce(c.consent_pdf_url, '') <> ''
    );

  select count(*)::int into v_likes
  from public.chart_likes l
  inner join public.customer_charts c on c.id = l.chart_id
  where c.shop_id = p_shop_id;

  select count(*)::int into v_requests
  from public.seminar_requests r
  inner join public.customer_charts c on c.id = r.case_id
  where c.shop_id = p_shop_id;

  select count(*)::int into v_completed
  from public.seminar_classes sc
  where sc.director_shop_id = p_shop_id
    and sc.status = 'completed';

  select coalesce(sum(
    greatest(0, coalesce(sc.current_enrollment, 0) * coalesce(sc.price, 0))
  ), 0)::int into v_funding
  from public.seminar_classes sc
  where sc.director_shop_id = p_shop_id
    and sc.status = 'completed';

  select count(*)::int into v_followers
  from public.shop_followers f
  where f.shop_id = p_shop_id;

  update public.shops
  set
    total_likes = coalesce(v_likes, 0),
    shared_case_count = coalesce(v_shared, 0),
    seminar_request_count = coalesce(v_requests, 0),
    completed_seminar_count = coalesce(v_completed, 0),
    total_seminar_count = coalesce(v_completed, 0),
    total_funding_amount = coalesce(v_funding, 0),
    follower_count = coalesce(v_followers, 0),
    updated_at = now()
  where id = p_shop_id;
end;
$$;

-- 6) 최근 365일 완료 세미나 펀딩
create or replace function public.shop_rolling_12m_funding(p_shop_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(
    greatest(0, coalesce(sc.current_enrollment, 0) * coalesce(sc.price, 0))
  ), 0)::int
  from public.seminar_classes sc
  where sc.director_shop_id = p_shop_id
    and sc.status = 'completed'
    and coalesce(sc.updated_at, sc.created_at) >= (now() - interval '365 days');
$$;

-- 7) 티어 자동 승급 (비즈니스 트랙이 소셜을 점프)
create or replace function public.update_shop_tier_badge(p_shop_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shared int;
  v_likes int;
  v_followers int;
  v_requests int;
  v_seminars int;
  v_funding int;
  v_rolling int;
  v_social text := 'none';
  v_business text := 'none';
  v_badge text := 'none';
begin
  if p_shop_id is null then
    return 'none';
  end if;

  perform public.sync_shop_tier_metrics(p_shop_id);

  select
    coalesce(s.shared_case_count, 0),
    coalesce(s.total_likes, 0),
    coalesce(s.follower_count, 0),
    coalesce(s.seminar_request_count, 0),
    coalesce(s.completed_seminar_count, 0),
    coalesce(s.total_funding_amount, 0)
  into v_shared, v_likes, v_followers, v_requests, v_seminars, v_funding
  from public.shops s
  where s.id = p_shop_id;

  if not found then
    return 'none';
  end if;

  v_rolling := public.shop_rolling_12m_funding(p_shop_id);

  -- 소셜 트랙 (공유 AND 좋아요 AND 팔로워)
  if v_shared >= 100 and v_likes >= 1200 and v_followers >= 500 then
    v_social := 'diamond';
  elsif v_shared >= 70 and v_likes >= 700 and v_followers >= 250 then
    v_social := 'platinum';
  elsif v_shared >= 45 and v_likes >= 350 and v_followers >= 120 then
    v_social := 'gold';
  elsif v_shared >= 25 and v_likes >= 150 and v_followers >= 60 then
    v_social := 'silver';
  elsif v_shared >= 10 and v_likes >= 60 and v_followers >= 25 then
    v_social := 'bronze';
  elsif v_shared >= 3 and v_likes >= 15 and v_followers >= 5 then
    v_social := 'iron';
  else
    v_social := 'none';
  end if;

  -- 비즈니스 트랙 (요청 AND 개최 AND 펀딩) — 충족 시 소셜 무시 점프
  if v_requests >= 1000 and v_seminars >= 100 and v_rolling >= 100000000 then
    v_business := 'grand_director';
  elsif v_requests >= 200 and v_seminars >= 50 and v_funding >= 20000000 then
    v_business := 'grand_master';
  elsif v_requests >= 50 and v_seminars >= 10 and v_funding >= 5000000 then
    v_business := 'master';
  elsif v_requests >= 10 and v_seminars >= 1 then
    v_business := 'mentor';
  else
    v_business := 'none';
  end if;

  if v_business <> 'none' then
    v_badge := v_business;
  else
    v_badge := v_social;
  end if;

  update public.shops
  set tier_badge = v_badge::public.shop_tier_badge,
      updated_at = now()
  where id = p_shop_id;

  return v_badge;
end;
$$;

-- 레거시 별칭
create or replace function public.refresh_shop_tier_badge(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.update_shop_tier_badge(p_shop_id);
end;
$$;

create or replace function public.compute_shop_tier_badge(p_shared_count int)
returns text
language sql
immutable
as $$
  -- 레거시 시그니처 유지. 실제 승급은 update_shop_tier_badge 사용.
  select case
    when coalesce(p_shared_count, 0) >= 100 then 'diamond'
    when coalesce(p_shared_count, 0) >= 70 then 'platinum'
    when coalesce(p_shared_count, 0) >= 45 then 'gold'
    when coalesce(p_shared_count, 0) >= 25 then 'silver'
    when coalesce(p_shared_count, 0) >= 10 then 'bronze'
    when coalesce(p_shared_count, 0) >= 3 then 'iron'
    else 'none'
  end;
$$;

grant execute on function public.sync_shop_tier_metrics(uuid) to anon, authenticated, public;
grant execute on function public.shop_rolling_12m_funding(uuid) to anon, authenticated, public;
grant execute on function public.update_shop_tier_badge(uuid) to anon, authenticated, public;
grant execute on function public.refresh_shop_tier_badge(uuid) to anon, authenticated, public;

-- 8) 트리거 — 이벤트 시 메트릭 + 티어 갱신
create or replace function public.trg_shop_tier_refresh()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop uuid;
  v_shop_old uuid;
begin
  if tg_table_name = 'customer_charts' then
    if tg_op = 'DELETE' then
      v_shop := old.shop_id;
    else
      v_shop := new.shop_id;
      if tg_op = 'UPDATE' then
        v_shop_old := old.shop_id;
      end if;
    end if;
    perform public.update_shop_tier_badge(v_shop);
    if v_shop_old is not null and v_shop_old is distinct from v_shop then
      perform public.update_shop_tier_badge(v_shop_old);
    end if;
  elsif tg_table_name = 'chart_likes' then
    select c.shop_id into v_shop
    from public.customer_charts c
    where c.id = case when tg_op = 'DELETE' then old.chart_id else new.chart_id end;
    perform public.update_shop_tier_badge(v_shop);
  elsif tg_table_name = 'shop_followers' then
    v_shop := case when tg_op = 'DELETE' then old.shop_id else new.shop_id end;
    perform public.update_shop_tier_badge(v_shop);
  elsif tg_table_name = 'seminar_requests' then
    select c.shop_id into v_shop
    from public.customer_charts c
    where c.id = case when tg_op = 'DELETE' then old.case_id else new.case_id end;
    perform public.update_shop_tier_badge(v_shop);
  elsif tg_table_name = 'seminar_classes' then
    v_shop := case
      when tg_op = 'DELETE' then old.director_shop_id
      else new.director_shop_id
    end;
    perform public.update_shop_tier_badge(v_shop);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_customer_charts_tier_badge on public.customer_charts;
create trigger trg_customer_charts_tier_badge
  after insert or update of is_case_shared, shop_id, signature_url, consent_pdf_url
  or delete
  on public.customer_charts
  for each row
  execute function public.trg_shop_tier_refresh();

drop trigger if exists trg_chart_likes_tier on public.chart_likes;
create trigger trg_chart_likes_tier
  after insert or delete
  on public.chart_likes
  for each row
  execute function public.trg_shop_tier_refresh();

drop trigger if exists trg_shop_followers_tier on public.shop_followers;
create trigger trg_shop_followers_tier
  after insert or delete
  on public.shop_followers
  for each row
  execute function public.trg_shop_tier_refresh();

drop trigger if exists trg_seminar_requests_tier on public.seminar_requests;
create trigger trg_seminar_requests_tier
  after insert or delete
  on public.seminar_requests
  for each row
  execute function public.trg_shop_tier_refresh();

drop trigger if exists trg_seminar_classes_tier on public.seminar_classes;
create trigger trg_seminar_classes_tier
  after insert or update of status, current_enrollment, price, director_shop_id
  or delete
  on public.seminar_classes
  for each row
  execute function public.trg_shop_tier_refresh();

-- 완료 펀딩 트리거는 티어 트리거가 재집계하므로 유지하되 카운트 중복을 피하도록
-- completed_seminar_count 는 sync_shop_tier_metrics 가 SSOT.

-- 9) 변동 수수료 매핑
create or replace function public.compute_platform_fee_pct(p_tier_badge text)
returns numeric
language sql
immutable
as $$
  select case lower(trim(replace(coalesce(p_tier_badge, 'none'), ' ', '_')))
    when 'grand_director' then 0.080
    when 'grand_master' then 0.100
    when 'master' then 0.110
    when 'mentor' then 0.120
    when 'diamond' then 0.135
    when 'platinum' then 0.140
    when 'gold' then 0.145
    when 'silver' then 0.150
    when 'bronze' then 0.150
    when 'iron' then 0.150
    else 0.150
  end;
$$;

-- 10) 그랜드 디렉터 연간 1억 갱신 · 강등
create or replace function public.review_grand_director_tiers()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_rolling int;
begin
  for r in
    select s.id
    from public.shops s
    where s.tier_badge::text = 'grand_director'
  loop
    v_rolling := public.shop_rolling_12m_funding(r.id);
    if coalesce(v_rolling, 0) < 100000000 then
      update public.shops
      set tier_badge = 'grand_master'::public.shop_tier_badge,
          updated_at = now()
      where id = r.id;
    end if;
  end loop;
end;
$$;

grant execute on function public.review_grand_director_tiers()
  to anon, authenticated, public;

do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('sori-grand-director-monthly-review');
exception
  when undefined_function then null;
  when undefined_object then null;
  when others then null;
end $$;

do $$
begin
  perform cron.schedule(
    'sori-grand-director-monthly-review',
    '0 0 1 * *',
    $cron$select public.review_grand_director_tiers();$cron$
  );
exception
  when undefined_function then
    raise notice 'pg_cron unavailable — review_grand_director_tiers() still callable manually';
  when others then
    raise notice 'pg_cron schedule skipped: %', sqlerrm;
end $$;

-- 11) 기존 샵 백필
do $$
declare
  r record;
begin
  for r in select id from public.shops loop
    perform public.update_shop_tier_badge(r.id);
  end loop;
end $$;
