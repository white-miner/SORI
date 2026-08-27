-- 071: membership_tickets + sync_membership_tickets_for_customer SSOT heal
-- Fix: merge_shop_customers (070) calls sync RPC that may be missing on partial DB apply.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) membership_tickets table (016 baseline + 022 finance columns)
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.membership_tickets (
  id text primary key,
  shop_id uuid not null references public.shops (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete cascade,
  customer_phone_digits text not null default '',
  ticket_name text not null default '',
  total_visits int not null default 0 check (total_visits >= 0),
  used_visits int not null default 0 check (used_visits >= 0),
  expires_at date,
  is_active boolean not null default true,
  paid_amount int not null default 0,
  per_session_value int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.membership_tickets
  add column if not exists paid_amount int not null default 0,
  add column if not exists per_session_value int not null default 0;

create index if not exists membership_tickets_phone_idx
  on public.membership_tickets (customer_phone_digits);

create index if not exists membership_tickets_customer_idx
  on public.membership_tickets (customer_id);

create index if not exists membership_tickets_shop_idx
  on public.membership_tickets (shop_id);

alter table public.membership_tickets enable row level security;

drop policy if exists "mvp_membership_tickets_select" on public.membership_tickets;
drop policy if exists "mvp_membership_tickets_insert" on public.membership_tickets;
drop policy if exists "mvp_membership_tickets_update" on public.membership_tickets;
drop policy if exists "mvp_membership_tickets_delete" on public.membership_tickets;
create policy "mvp_membership_tickets_select" on public.membership_tickets for select using (true);
create policy "mvp_membership_tickets_insert" on public.membership_tickets for insert with check (true);
create policy "mvp_membership_tickets_update" on public.membership_tickets for update using (true);
create policy "mvp_membership_tickets_delete" on public.membership_tickets for delete using (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) customers.memberships jsonb → membership_tickets sync RPC
--    Signature MUST be (uuid) — PostgREST param: p_customer_id
-- ═══════════════════════════════════════════════════════════════════════════

drop function if exists public.sync_membership_tickets_for_customer(uuid);

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
  tid text;
  tname text;
  total int;
  used int;
  exp date;
  paid int;
  per_val int;
begin
  if p_customer_id is null then
    return;
  end if;

  select * into c from public.customers where id = p_customer_id;
  if not found then
    return;
  end if;

  delete from public.membership_tickets where customer_id = p_customer_id;

  if c.memberships is null or jsonb_typeof(c.memberships) <> 'array' then
    return;
  end if;

  for item in select * from jsonb_array_elements(c.memberships)
  loop
    tid := coalesce(nullif(item->>'id', ''), gen_random_uuid()::text);
    tname := coalesce(nullif(item->>'service_name', ''), '회원권');
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

    insert into public.membership_tickets (
      id, shop_id, customer_id, customer_phone_digits,
      ticket_name, total_visits, used_visits, expires_at, is_active,
      paid_amount, per_session_value, updated_at
    ) values (
      tid,
      c.shop_id,
      c.id,
      regexp_replace(coalesce(c.phone, ''), '[^0-9]', '', 'g'),
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
      ticket_name = excluded.ticket_name,
      total_visits = excluded.total_visits,
      used_visits = excluded.used_visits,
      expires_at = excluded.expires_at,
      is_active = excluded.is_active,
      paid_amount = excluded.paid_amount,
      per_session_value = excluded.per_session_value,
      updated_at = now();
  end loop;
end;
$$;

comment on function public.sync_membership_tickets_for_customer(uuid) is
  'customers.memberships jsonb SSOT → membership_tickets wallet rows (delete+recreate).';

grant execute on function public.sync_membership_tickets_for_customer(uuid)
  to anon, authenticated, service_role;

-- PostgREST schema cache refresh hint (auto on DDL in Supabase).

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) merge_shop_customers — transaction safety note
--    Entire function body runs in ONE transaction (PostgREST RPC).
--    Any ERROR (incl. missing function) rolls back ALL prior DML in the call.
--    Re-apply 070 after this heal if merge function was partially created.
-- ═══════════════════════════════════════════════════════════════════════════
