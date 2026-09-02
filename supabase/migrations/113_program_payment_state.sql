-- PRD v7.2 — PG 없이 수기로 닫는다. '오늘 받을 돈'과 '실제 받은 돈'을 분리한다.
--
-- 분할 입금·승인 취소는 시간 순으로 늘어나는 이벤트이므로 jsonb 가 아니라 원장 테이블이다.
-- 합계는 트리거로 견적에 캐시한다.

alter table public.program_quotes
  add column if not exists payment_status text not null default 'unpaid',
  add column if not exists paid_krw int not null default 0,
  add column if not exists paid_at timestamptz,
  add column if not exists sold_by uuid references public.profiles(id) on delete set null;

alter table public.program_quotes
  drop constraint if exists program_quotes_payment_status_check;
alter table public.program_quotes
  add constraint program_quotes_payment_status_check
  check (payment_status in ('unpaid', 'partial', 'paid', 'refunded'));

comment on column public.program_quotes.payment_status is
  'Q3(a) — 미결제여도 차감을 막지 않는다. 대신 미수 배지로 노출한다.';
comment on column public.program_quotes.sold_by is
  'E8 — 원장이 여럿인 샵의 실적 귀속. author_id 와 달리 판매 확정자다.';

create table if not exists public.program_quote_payments (
  id          uuid primary key default gen_random_uuid(),
  quote_id    uuid not null references public.program_quotes(id) on delete cascade,
  amount_krw  int  not null,
  method      text not null default 'cash'
              check (method in ('cash', 'card', 'transfer', 'etc')),
  note        text not null default '',
  received_by uuid references public.profiles(id) on delete set null,
  received_at timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create index if not exists program_quote_payments_quote_idx
  on public.program_quote_payments (quote_id, received_at);

comment on table public.program_quote_payments is
  'PRD v7.2 — append-only 입금 원장. 취소는 삭제가 아니라 음수 행으로 남긴다.';
comment on column public.program_quote_payments.amount_krw is
  '음수 = 카드 승인 취소 / 환불 이벤트. 이력을 지우지 않는다.';

create or replace function public.program_sync_quote_paid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote_id uuid := coalesce(new.quote_id, old.quote_id);
  v_sum int;
  v_due int;
begin
  select coalesce(sum(amount_krw), 0) into v_sum
    from public.program_quote_payments
   where quote_id = v_quote_id;

  select payable_krw into v_due
    from public.program_quotes
   where id = v_quote_id;

  update public.program_quotes
     set paid_krw = v_sum,
         paid_at = case
           when v_sum >= coalesce(v_due, 0) and v_sum > 0 then now()
           else null end,
         payment_status = case
           when v_sum <= 0 then 'unpaid'
           when v_sum >= coalesce(v_due, 0) then 'paid'
           else 'partial' end
   where id = v_quote_id;

  return null;
end $$;

drop trigger if exists program_quote_payments_sync on public.program_quote_payments;
create trigger program_quote_payments_sync
  after insert or update or delete on public.program_quote_payments
  for each row execute function public.program_sync_quote_paid();

alter table public.program_quote_payments enable row level security;

drop policy if exists program_quote_payments_director on public.program_quote_payments;
create policy program_quote_payments_director
  on public.program_quote_payments for all
  using (
    exists (
      select 1 from public.program_quotes q
      where q.id = quote_id
        and public.program_shop_is_director(q.shop_id)
    )
  )
  with check (
    exists (
      select 1 from public.program_quotes q
      where q.id = quote_id
        and public.program_shop_is_director(q.shop_id)
    )
  );

notify pgrst, 'reload schema';
