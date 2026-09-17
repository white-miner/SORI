-- 샵 서비스 메뉴 + 고객 다중 회원권 + 차트 고객 요청사항
alter table public.shops
  add column if not exists service_menu jsonb not null default '[]'::jsonb;

alter table public.customers
  add column if not exists memberships jsonb not null default '[]'::jsonb;

alter table public.customer_charts
  add column if not exists customer_requests text not null default '';

comment on column public.shops.service_menu is '샵 제공 서비스명 목록 (jsonb string array)';
comment on column public.customers.memberships is '다중 회원권 [{id,service_name,total_visits,used_visits}]';
comment on column public.customer_charts.customer_requests is '오늘 방문 고객 특별 요청사항';
