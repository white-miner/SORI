-- 스마트 회원권(티켓팅) 필드
alter table public.customers
  add column if not exists membership_service_name text not null default '',
  add column if not exists membership_used_visits int not null default 0;

comment on column public.customers.membership_service_name is '진행 중 회원권 서비스명 (예: 재생 케어 10회권)';
comment on column public.customers.membership_total_visits is '총 결제 횟수';
comment on column public.customers.membership_used_visits is '현재까지 차감된 횟수';
