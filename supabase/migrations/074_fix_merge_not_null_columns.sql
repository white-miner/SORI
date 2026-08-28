-- 074: membership_tickets NOT NULL denormalized columns (user_phone, customer_name)
-- Fix 23502 during merge → sync_membership_tickets_for_customer INSERT

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Schema heal — PO production may already have these NOT NULL columns
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.membership_tickets
  add column if not exists user_phone text,
  add column if not exists customer_name text;

update public.membership_tickets mt
set
  user_phone = coalesce(
    nullif(trim(mt.user_phone), ''),
    nullif(trim(c.phone), ''),
    ''
  ),
  customer_name = coalesce(
    nullif(trim(mt.customer_name), ''),
    nullif(trim(c.name), ''),
    '고객'
  )
from public.customers c
where mt.customer_id = c.id;

update public.membership_tickets
set
  user_phone = coalesce(user_phone, ''),
  customer_name = coalesce(customer_name, '고객')
where user_phone is null or customer_name is null;

alter table public.membership_tickets
  alter column user_phone set default '',
  alter column customer_name set default '고객';

do $$
begin
  alter table public.membership_tickets
    alter column user_phone set not null;
exception
  when others then null;
end $$;

do $$
begin
  alter table public.membership_tickets
    alter column customer_name set not null;
exception
  when others then null;
end $$;

comment on column public.membership_tickets.user_phone is
  'Denormalized customers.phone for wallet queries (NOT NULL, empty string if missing).';
comment on column public.membership_tickets.customer_name is
  'Denormalized customers.name for wallet display (NOT NULL).';

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) sync_membership_tickets_for_customer — populate all required columns
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.sync_membership_tickets_for_customer(
  p_customer_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  item jsonb;
  tid_text text;
  tid_uuid uuid;
  tname text;
  total int;
  used int;
  exp date;
  paid int;
  per_val int;
  v_id_is_uuid boolean;
  v_user_phone text;
  v_customer_name text;
  v_phone_digits text;
begin
  if p_customer_id is null then
    return;
  end if;

  select (udt_name = 'uuid')
  into v_id_is_uuid
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'membership_tickets'
    and column_name = 'id';

  v_id_is_uuid := coalesce(v_id_is_uuid, false);

  select * into c from public.customers where id = p_customer_id;
  if not found then
    return;
  end if;

  v_user_phone := coalesce(nullif(trim(c.phone), ''), '');
  v_customer_name := coalesce(nullif(trim(c.name), ''), '고객');
  v_phone_digits := regexp_replace(v_user_phone, '[^0-9]', '', 'g');

  delete from public.membership_tickets where customer_id = p_customer_id;

  if c.memberships is null or jsonb_typeof(c.memberships) <> 'array' then
    return;
  end if;

  for item in select * from jsonb_array_elements(c.memberships)
  loop
    tname := coalesce(nullif(trim(item->>'service_name'), ''), '회원권');
    total := greatest(coalesce((item->>'total_visits')::int, 0), 0);
    used := greatest(coalesce((item->>'used_visits')::int, 0), 0);
    paid := greatest(coalesce((item->>'paid_amount')::int, 0), 0);
    per_val := greatest(coalesce((item->>'per_session_value')::int, 0), 0);
    if per_val <= 0 and paid > 0 and total > 0 then
      per_val := round(paid::numeric / total::numeric)::int;
    end if;
    if total <= 0 then
      continue;
    end if;
    begin
      exp := nullif(item->>'expires_at', '')::date;
    exception when others then
      exp := null;
    end;

    if v_id_is_uuid then
      begin
        tid_uuid := coalesce(nullif(trim(item->>'id'), '')::uuid, gen_random_uuid());
      exception when others then
        tid_uuid := gen_random_uuid();
      end;

      insert into public.membership_tickets (
        id, shop_id, customer_id, customer_phone_digits,
        user_phone, customer_name,
        ticket_name, total_visits, used_visits, expires_at, is_active,
        paid_amount, per_session_value, updated_at
      ) values (
        tid_uuid,
        c.shop_id,
        c.id,
        v_phone_digits,
        v_user_phone,
        v_customer_name,
        tname,
        total,
        least(used, total),
        exp,
        (total - used) > 0,
        paid,
        per_val,
        now()
      )
      on conflict (id) do update set
        shop_id = excluded.shop_id,
        customer_id = excluded.customer_id,
        customer_phone_digits = excluded.customer_phone_digits,
        user_phone = excluded.user_phone,
        customer_name = excluded.customer_name,
        ticket_name = excluded.ticket_name,
        total_visits = excluded.total_visits,
        used_visits = excluded.used_visits,
        expires_at = excluded.expires_at,
        is_active = excluded.is_active,
        paid_amount = excluded.paid_amount,
        per_session_value = excluded.per_session_value,
        updated_at = now();
    else
      tid_text := coalesce(nullif(trim(item->>'id'), ''), gen_random_uuid()::text);

      insert into public.membership_tickets (
        id, shop_id, customer_id, customer_phone_digits,
        user_phone, customer_name,
        ticket_name, total_visits, used_visits, expires_at, is_active,
        paid_amount, per_session_value, updated_at
      ) values (
        tid_text,
        c.shop_id,
        c.id,
        v_phone_digits,
        v_user_phone,
        v_customer_name,
        tname,
        total,
        least(used, total),
        exp,
        (total - used) > 0,
        paid,
        per_val,
        now()
      )
      on conflict (id) do update set
        shop_id = excluded.shop_id,
        customer_id = excluded.customer_id,
        customer_phone_digits = excluded.customer_phone_digits,
        user_phone = excluded.user_phone,
        customer_name = excluded.customer_name,
        ticket_name = excluded.ticket_name,
        total_visits = excluded.total_visits,
        used_visits = excluded.used_visits,
        expires_at = excluded.expires_at,
        is_active = excluded.is_active,
        paid_amount = excluded.paid_amount,
        per_session_value = excluded.per_session_value,
        updated_at = now();
    end if;
  end loop;
end;
$$;

comment on function public.sync_membership_tickets_for_customer(uuid) is
  'customers.memberships jsonb SSOT → membership_tickets (user_phone/customer_name from customers).';

grant execute on function public.sync_membership_tickets_for_customer(uuid)
  to anon, authenticated, service_role;
