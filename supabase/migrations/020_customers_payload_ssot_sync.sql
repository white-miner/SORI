-- customers 테이블 ↔ 앱 _customerWriteMap 전수 동기화 (PGRST204 일괄 복구)
-- 프론트엔드 upsert/insert 가 보내는 모든 컬럼을 IF NOT EXISTS 로 보장한다.

alter table public.customers
  add column if not exists shop_id uuid references public.shops (id) on delete cascade,
  add column if not exists name text,
  add column if not exists phone text,
  add column if not exists last_treatment_date date,
  add column if not exists treatment_type text default '',
  add column if not exists memo text default '',
  add column if not exists memberships jsonb not null default '[]'::jsonb,
  add column if not exists membership_service_name text not null default '',
  add column if not exists membership_total_visits int not null default 0,
  add column if not exists membership_used_visits int not null default 0,
  add column if not exists gender text,
  add column if not exists birth_date date,
  add column if not exists address text default '',
  add column if not exists occupation text default '',
  add column if not exists user_id uuid references public.profiles (id) on delete set null,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- 레거시 읽기 전용 폴백 컬럼 (앱은 customers 쓰기 payload 에서 제외 — 차트 SSOT)
alter table public.customers
  add column if not exists allergy_notes text default '',
  add column if not exists medication_history text default '',
  add column if not exists home_care_habits text default '';

-- gender 제약 (기존 값이 깨지지 않도록 완화 적용)
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'customers_gender_check'
  ) then
    alter table public.customers
      add constraint customers_gender_check
      check (gender is null or gender in ('female', 'male'));
  end if;
exception
  when others then
    raise notice 'customers_gender_check skipped: %', sqlerrm;
end $$;

comment on column public.customers.memberships is
  'SSOT 원장 편집 소스 [{id,service_name,total_visits,used_visits,expires_at?}]. membership_tickets 로 sync';
comment on column public.customers.membership_service_name is
  '레거시 미러: memberships[0].service_name';
comment on column public.customers.membership_total_visits is
  '레거시 미러: 합산/대표 총 횟수';
comment on column public.customers.membership_used_visits is
  '레거시 미러: 합산/대표 사용 횟수';
comment on column public.customers.allergy_notes is
  '레거시. 신규 쓰기는 customer_charts.allergy_notes (차트 SSOT)';
comment on column public.customers.medication_history is
  '레거시. 신규 쓰기는 customer_charts.skin_sensitivity 등';
comment on column public.customers.home_care_habits is
  '레거시. 신규 쓰기는 customer_charts.side_effect_history / 홈케어 처방';

create index if not exists idx_customers_shop_phone on public.customers (shop_id, phone);
create index if not exists idx_customers_user on public.customers (user_id);
create index if not exists idx_customers_updated_at on public.customers (updated_at desc);
