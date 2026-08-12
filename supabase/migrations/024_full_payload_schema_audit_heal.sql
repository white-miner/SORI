-- =============================================================================
-- 024: 프론트엔드 Supabase Payload 전수 감사 후 스키마 일괄 치유
-- -----------------------------------------------------------------------------
-- 앱(lib/models + supabase_sori_repository) 이 읽기/쓰기하는 모든 테이블·컬럼을
-- CREATE TABLE IF NOT EXISTS + ADD COLUMN IF NOT EXISTS 로 보장한다.
-- 특히 customer_reviews.customer_id 는 001 CREATE 에만 있고 이후 ALTER ensure
-- 가 없어, 구스키마/부분적용 DB에서 PGRST204 → 상태 붕괴의 근원이 된다.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0) 공통: shops / profiles (FK 대상)
-- ---------------------------------------------------------------------------
create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_name text,
  phone text,
  naver_place_url text,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'guest'
    check (role in ('director', 'customer', 'guest')),
  name text not null default '',
  phone text not null default '',
  active_mode text not null default 'customer'
    check (active_mode in ('director', 'customer', 'guest')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.shops
  add column if not exists name text,
  add column if not exists owner_name text,
  add column if not exists phone text,
  add column if not exists naver_place_url text,
  add column if not exists address text,
  add column if not exists owner_user_id uuid references public.profiles (id) on delete set null,
  add column if not exists service_menu jsonb not null default '[]'::jsonb,
  add column if not exists operating_hours text default '',
  add column if not exists sns_blog_url text default '',
  add column if not exists sns_instagram_url text default '',
  add column if not exists kakao_point int not null default 0,
  add column if not exists is_pro boolean not null default false,
  add column if not exists monthly_capa int not null default 100,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.profiles
  add column if not exists role text not null default 'guest',
  add column if not exists name text not null default '',
  add column if not exists phone text not null default '',
  add column if not exists active_mode text not null default 'customer',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- 1) customers (Customer.toDbWriteMap SSOT)
-- ---------------------------------------------------------------------------
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  name text not null,
  phone text not null,
  last_treatment_date date,
  treatment_type text,
  memo text default '',
  membership_total_visits int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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
  add column if not exists last_promotion_sent_at timestamptz,
  add column if not exists allergy_notes text default '',
  add column if not exists medication_history text default '',
  add column if not exists home_care_habits text default '',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- 2) customer_charts + chart_records 미러 (ChartDbColumns.writeKeys)
-- ---------------------------------------------------------------------------
create table if not exists public.customer_charts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete cascade,
  visit_number int not null check (visit_number >= 1),
  visit_checked boolean not null default false,
  visit_checked_at timestamptz,
  before_image_url text,
  after_image_url text,
  treatment_summary text,
  director_insight text,
  feedback_token text unique,
  feedback_line_opened_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, visit_number)
);

alter table public.customer_charts
  add column if not exists shop_id uuid references public.shops (id) on delete cascade,
  add column if not exists customer_id uuid references public.customers (id) on delete cascade,
  add column if not exists visit_number int,
  add column if not exists custom_chart_no text,
  add column if not exists visit_checked boolean not null default false,
  add column if not exists visit_checked_at timestamptz,
  add column if not exists before_image_url text,
  add column if not exists after_image_url text,
  add column if not exists photo_meta jsonb not null default '{}'::jsonb,
  add column if not exists care_name text not null default '',
  add column if not exists treatment_summary text default '',
  add column if not exists director_insight text default '',
  add column if not exists allergy_notes text default '',
  add column if not exists skin_sensitivity text default '',
  add column if not exists side_effect_history text default '',
  add column if not exists customer_requests text default '',
  add column if not exists concern_chips jsonb not null default '[]'::jsonb,
  add column if not exists first_visit_fear_chips jsonb not null default '[]'::jsonb,
  add column if not exists revisit_feedback_chips jsonb not null default '[]'::jsonb,
  add column if not exists feedback_token text,
  add column if not exists feedback_line_opened_at timestamptz,
  add column if not exists consent_mandatory boolean not null default false,
  add column if not exists consent_photo boolean not null default false,
  add column if not exists consent_marketing boolean not null default false,
  add column if not exists consent_offline_only boolean not null default false,
  add column if not exists signature_url text,
  add column if not exists consent_pdf_url text,
  add column if not exists is_case_shared boolean not null default false,
  add column if not exists case_shared boolean not null default false,
  add column if not exists prescription_tags jsonb not null default '[]'::jsonb,
  add column if not exists home_care_prescriptions jsonb not null default '[]'::jsonb,
  add column if not exists guardian_phone text,
  add column if not exists info_view_consent boolean not null default false,
  add column if not exists home_care_mission_checks jsonb not null default '[]'::jsonb,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
declare
  relkind char;
begin
  select c.relkind into relkind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'chart_records';

  if relkind = 'r' then
    alter table public.chart_records
      add column if not exists shop_id uuid,
      add column if not exists customer_id uuid,
      add column if not exists visit_number int,
      add column if not exists custom_chart_no text,
      add column if not exists visit_checked boolean default false,
      add column if not exists visit_checked_at timestamptz,
      add column if not exists before_image_url text,
      add column if not exists after_image_url text,
      add column if not exists photo_meta jsonb default '{}'::jsonb,
      add column if not exists care_name text default '',
      add column if not exists treatment_summary text default '',
      add column if not exists director_insight text default '',
      add column if not exists allergy_notes text default '',
      add column if not exists skin_sensitivity text default '',
      add column if not exists side_effect_history text default '',
      add column if not exists customer_requests text default '',
      add column if not exists concern_chips jsonb default '[]'::jsonb,
      add column if not exists first_visit_fear_chips jsonb default '[]'::jsonb,
      add column if not exists revisit_feedback_chips jsonb default '[]'::jsonb,
      add column if not exists feedback_token text,
      add column if not exists feedback_line_opened_at timestamptz,
      add column if not exists consent_mandatory boolean default false,
      add column if not exists consent_photo boolean default false,
      add column if not exists consent_marketing boolean default false,
      add column if not exists consent_offline_only boolean default false,
      add column if not exists signature_url text,
      add column if not exists consent_pdf_url text,
      add column if not exists is_case_shared boolean default false,
      add column if not exists prescription_tags jsonb default '[]'::jsonb,
      add column if not exists home_care_prescriptions jsonb default '[]'::jsonb,
      add column if not exists guardian_phone text,
      add column if not exists info_view_consent boolean default false,
      add column if not exists home_care_mission_checks jsonb default '[]'::jsonb,
      add column if not exists updated_at timestamptz default now();
    raise notice 'chart_records BASE TABLE columns ensured';
  else
    execute 'drop view if exists public.chart_records cascade';
    execute 'create view public.chart_records as select * from public.customer_charts';
    execute 'grant select, insert, update, delete on public.chart_records to anon, authenticated, service_role';
    raise notice 'chart_records view recreated as select * from customer_charts';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3) customer_reviews ← PGRST204 근원 (customer_id ensure 누락 치유)
-- ---------------------------------------------------------------------------
create table if not exists public.customer_reviews (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.customer_charts (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  puzzle_selections jsonb not null default '[]'::jsonb,
  original_text text,
  edited_text text,
  status text not null default 'draft',
  request_ai_reply boolean not null default false,
  accepted_at timestamptz,
  naver_registered boolean not null default false,
  naver_registered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.customer_reviews
  add column if not exists chart_id uuid references public.customer_charts (id) on delete cascade,
  add column if not exists customer_id uuid references public.customers (id) on delete cascade,
  add column if not exists shop_id uuid references public.shops (id) on delete cascade,
  add column if not exists puzzle_selections jsonb not null default '[]'::jsonb,
  add column if not exists original_text text,
  add column if not exists edited_text text,
  add column if not exists status text not null default 'draft',
  add column if not exists request_ai_reply boolean not null default false,
  add column if not exists accepted_at timestamptz,
  add column if not exists naver_registered boolean not null default false,
  add column if not exists naver_registered_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create index if not exists idx_customer_reviews_chart
  on public.customer_reviews (chart_id);
create index if not exists idx_customer_reviews_customer
  on public.customer_reviews (customer_id);
create index if not exists idx_customer_reviews_shop
  on public.customer_reviews (shop_id);

comment on column public.customer_reviews.customer_id is
  '앱 CustomerReview.toMap / 차트저장 후기초안 insert 필수 FK — 024 ensure';

-- ---------------------------------------------------------------------------
-- 4) ai_replies
-- ---------------------------------------------------------------------------
create table if not exists public.ai_replies (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.customer_reviews (id) on delete cascade,
  chart_id uuid not null references public.customer_charts (id) on delete cascade,
  status text not null default 'pending',
  reply_text text,
  is_copied boolean not null default false,
  copied_at timestamptz,
  generated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.ai_replies
  add column if not exists review_id uuid references public.customer_reviews (id) on delete cascade,
  add column if not exists chart_id uuid references public.customer_charts (id) on delete cascade,
  add column if not exists status text not null default 'pending',
  add column if not exists reply_text text,
  add column if not exists is_copied boolean not null default false,
  add column if not exists copied_at timestamptz,
  add column if not exists generated_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- 5) care_diary_notes
-- ---------------------------------------------------------------------------
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

alter table public.care_diary_notes
  add column if not exists shop_id uuid references public.shops (id) on delete cascade,
  add column if not exists customer_id uuid references public.customers (id) on delete cascade,
  add column if not exists note_date date,
  add column if not exists body text not null default '',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- 6) membership_tickets
-- ---------------------------------------------------------------------------
create table if not exists public.membership_tickets (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete cascade,
  customer_phone_digits text not null default '',
  ticket_name text not null default '',
  total_visits int not null default 0,
  used_visits int not null default 0,
  expires_at date,
  is_active boolean not null default true,
  paid_amount numeric(12, 2) not null default 0,
  per_session_value numeric(12, 2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.membership_tickets
  add column if not exists shop_id uuid references public.shops (id) on delete cascade,
  add column if not exists customer_id uuid references public.customers (id) on delete cascade,
  add column if not exists customer_phone_digits text not null default '',
  add column if not exists ticket_name text not null default '',
  add column if not exists total_visits int not null default 0,
  add column if not exists used_visits int not null default 0,
  add column if not exists expires_at date,
  add column if not exists is_active boolean not null default true,
  add column if not exists paid_amount numeric(12, 2) not null default 0,
  add column if not exists per_session_value numeric(12, 2) not null default 0,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- 7) kakao_msg_logs
-- ---------------------------------------------------------------------------
create table if not exists public.kakao_msg_logs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  customer_phone text not null default '',
  template_code text not null default '',
  content text not null default '',
  status text not null default 'queued',
  margin_amount int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.kakao_msg_logs
  add column if not exists shop_id uuid references public.shops (id) on delete cascade,
  add column if not exists customer_phone text not null default '',
  add column if not exists template_code text not null default '',
  add column if not exists content text not null default '',
  add column if not exists status text not null default 'queued',
  add column if not exists margin_amount int not null default 0,
  add column if not exists created_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- 8) Storage buckets (앱 업로드)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('chart-photos', 'chart-photos', true),
  ('chart-signatures', 'chart-signatures', true),
  ('consent_pdfs', 'consent_pdfs', true)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 9) RLS 최소 보장 (이미 있으면면 no-op)
-- ---------------------------------------------------------------------------
alter table public.shops enable row level security;
alter table public.customers enable row level security;
alter table public.customer_charts enable row level security;
alter table public.customer_reviews enable row level security;
alter table public.ai_replies enable row level security;
alter table public.care_diary_notes enable row level security;
alter table public.membership_tickets enable row level security;
alter table public.kakao_msg_logs enable row level security;

-- MVP anon 정책 (006 과 동일 취지 — 없으면 생성)
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'customer_reviews'
      and policyname = 'mvp_reviews_select'
  ) then
    create policy "mvp_reviews_select" on public.customer_reviews for select using (true);
    create policy "mvp_reviews_insert" on public.customer_reviews for insert with check (true);
    create policy "mvp_reviews_update" on public.customer_reviews for update using (true);
  end if;
exception when others then
  raise notice 'customer_reviews policies skipped: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- 10) PostgREST 스키마 캐시 강제 리로드 (PGRST204 잔존 방지)
-- ---------------------------------------------------------------------------
notify pgrst, 'reload schema';

comment on table public.customer_reviews is
  '024 full audit heal — customer_id/shop_id/chart_id ensure 포함';
