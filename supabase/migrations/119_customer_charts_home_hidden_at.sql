-- 119: Expand — 홈「관리 케이스」비파괴 숨김
-- 「홈에서 숨기기」= home_hidden_at 기록만. caseShared / Visit / Payment / 사진 불변.

alter table public.customer_charts
  add column if not exists home_hidden_at timestamptz null;

comment on column public.customer_charts.home_hidden_at is
  'Home management-case feed hide timestamp. NULL = visible on home. Does not affect community caseShared.';

create index if not exists idx_customer_charts_shop_home_visible
  on public.customer_charts (shop_id, created_at desc)
  where home_hidden_at is null;
