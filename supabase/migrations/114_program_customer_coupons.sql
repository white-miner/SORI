-- PRD v7.2 — "다음 구매 시 20% 할인"이 증발하지 않게 만든다.
--
-- 쿠폰은 만료 배치와 고객 교차 조회의 대상이므로 customers.memberships 같은
-- jsonb 배열이 아니라 인덱스를 가진 테이블이어야 한다.

create table if not exists public.program_customer_coupons (
  id              uuid primary key default gen_random_uuid(),
  shop_id         uuid not null references public.shops(id) on delete cascade,
  customer_id     uuid not null references public.customers(id) on delete cascade,
  issued_quote_id uuid references public.program_quotes(id) on delete set null,
  promotion_id    uuid references public.program_promotions(id) on delete set null,
  title           text not null,
  percent_off     numeric(5,2) not null default 0,
  discount_krw    int  not null default 0,
  extra_visits    int  not null default 0,
  gift_qty        int  not null default 0,
  status          text not null default 'issued'
                  check (status in ('issued', 'used', 'expired', 'void')),
  issued_at       timestamptz not null default now(),
  expires_at      timestamptz,
  used_at         timestamptz,
  used_quote_id   uuid references public.program_quotes(id) on delete set null,
  created_at      timestamptz not null default now(),
  check (percent_off >= 0 and percent_off <= 100),
  check (discount_krw >= 0 and extra_visits >= 0 and gift_qty >= 0),
  check (status <> 'used' or used_at is not null)
);

create index if not exists program_coupons_customer_idx
  on public.program_customer_coupons (customer_id, status, expires_at);
create index if not exists program_coupons_shop_expiry_idx
  on public.program_customer_coupons (shop_id, status, expires_at);

comment on table public.program_customer_coupons is
  'PRD v7.2 — 발급된 미래가치. 회원권(횟수)과 별개 자산이며 상태 전이를 기록한다.';
comment on column public.program_customer_coupons.status is
  'issued=미사용 / used=사용 / expired=기한 만료 / void=무효화. 삭제로 지우지 않는다.';

alter table public.program_customer_coupons enable row level security;

drop policy if exists program_customer_coupons_director on public.program_customer_coupons;
create policy program_customer_coupons_director
  on public.program_customer_coupons for all
  using (public.program_shop_is_director(shop_id))
  with check (public.program_shop_is_director(shop_id));

-- E3 — 만료는 조회 시점에 조용히 사라지는 것이 아니라 명시적 상태 전이다.
create or replace function public.program_expire_coupons(p_shop_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare v_n int;
begin
  if not public.program_shop_is_director(p_shop_id) then
    raise exception 'not director of shop' using errcode = '42501';
  end if;

  update public.program_customer_coupons
     set status = 'expired'
   where shop_id = p_shop_id
     and status = 'issued'
     and expires_at is not null
     and expires_at < now();
  get diagnostics v_n = row_count;
  return v_n;
end $$;

grant execute on function public.program_expire_coupons(uuid) to authenticated;

notify pgrst, 'reload schema';
