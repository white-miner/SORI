-- 스마트 홈케어 처방 + 보호자 열람 + 3일 미션 + 케어 다이어리

alter table public.customer_charts
  add column if not exists home_care_prescriptions jsonb not null default '[]'::jsonb;

alter table public.customer_charts
  add column if not exists guardian_phone text;

alter table public.customer_charts
  add column if not exists info_view_consent boolean not null default false;

alter table public.customer_charts
  add column if not exists home_care_mission_checks jsonb not null default '[false,false,false]'::jsonb;

comment on column public.customer_charts.home_care_prescriptions is
  '원장이 선택한 홈케어 처방 태그 ID 배열';
comment on column public.customer_charts.guardian_phone is
  '보호자 연락처 (가족 프로필 스위처 매칭용)';
comment on column public.customer_charts.info_view_consent is
  '보호자의 정보 열람 동의 여부';
comment on column public.customer_charts.home_care_mission_checks is
  '시술 후 3일 홈케어 미션 체크 [day1, day2, day3]';

create table if not exists public.care_diary_notes (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete cascade,
  note_date date not null,
  body text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, note_date)
);

create index if not exists care_diary_notes_shop_customer_idx
  on public.care_diary_notes (shop_id, customer_id);

alter table public.care_diary_notes enable row level security;

drop policy if exists "mvp_care_diary_select" on public.care_diary_notes;
drop policy if exists "mvp_care_diary_insert" on public.care_diary_notes;
drop policy if exists "mvp_care_diary_update" on public.care_diary_notes;
create policy "mvp_care_diary_select" on public.care_diary_notes for select using (true);
create policy "mvp_care_diary_insert" on public.care_diary_notes for insert with check (true);
create policy "mvp_care_diary_update" on public.care_diary_notes for update using (true);
