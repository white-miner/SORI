-- 121: Expand — 고객 파일철 번호 · 마지막 발급 방문번호 · 방문일
-- Scope: ADD COLUMN IF NOT EXISTS only. All three columns are nullable.
-- Not in this migration:
--   backfill, UNIQUE, indexes, UPDATE/DELETE/merge of existing rows,
--   app routes, forceQuickChart, ensureTodayShootChart, Chart UI.
-- Preserved:
--   unique(customer_id, visit_number) on public.customer_charts
--   custom_chart_no / visit_number are NOT substitutes for customer_file_no.

alter table public.customers
  add column if not exists customer_file_no integer null;

alter table public.customers
  add column if not exists last_visit_number integer null;

alter table public.customer_charts
  add column if not exists visit_date date null;

comment on column public.customers.customer_file_no is
  'Permanent shop-local customer file number (UI later: No25). NULL until a later backfill. Do not use custom_chart_no, displayChartNo, or visit_number as this value.';

comment on column public.customers.last_visit_number is
  'Last issued customer_charts.visit_number for this customer (UI later: v15). Prevents reuse after chart delete. NULL until a later backfill. Not customer_file_no.';

comment on column public.customer_charts.visit_date is
  'Actual visit calendar date as Asia/Seoul date. Future SSOT for Today and one-chart-per-customer-per-day. NULL until a later backfill. Not a display alias of created_at or visit_checked_at.';

-- MANUAL ROLLBACK (run only to undo this Expand; drops these three columns):
-- alter table public.customer_charts drop column if exists visit_date;
-- alter table public.customers drop column if exists last_visit_number;
-- alter table public.customers drop column if exists customer_file_no;
