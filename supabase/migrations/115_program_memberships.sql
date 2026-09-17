-- PRD v7.2 — Q2(a) 회원권을 자산 테이블로 승격.
--
-- customers.memberships jsonb 는 append-only 라 환불·승계·소멸을 표현할 수 없다.
-- 돈이 오가는 자산은 행 단위 이력과 FK 가 필요하다.
-- 기존 화면이 전부 jsonb 를 읽으므로 jsonb 는 읽기 미러로 유지한다 (무중단 전환).

create table if not exists public.program_memberships (
  id                 uuid primary key default gen_random_uuid(),
  shop_id            uuid not null references public.shops(id) on delete cascade,
  customer_id        uuid not null references public.customers(id) on delete cascade,
  source_quote_id    uuid references public.program_quotes(id) on delete set null,
  service_name       text not null,
  total_visits       int  not null check (total_visits > 0),
  used_visits        int  not null default 0 check (used_visits >= 0),
  paid_krw           int  not null default 0,
  per_session_krw    int  not null default 0,
  status             text not null default 'active'
                     check (status in ('active', 'refunded', 'superseded', 'expired', 'void')),
  refunded_krw       int  not null default 0,
  refunded_at        timestamptz,
  refund_basis       text check (refund_basis is null or refund_basis in ('list_unit', 'package_unit')),
  superseded_by      uuid references public.program_memberships(id) on delete set null,
  credit_applied_krw int  not null default 0,
  expires_at         timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (used_visits <= total_visits)
);

create index if not exists program_memberships_customer_idx
  on public.program_memberships (customer_id, status, expires_at nulls last);
create index if not exists program_memberships_shop_idx
  on public.program_memberships (shop_id, created_at desc);

comment on table public.program_memberships is
  'PRD v7.2 — 회원권 자산 원장. customers.memberships jsonb 는 읽기 미러로만 남는다.';
comment on column public.program_memberships.refund_basis is
  'E1 — 소진분 정산 기준. list_unit=정가 회당, package_unit=패키지 회당. 분쟁 대비 기록.';
comment on column public.program_memberships.superseded_by is
  'E2 — 업그레이드 승계 대상. 원본은 superseded 로 닫고 잔여가치를 credit 으로 넘긴다.';
comment on column public.program_memberships.expires_at is
  'E7 — 차감 우선순위 1순위 키. 만료 임박분을 먼저 소진시킨다.';

alter table public.program_memberships enable row level security;

drop policy if exists program_memberships_director on public.program_memberships;
create policy program_memberships_director
  on public.program_memberships for all
  using (public.program_shop_is_director(shop_id))
  with check (public.program_shop_is_director(shop_id));

notify pgrst, 'reload schema';
