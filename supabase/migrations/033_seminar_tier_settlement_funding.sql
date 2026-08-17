-- 033: 펀딩 증명 · 티어별 정산 · 세미나 리뷰 · 클래스 완료 트리거

-- 1) shops 펀딩 금융 증명 컬럼
alter table public.shops
  add column if not exists total_seminar_count int not null default 0,
  add column if not exists total_funding_amount int not null default 0;

comment on column public.shops.total_seminar_count is
  '완료(completed) 처리된 누적 세미나 클래스 수';
comment on column public.shops.total_funding_amount is
  '완료 클래스 기준 누적 펀딩 금액 (참가자×수강료 합)';

-- 2) 클래스 completed 시 호스트 펀딩 집계 트리거
create or replace function public.trg_seminar_class_completed_funding()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed'
     and (tg_op = 'INSERT' or old.status is distinct from 'completed') then
    update public.shops
    set
      total_seminar_count = total_seminar_count + 1,
      total_funding_amount = total_funding_amount
        + greatest(0, coalesce(new.current_enrollment, 0) * coalesce(new.price, 0)),
      updated_at = now()
    where id = new.director_shop_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_seminar_class_completed_funding on public.seminar_classes;
create trigger trg_seminar_class_completed_funding
  after insert or update of status, current_enrollment, price
  on public.seminar_classes
  for each row
  execute function public.trg_seminar_class_completed_funding();

-- 3) 세미나 인사이트 리뷰 (에스크로 릴리즈 전 필수)
create table if not exists public.seminar_enrollment_reviews (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null
    references public.seminar_enrollments (id) on delete cascade,
  insight_tags jsonb not null default '[]'::jsonb,
  comment text not null default '',
  created_at timestamptz not null default now(),
  unique (enrollment_id)
);

create index if not exists idx_seminar_enrollment_reviews_enrollment
  on public.seminar_enrollment_reviews (enrollment_id);

alter table public.seminar_enrollment_reviews enable row level security;
drop policy if exists "mvp_seminar_enrollment_reviews_all"
  on public.seminar_enrollment_reviews;
create policy "mvp_seminar_enrollment_reviews_all"
  on public.seminar_enrollment_reviews for all using (true) with check (true);

-- 4) 티어별 변동 수수료율 (기본 15%, 최저 8%)
create or replace function public.compute_platform_fee_pct(p_tier_badge text)
returns numeric
language sql
immutable
as $$
  select greatest(
    0.08,
    0.15 - case lower(trim(coalesce(p_tier_badge, 'none')))
      when 'master' then 0.07
      when 'gold' then 0.05
      when 'silver' then 0.03
      when 'bronze' then 0.01
      else 0.00
    end
  );
$$;

-- 5) 인사이트 리뷰 제출 RPC
create or replace function public.submit_seminar_enrollment_review(
  p_enrollment_id uuid,
  p_insight_tags jsonb,
  p_comment text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_review_id uuid;
  v_tags jsonb;
begin
  if p_enrollment_id is null then
    raise exception 'enrollment_id required';
  end if;

  if not exists (
    select 1 from public.seminar_enrollments e where e.id = p_enrollment_id
  ) then
    raise exception 'enrollment not found';
  end if;

  v_tags := coalesce(p_insight_tags, '[]'::jsonb);
  if jsonb_typeof(v_tags) <> 'array' or jsonb_array_length(v_tags) < 1 then
    raise exception 'at least one insight tag required';
  end if;

  insert into public.seminar_enrollment_reviews (
    enrollment_id,
    insight_tags,
    comment
  )
  values (
    p_enrollment_id,
    v_tags,
    coalesce(trim(p_comment), '')
  )
  on conflict (enrollment_id) do update
  set
    insight_tags = excluded.insight_tags,
    comment = excluded.comment
  returning id into v_review_id;

  return v_review_id;
end;
$$;

grant execute on function public.submit_seminar_enrollment_review(uuid, jsonb, text)
  to anon, authenticated, public;

-- 6) 티어별 변동 수수료 정산 (리뷰 필수)
create or replace function public.settle_seminar_enrollment(
  p_enrollment_id uuid,
  p_platform_fee_pct numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enrollment public.seminar_enrollments%rowtype;
  v_class public.seminar_classes%rowtype;
  v_director_tier text;
  v_fee_pct numeric;
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

  if not exists (
    select 1
    from public.seminar_enrollment_reviews r
    where r.enrollment_id = p_enrollment_id
  ) then
    raise exception 'review required before settlement';
  end if;

  select * into v_class
  from public.seminar_classes
  where id = v_enrollment.class_id;

  select coalesce(s.tier_badge, 'none') into v_director_tier
  from public.shops s
  where s.id = v_class.director_shop_id;

  v_fee_pct := coalesce(
    p_platform_fee_pct,
    public.compute_platform_fee_pct(v_director_tier)
  );

  v_net := greatest(
    0,
    floor(v_enrollment.amount * (1 - v_fee_pct))::int
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
    'platform_fee_pct', v_fee_pct,
    'tier_badge', v_director_tier
  );
end;
$$;

grant execute on function public.settle_seminar_enrollment(uuid, numeric)
  to anon, authenticated, public;
