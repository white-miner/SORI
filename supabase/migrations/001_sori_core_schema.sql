-- SORI (소리) B2B Aesthetic CRM — core schema (Supabase / Postgres)

-- shops: 매장 정보
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

-- customers (앱 모델과 연동용 최소 스키마)
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

-- customer_charts: 전/후 차트, 회차, 방문 확인, 원장 인사이트
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

-- visit_checked = true 시 결제 테이블 없이 토큰/피드백 라인 개설
create or replace function public.open_feedback_line_on_visit_checked()
returns trigger
language plpgsql
as $$
begin
  if new.visit_checked = true
     and (tg_op = 'INSERT' or coalesce(old.visit_checked, false) = false) then
    if new.feedback_token is null then
      new.feedback_token := encode(gen_random_bytes(16), 'hex');
    end if;
    if new.feedback_line_opened_at is null then
      new.feedback_line_opened_at := now();
    end if;
    if new.visit_checked_at is null then
      new.visit_checked_at := now();
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_customer_charts_visit_checked on public.customer_charts;
create trigger trg_customer_charts_visit_checked
before insert or update of visit_checked
on public.customer_charts
for each row
execute function public.open_feedback_line_on_visit_checked();

-- customer_reviews: 고객 선택 퍼즐, 수정 텍스트, 요청 답글 옵션
create table if not exists public.customer_reviews (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.customer_charts (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  puzzle_selections jsonb not null default '[]'::jsonb,
  original_text text,
  edited_text text,
  status text not null default 'draft'
    check (status in ('draft', 'accepted', 'editing', 'reply_requested', 'published')),
  request_ai_reply boolean not null default false,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ai_replies: 비동기 생성 AI 답글, 복사 여부
create table if not exists public.ai_replies (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.customer_reviews (id) on delete cascade,
  chart_id uuid not null references public.customer_charts (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'generating', 'ready', 'failed')),
  reply_text text,
  is_copied boolean not null default false,
  copied_at timestamptz,
  generated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_customer_charts_customer
  on public.customer_charts (customer_id, visit_number desc);
create index if not exists idx_customer_reviews_chart
  on public.customer_reviews (chart_id);
create index if not exists idx_ai_replies_review
  on public.ai_replies (review_id);

alter table public.shops enable row level security;
alter table public.customers enable row level security;
alter table public.customer_charts enable row level security;
alter table public.customer_reviews enable row level security;
alter table public.ai_replies enable row level security;
