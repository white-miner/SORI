-- 031: B2B 에듀케이터 마켓플레이스 · 티어 뱃지 · 세미나 · 에스크로 정산

-- 1) shops 확장
alter table public.shops
  add column if not exists tier_badge text not null default 'none',
  add column if not exists sori_cash_balance int not null default 0;

comment on column public.shops.tier_badge is
  '누적 공유 케이스 기반 티어: none | Bronze | Silver | Gold | Master';
comment on column public.shops.sori_cash_balance is
  '세미나 정산 후 적립되는 SORI Cash (원 단위)';

-- 2) seminar_requests
create table if not exists public.seminar_requests (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.customer_charts (id) on delete cascade,
  requestor_shop_id uuid not null references public.shops (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (case_id, requestor_shop_id)
);

create index if not exists idx_seminar_requests_case
  on public.seminar_requests (case_id, created_at desc);
create index if not exists idx_seminar_requests_requestor
  on public.seminar_requests (requestor_shop_id, created_at desc);

comment on table public.seminar_requests is
  'B2B 원장 → 타 샵 공유 케이스 세미나 개설 요청';

-- 3) seminar_classes
create table if not exists public.seminar_classes (
  id uuid primary key default gen_random_uuid(),
  director_shop_id uuid not null references public.shops (id) on delete cascade,
  target_case_id uuid references public.customer_charts (id) on delete set null,
  title text not null,
  event_date timestamptz,
  location text not null default '',
  price int not null default 0 check (price >= 0),
  max_capacity int not null default 20 check (max_capacity >= 1),
  current_enrollment int not null default 0 check (current_enrollment >= 0),
  status text not null default 'open'
    check (status in ('draft', 'open', 'held', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_seminar_classes_director
  on public.seminar_classes (director_shop_id, created_at desc);
create index if not exists idx_seminar_classes_case
  on public.seminar_classes (target_case_id);

comment on table public.seminar_classes is
  '원장 오프라인/온라인 교육 클래스 — status held = 에스크로 보류';

-- 4) seminar_enrollments (에스크로)
create table if not exists public.seminar_enrollments (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.seminar_classes (id) on delete cascade,
  enrollor_shop_id uuid not null references public.shops (id) on delete cascade,
  amount int not null default 0 check (amount >= 0),
  status text not null default 'held'
    check (status in ('held', 'completed', 'refunded')),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists idx_seminar_enrollments_class
  on public.seminar_enrollments (class_id, status);

-- 5) 티어 뱃지 자동 갱신
create or replace function public.compute_shop_tier_badge(p_shared_count int)
returns text
language sql
immutable
as $$
  select case
    when coalesce(p_shared_count, 0) >= 30 then 'Master'
    when coalesce(p_shared_count, 0) >= 15 then 'Gold'
    when coalesce(p_shared_count, 0) >= 5 then 'Silver'
    when coalesce(p_shared_count, 0) >= 1 then 'Bronze'
    else 'none'
  end;
$$;

create or replace function public.refresh_shop_tier_badge(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_badge text;
begin
  if p_shop_id is null then
    return;
  end if;

  select count(*)::int into v_count
  from public.customer_charts c
  where c.shop_id = p_shop_id
    and c.is_case_shared = true
    and (
      coalesce(c.signature_url, '') <> ''
      or coalesce(c.consent_pdf_url, '') <> ''
    );

  v_badge := public.compute_shop_tier_badge(v_count);

  update public.shops
  set tier_badge = v_badge,
      updated_at = now()
  where id = p_shop_id;
end;
$$;

create or replace function public.trg_refresh_tier_on_case_share()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'INSERT' then
    if NEW.is_case_shared = true then
      perform public.refresh_shop_tier_badge(NEW.shop_id);
    end if;
  elsif TG_OP = 'UPDATE' then
    if NEW.is_case_shared is distinct from OLD.is_case_shared
       or NEW.shop_id is distinct from OLD.shop_id then
      perform public.refresh_shop_tier_badge(NEW.shop_id);
      if OLD.shop_id is distinct from NEW.shop_id then
        perform public.refresh_shop_tier_badge(OLD.shop_id);
      end if;
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_customer_charts_tier_badge on public.customer_charts;
create trigger trg_customer_charts_tier_badge
  after insert or update of is_case_shared, shop_id
  on public.customer_charts
  for each row
  execute function public.trg_refresh_tier_on_case_share();

-- 기존 샵 tier_badge 백필
do $$
declare
  r record;
begin
  for r in select id from public.shops loop
    perform public.refresh_shop_tier_badge(r.id);
  end loop;
end $$;

-- 6) 타임라인 그룹 RPC (동일 customer + 관리 태그)
create or replace function public.get_case_timeline_group(p_chart_id uuid)
returns table (
  chart_id uuid,
  visit_number int,
  care_name text,
  before_image_url text,
  after_image_url text,
  care_tags jsonb,
  created_at timestamptz
)
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_shop_id uuid;
  v_tags jsonb;
  v_tag_arr text[];
begin
  select c.customer_id, c.shop_id,
         coalesce(
           nullif(c.care_tags, '[]'::jsonb),
           nullif(c.concern_chips, '[]'::jsonb),
           '[]'::jsonb
         )
  into v_customer_id, v_shop_id, v_tags
  from public.customer_charts c
  where c.id = p_chart_id;

  if v_customer_id is null then
    return;
  end if;

  select coalesce(array_agg(t), '{}'::text[])
  into v_tag_arr
  from jsonb_array_elements_text(v_tags) as t;

  return query
  select
    c.id,
    c.visit_number,
    c.care_name,
    c.before_image_url,
    c.after_image_url,
    coalesce(
      nullif(c.care_tags, '[]'::jsonb),
      nullif(c.concern_chips, '[]'::jsonb),
      '[]'::jsonb
    ),
    c.created_at
  from public.customer_charts c
  where c.customer_id = v_customer_id
    and c.shop_id = v_shop_id
    and c.is_case_shared = true
    and (
      c.id = p_chart_id
      or cardinality(v_tag_arr) = 0
      or coalesce(c.care_tags, c.concern_chips, '[]'::jsonb)
         ?| v_tag_arr
    )
  order by c.visit_number asc, c.created_at asc;
end;
$$;

grant execute on function public.get_case_timeline_group(uuid)
  to anon, authenticated, public;

-- 7) 세미나 수강 등록 (에스크로 held)
create or replace function public.enroll_seminar_class(
  p_class_id uuid,
  p_enrollor_shop_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_class public.seminar_classes%rowtype;
  v_enrollment_id uuid;
begin
  select * into v_class
  from public.seminar_classes
  where id = p_class_id
  for update;

  if not found then
    raise exception 'class not found';
  end if;

  if v_class.status not in ('open', 'held') then
    raise exception 'class not enrollable';
  end if;

  if v_class.current_enrollment >= v_class.max_capacity then
    raise exception 'class full';
  end if;

  insert into public.seminar_enrollments (
    class_id,
    enrollor_shop_id,
    amount,
    status
  )
  values (
    p_class_id,
    p_enrollor_shop_id,
    v_class.price,
    'held'
  )
  returning id into v_enrollment_id;

  update public.seminar_classes
  set
    current_enrollment = current_enrollment + 1,
    status = case
      when current_enrollment + 1 >= max_capacity then 'held'
      else status
    end,
    updated_at = now()
  where id = p_class_id;

  return v_enrollment_id;
end;
$$;

grant execute on function public.enroll_seminar_class(uuid, uuid)
  to anon, authenticated, public;

-- 8) 수강 완료 정산 (held → completed, sori_cash_balance 적립)
create or replace function public.settle_seminar_enrollment(
  p_enrollment_id uuid,
  p_platform_fee_pct numeric default 0.10
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enrollment public.seminar_enrollments%rowtype;
  v_class public.seminar_classes%rowtype;
  v_net int;
begin
  select * into v_enrollment
  from public.seminar_enrollments
  where id = p_enrollment_id
  for update;

  if not found then
    raise exception 'enrollment not found';
  end if;

  if v_enrollment.status <> 'held' then
    raise exception 'enrollment not in held status';
  end if;

  select * into v_class
  from public.seminar_classes
  where id = v_enrollment.class_id;

  v_net := greatest(
    0,
    floor(v_enrollment.amount * (1 - coalesce(p_platform_fee_pct, 0.10)))::int
  );

  update public.seminar_enrollments
  set status = 'completed',
      completed_at = now()
  where id = p_enrollment_id;

  update public.shops
  set sori_cash_balance = sori_cash_balance + v_net,
      updated_at = now()
  where id = v_class.director_shop_id;

  return jsonb_build_object(
    'enrollment_id', p_enrollment_id,
    'net_amount', v_net,
    'director_shop_id', v_class.director_shop_id,
    'platform_fee_pct', coalesce(p_platform_fee_pct, 0.10)
  );
end;
$$;

grant execute on function public.settle_seminar_enrollment(uuid, numeric)
  to anon, authenticated, public;

-- 9) RLS (MVP — anon 허용, 프로덕션에서 강화)
alter table public.seminar_requests enable row level security;
alter table public.seminar_classes enable row level security;
alter table public.seminar_enrollments enable row level security;

drop policy if exists "mvp_seminar_requests_select" on public.seminar_requests;
drop policy if exists "mvp_seminar_requests_insert" on public.seminar_requests;
create policy "mvp_seminar_requests_select"
  on public.seminar_requests for select using (true);
create policy "mvp_seminar_requests_insert"
  on public.seminar_requests for insert with check (true);

drop policy if exists "mvp_seminar_classes_select" on public.seminar_classes;
drop policy if exists "mvp_seminar_classes_insert" on public.seminar_classes;
drop policy if exists "mvp_seminar_classes_update" on public.seminar_classes;
create policy "mvp_seminar_classes_select"
  on public.seminar_classes for select using (true);
create policy "mvp_seminar_classes_insert"
  on public.seminar_classes for insert with check (true);
create policy "mvp_seminar_classes_update"
  on public.seminar_classes for update using (true);

drop policy if exists "mvp_seminar_enrollments_select" on public.seminar_enrollments;
drop policy if exists "mvp_seminar_enrollments_insert" on public.seminar_enrollments;
drop policy if exists "mvp_seminar_enrollments_update" on public.seminar_enrollments;
create policy "mvp_seminar_enrollments_select"
  on public.seminar_enrollments for select using (true);
create policy "mvp_seminar_enrollments_insert"
  on public.seminar_enrollments for insert with check (true);
create policy "mvp_seminar_enrollments_update"
  on public.seminar_enrollments for update using (true);

-- 10) community_shared_cases 뷰에 tier_badge / booking URL 유지 (DROP 후 재생성)
drop view if exists public.community_shared_cases;

create view public.community_shared_cases
with (security_invoker = true)
as
select
  c.id as chart_id,
  c.shop_id,
  c.visit_number,
  c.care_name,
  c.treatment_summary,
  c.concern_chips,
  case
    when c.care_tags is not null
      and jsonb_typeof(c.care_tags) = 'array'
      and jsonb_array_length(c.care_tags) > 0
      then c.care_tags
    else coalesce(c.concern_chips, '[]'::jsonb)
  end as care_tags,
  c.before_image_url,
  c.after_image_url,
  c.is_case_shared,
  c.created_at,
  s.name as shop_name,
  s.owner_name as shop_owner_name,
  s.profile_image_url as shop_profile_image_url,
  s.naver_place_url as shop_naver_place_url,
  coalesce(s.naver_booking_url, '') as shop_naver_booking_url,
  coalesce(s.tier_badge, 'none') as shop_tier_badge,
  r.id as review_id,
  r.original_text as review_original_text,
  r.edited_text as review_edited_text,
  coalesce(
    nullif(trim(coalesce(r.edited_text, '')), ''),
    nullif(trim(coalesce(r.original_text, '')), '')
  ) as customer_review_text,
  r.director_reply,
  r.director_replied_at,
  r.rating as review_rating,
  r.status as review_status,
  r.accepted_at as review_accepted_at,
  r.created_at as review_created_at
from public.customer_charts c
join public.shops s on s.id = c.shop_id
left join lateral (
  select *
  from public.customer_reviews rv
  where rv.chart_id = c.id
    and coalesce(rv.original_text, '') <> ''
  order by coalesce(rv.accepted_at, rv.created_at) desc nulls last
  limit 1
) r on true
where c.is_case_shared = true
  and (
    coalesce(c.signature_url, '') <> ''
    or coalesce(c.consent_pdf_url, '') <> ''
  )
  and (
    coalesce(c.before_image_url, '') <> ''
    or coalesce(c.after_image_url, '') <> ''
  );

grant select on public.community_shared_cases to anon, authenticated, public;
