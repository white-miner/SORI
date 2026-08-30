-- 095: Repair missing delete_shop_customers RPC (PGRST202 schema cache).
-- Idempotent recreate — same contract as 043.

create or replace function public.delete_shop_customers(p_ids uuid[])
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owned uuid[];
  v_deleted uuid[];
begin
  if p_ids is null or coalesce(cardinality(p_ids), 0) = 0 then
    return array[]::uuid[];
  end if;

  if cardinality(p_ids) > 50 then
    raise exception '한 번에 최대 50명까지 삭제할 수 있습니다.';
  end if;

  if v_uid is null then
    raise exception '로그인이 필요합니다. (auth.uid is null)';
  end if;

  select coalesce(array_agg(c.id), array[]::uuid[])
  into v_owned
  from public.customers c
  inner join public.shops s on s.id = c.shop_id
  where c.id = any (p_ids)
    and s.owner_user_id = v_uid;

  if coalesce(cardinality(v_owned), 0) = 0 then
    return array[]::uuid[];
  end if;

  begin
    delete from public.membership_tickets
    where customer_id = any (v_owned);
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.care_diary_notes
    where customer_id = any (v_owned);
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.shop_followers
    where customer_id = any (v_owned);
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.customer_reviews
    where customer_id = any (v_owned);
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.customer_charts
    where customer_id = any (v_owned);
  exception
    when undefined_table then null;
  end;

  with removed as (
    delete from public.customers
    where id = any (v_owned)
    returning id
  )
  select coalesce(array_agg(id), array[]::uuid[])
  into v_deleted
  from removed;

  return coalesce(v_deleted, array[]::uuid[]);
end;
$$;

comment on function public.delete_shop_customers(uuid[]) is
  '원장(shops.owner_user_id = auth.uid()) 소유 고객만 일괄 삭제. 성공한 customer id 배열 반환.';

grant execute on function public.delete_shop_customers(uuid[])
  to authenticated, anon;

notify pgrst, 'reload schema';
