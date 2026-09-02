-- PRD v7.2 — 수락 = 회원권 + 쿠폰 + 결제상태 + 사용이력을 한 트랜잭션으로 닫는다.
--
-- 클라이언트에서 4번 나눠 호출하면 중간 실패 시 회원권만 있고 돈 기록은 없는 상태가 생긴다.
-- v1(accept_program_quote)은 구버전 앱 호환을 위해 삭제하지 않는다.

create or replace function public.accept_program_quote_v2(
  p_quote_id       uuid,
  p_customer_id    uuid,
  p_payment_status text default 'unpaid',
  p_paid_krw       int  default 0,
  p_method         text default 'cash'
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote    public.program_quotes;
  v_chosen   jsonb;
  v_visits   int;
  v_extra    int;
  v_paid_due int;
  v_unit     int;
  v_mid      uuid;
  v_promo    record;
  v_coupons  jsonb;
  v_row      jsonb;
begin
  select * into v_quote
    from public.program_quotes
   where id = p_quote_id
     for update;

  if not found then
    raise exception 'program_quote % not found', p_quote_id using errcode = 'P0002';
  end if;

  if not public.program_shop_is_director(v_quote.shop_id) then
    raise exception 'not director of shop' using errcode = '42501';
  end if;

  if p_customer_id is null then
    raise exception 'customer_id required' using errcode = '22023';
  end if;

  perform 1 from public.customers where id = p_customer_id for update;
  if not found then
    raise exception 'customer % not found', p_customer_id using errcode = 'P0002';
  end if;

  if v_quote.chosen_package_id is not null
     and (v_quote.snapshot -> 'right' ->> 'id') = v_quote.chosen_package_id::text then
    v_chosen := v_quote.snapshot -> 'right';
  else
    v_chosen := v_quote.snapshot -> 'left';
  end if;

  v_visits   := greatest(coalesce((v_chosen ->> 'visit_count')::int, 1), 1);
  v_paid_due := greatest(v_quote.payable_krw, 0);

  -- 횟수 추가 혜택만 회원권에 더한다. next_visit_credit 은 쿠폰으로 분기한다.
  select coalesce(sum(pr.extra_visits * coalesce(qp.qty, 1)), 0)
    into v_extra
    from public.program_quote_promos qp
    join public.program_promotions pr on pr.id = qp.promotion_id
   where qp.quote_id = p_quote_id
     and pr.kind <> 'next_visit_credit';

  v_visits := v_visits + coalesce(v_extra, 0);
  v_unit := case when v_visits > 0 then (v_paid_due / v_visits) else 0 end;

  insert into public.program_memberships (
    shop_id, customer_id, source_quote_id, service_name,
    total_visits, paid_krw, per_session_krw
  ) values (
    v_quote.shop_id, p_customer_id, p_quote_id,
    coalesce(v_chosen ->> 'name', 'Program'),
    v_visits, v_paid_due, v_unit
  ) returning id into v_mid;

  -- 읽기 미러 유지 — 기존 화면 무중단
  update public.customers
     set memberships = coalesce(memberships, '[]'::jsonb) || jsonb_build_array(
           jsonb_build_object(
             'id', v_mid::text,
             'service_name', coalesce(v_chosen ->> 'name', 'Program'),
             'total_visits', v_visits,
             'used_visits', 0,
             'paid_amount', v_paid_due,
             'per_session_value', v_unit
           ))
   where id = p_customer_id;

  -- S7 — 미래가치는 회원권 횟수가 아니라 쿠폰 행으로 떨어진다.
  for v_promo in
    select pr.id, pr.title, pr.percent_off, pr.discount_krw,
           pr.extra_visits, pr.gift_qty, pr.valid_until,
           coalesce(qp.qty, 1) as qty
      from public.program_quote_promos qp
      join public.program_promotions pr on pr.id = qp.promotion_id
     where qp.quote_id = p_quote_id
       and pr.kind = 'next_visit_credit'
  loop
    insert into public.program_customer_coupons (
      shop_id, customer_id, issued_quote_id, promotion_id, title,
      percent_off, discount_krw, extra_visits, gift_qty, expires_at
    )
    select v_quote.shop_id, p_customer_id, p_quote_id, v_promo.id, v_promo.title,
           v_promo.percent_off, v_promo.discount_krw, v_promo.extra_visits,
           v_promo.gift_qty, v_promo.valid_until
      from generate_series(1, v_promo.qty);
  end loop;

  -- S6 — 사용 이력. 최근 사용순 정렬의 근거가 된다.
  update public.program_promotions pr
     set use_count = pr.use_count + 1,
         last_used_at = now()
    from public.program_quote_promos qp
   where qp.quote_id = p_quote_id
     and pr.id = qp.promotion_id;

  -- C11 — 수기 결제. PG 는 이번에도 범위 밖이다.
  if p_paid_krw > 0 then
    insert into public.program_quote_payments (quote_id, amount_krw, method)
    values (p_quote_id, p_paid_krw, p_method);
  end if;

  update public.program_quotes
     set customer_id = p_customer_id,
         status = 'accepted',
         accepted_at = now(),
         sold_by = coalesce(sold_by, auth.uid()),
         payment_status = case
           when p_paid_krw >= v_paid_due and p_paid_krw > 0 then 'paid'
           when p_paid_krw > 0 then 'partial'
           else p_payment_status end
   where id = p_quote_id
  returning to_jsonb(program_quotes.*) into v_row;

  select coalesce(jsonb_agg(to_jsonb(c.*)), '[]'::jsonb)
    into v_coupons
    from public.program_customer_coupons c
   where c.issued_quote_id = p_quote_id;

  return jsonb_build_object(
    'quote', v_row,
    'membership_id', v_mid::text,
    'coupons', v_coupons
  );
end $$;

grant execute on function
  public.accept_program_quote_v2(uuid, uuid, text, int, text) to authenticated;

comment on function public.accept_program_quote_v2(uuid, uuid, text, int, text) is
  'PRD v7.2 — 회원권·쿠폰·결제상태·사용이력을 한 트랜잭션으로 닫는다. v1 은 호환용 유지.';

-- 고객 보유 쿠폰 조회 — 재방문 즉시 식별용
create or replace function public.program_customer_coupon_counts(p_shop_id uuid)
returns table (customer_id uuid, unused_count int)
language sql
stable
security definer
set search_path = public
as $$
  select c.customer_id, count(*)::int
    from public.program_customer_coupons c
   where c.shop_id = p_shop_id
     and c.status = 'issued'
     and public.program_shop_is_director(p_shop_id)
   group by c.customer_id;
$$;

grant execute on function public.program_customer_coupon_counts(uuid) to authenticated;

notify pgrst, 'reload schema';
