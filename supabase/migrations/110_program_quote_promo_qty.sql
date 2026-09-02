-- PRD v7.1 — 같은 프로모션을 견적에 여러 장 붙인다.
-- 109 의 PK (quote_id, promotion_id) 는 유지하고 qty 로 장수를 센다.

alter table public.program_quote_promos
  add column if not exists qty int not null default 1;

alter table public.program_quote_promos
  drop constraint if exists program_quote_promos_qty_check;

alter table public.program_quote_promos
  add constraint program_quote_promos_qty_check
  check (qty > 0 and qty <= 9);

comment on column public.program_quote_promos.qty is
  '같은 카탈로그 혜택을 이 견적에 몇 장 붙였는지. extra_visits/value_krw/discount_krw 에 곱한다.';

create or replace function public.accept_program_quote(
  p_quote_id    uuid,
  p_customer_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote     public.program_quotes;
  v_chosen    jsonb;
  v_visits    int;
  v_extra     int;
  v_paid      int;
  v_unit      int;
  v_member    jsonb;
  v_customer  public.customers;
begin
  select * into v_quote
    from public.program_quotes
   where id = p_quote_id
     for update;

  if not found then
    raise exception 'program_quote % not found', p_quote_id
      using errcode = 'P0002';
  end if;

  if not public.program_shop_is_director(v_quote.shop_id) then
    raise exception 'not director of shop'
      using errcode = '42501';
  end if;

  if p_customer_id is null then
    raise exception 'customer_id required'
      using errcode = '22023';
  end if;

  select * into v_customer
    from public.customers
   where id = p_customer_id
     for update;

  if not found then
    raise exception 'customer % not found', p_customer_id
      using errcode = 'P0002';
  end if;

  if v_quote.chosen_package_id is not null
     and (v_quote.snapshot -> 'right' ->> 'id') = v_quote.chosen_package_id::text then
    v_chosen := v_quote.snapshot -> 'right';
  else
    v_chosen := v_quote.snapshot -> 'left';
  end if;

  v_visits := greatest(coalesce((v_chosen ->> 'visit_count')::int, 1), 1);
  v_paid   := greatest(v_quote.payable_krw, 0);

  select coalesce(sum(pr.extra_visits * coalesce(qp.qty, 1)), 0)
    into v_extra
    from public.program_quote_promos qp
    join public.program_promotions pr on pr.id = qp.promotion_id
   where qp.quote_id = p_quote_id;

  v_visits := v_visits + coalesce(v_extra, 0);
  v_unit := case when v_visits > 0 then (v_paid / v_visits) else 0 end;

  v_member := jsonb_build_object(
    'id', gen_random_uuid()::text,
    'service_name', coalesce(v_chosen ->> 'name', 'Program'),
    'total_visits', v_visits,
    'used_visits', 0,
    'paid_amount', v_paid,
    'per_session_value', v_unit
  );

  update public.customers
     set memberships = coalesce(memberships, '[]'::jsonb) || jsonb_build_array(v_member)
   where id = p_customer_id;

  update public.program_quotes
     set customer_id = p_customer_id,
         status = 'accepted',
         accepted_at = now()
   where id = p_quote_id
  returning to_jsonb(program_quotes.*) into v_chosen;

  return v_chosen;
end $$;

grant execute on function public.accept_program_quote(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
