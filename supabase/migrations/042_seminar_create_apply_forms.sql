-- 042: 세미나 개설 폼 확장(class_format) + 수강 신청서(seminar_applications)
-- 기존 seminar_classes / seminar_enrollments 와 병행. seminars 는 호환 뷰.

alter table public.seminar_classes
  add column if not exists class_format text not null default 'oneday'
    check (class_format in ('oneday', 'regular', 'one_on_one', 'demo'));

comment on column public.seminar_classes.class_format is
  '클래스 형태: oneday | regular | one_on_one | demo';

-- 사용자 요청 명칭 `seminars` 호환 뷰 (실데이터는 seminar_classes)
create or replace view public.seminars as
select
  id,
  director_shop_id,
  target_case_id,
  title,
  event_date,
  location,
  price,
  max_capacity,
  current_enrollment,
  status,
  description,
  class_format,
  created_at,
  updated_at
from public.seminar_classes;

comment on view public.seminars is
  '호환 뷰 — 물리 테이블은 seminar_classes';

grant select on public.seminars to anon, authenticated, public;

-- 수강 신청서 (관심/사전 질문 → 이후 에스크로 enroll 연동)
create table if not exists public.seminar_applications (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.seminar_classes (id) on delete cascade,
  applicant_shop_id uuid references public.shops (id) on delete set null,
  applicant_user_id uuid references auth.users (id) on delete set null,
  applicant_name text not null default '',
  shop_name text not null default '',
  contact_phone text not null default '',
  career_type text not null default '',
  question text not null default '',
  refund_agreed boolean not null default false,
  status text not null default 'submitted'
    check (status in ('submitted', 'accepted', 'rejected', 'cancelled')),
  created_at timestamptz not null default now(),
  unique (class_id, applicant_shop_id),
  unique (class_id, applicant_user_id)
);

create index if not exists idx_seminar_applications_class
  on public.seminar_applications (class_id, created_at desc);
create index if not exists idx_seminar_applications_shop
  on public.seminar_applications (applicant_shop_id, created_at desc);

comment on table public.seminar_applications is
  '세미나 수강 신청서 — 사전 질문·경력·환불동의. 결제는 seminar_enrollments';

alter table public.seminar_applications enable row level security;

drop policy if exists "mvp_seminar_applications_select" on public.seminar_applications;
drop policy if exists "mvp_seminar_applications_insert" on public.seminar_applications;
drop policy if exists "mvp_seminar_applications_update" on public.seminar_applications;

create policy "mvp_seminar_applications_select"
  on public.seminar_applications for select using (true);
create policy "mvp_seminar_applications_insert"
  on public.seminar_applications for insert with check (true);
create policy "mvp_seminar_applications_update"
  on public.seminar_applications for update using (true) with check (true);
