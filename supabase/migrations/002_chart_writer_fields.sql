-- SORI schema patch: chart writer + custom chart no + interview chips

alter table public.shops
  alter column naver_place_url set not null;

alter table public.customer_charts
  add column if not exists custom_chart_no text,
  add column if not exists care_name text default '',
  add column if not exists concern_chips jsonb not null default '[]'::jsonb,
  add column if not exists first_visit_fear_chips jsonb not null default '[]'::jsonb,
  add column if not exists revisit_feedback_chips jsonb not null default '[]'::jsonb;
