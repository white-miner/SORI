-- 스마트 회원권(디지털 티켓) — 다중 샵 B2B2C 지갑용

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
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists membership_tickets_phone_idx
  on public.membership_tickets (customer_phone_digits);

create index if not exists membership_tickets_customer_idx
  on public.membership_tickets (customer_id);

create index if not exists membership_tickets_shop_idx
  on public.membership_tickets (shop_id);

comment on table public.membership_tickets is
  '스마트 회원권 티켓 지갑 (샵별 상품·잔여·만료)';

alter table public.membership_tickets enable row level security;

drop policy if exists "mvp_membership_tickets_select" on public.membership_tickets;
drop policy if exists "mvp_membership_tickets_insert" on public.membership_tickets;
drop policy if exists "mvp_membership_tickets_update" on public.membership_tickets;
drop policy if exists "mvp_membership_tickets_delete" on public.membership_tickets;
create policy "mvp_membership_tickets_select" on public.membership_tickets for select using (true);
create policy "mvp_membership_tickets_insert" on public.membership_tickets for insert with check (true);
create policy "mvp_membership_tickets_update" on public.membership_tickets for update using (true);
create policy "mvp_membership_tickets_delete" on public.membership_tickets for delete using (true);

-- customers.memberships jsonb → membership_tickets 동기화 헬퍼
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
begin
  select * into c from public.customers where id = p_customer_id;
  if not found then
    return;
  end if;

  -- 기존 티켓 정리 후 재생성 (jsonb 가 소스)
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
      ticket_name, total_visits, used_visits, expires_at, is_active, updated_at
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
      updated_at = now();
  end loop;
end;
$$;

grant execute on function public.sync_membership_tickets_for_customer(uuid) to anon, authenticated;

-- 차트 방문 확인 후 care_name 매칭 티켓 1회 차감 RPC
create or replace function public.deduct_membership_ticket(
  p_customer_id uuid,
  p_care_name text
)
returns table (
  deducted boolean,
  ticket_id text,
  remaining int,
  message text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  t record;
  care_norm text;
  name_norm text;
begin
  care_norm := lower(regexp_replace(coalesce(p_care_name, ''), '\s+|회권', '', 'g'));
  if care_norm = '' then
    deducted := false;
    ticket_id := null;
    remaining := 0;
    message := '진행 서비스가 없어 회원권을 차감하지 않았습니다.';
    return next;
    return;
  end if;

  for t in
    select * from public.membership_tickets
    where customer_id = p_customer_id
      and is_active = true
      and total_visits > used_visits
    order by updated_at desc
  loop
    name_norm := lower(regexp_replace(coalesce(t.ticket_name, ''), '\s+|회권', '', 'g'));
    if name_norm = care_norm
       or position(care_norm in name_norm) > 0
       or position(name_norm in care_norm) > 0 then
      update public.membership_tickets
      set
        used_visits = used_visits + 1,
        is_active = (total_visits - (used_visits + 1)) > 0,
        updated_at = now()
      where id = t.id
      returning * into t;

      -- customers.memberships jsonb 도 동기
      update public.customers c
      set memberships = (
        select coalesce(jsonb_agg(
          case
            when elem->>'id' = t.id then
              jsonb_set(elem, '{used_visits}', to_jsonb(t.used_visits))
            else elem
          end
        ), '[]'::jsonb)
        from jsonb_array_elements(coalesce(c.memberships, '[]'::jsonb)) elem
      ),
      membership_used_visits = t.used_visits,
      updated_at = now()
      where c.id = p_customer_id;

      deducted := true;
      ticket_id := t.id;
      remaining := greatest(t.total_visits - t.used_visits, 0);
      message := t.ticket_name || ' 회원권 1회 차감 (잔여 ' || remaining || '회)';
      return next;
      return;
    end if;
  end loop;

  deducted := false;
  ticket_id := null;
  remaining := 0;
  message := '진행 서비스와 일치하는 회원권이 없어 차감하지 않았습니다.';
  return next;
end;
$$;

grant execute on function public.deduct_membership_ticket(uuid, text) to anon, authenticated;

-- 기존 customers.memberships 백필
do $$
declare
  r record;
begin
  for r in select id from public.customers
  loop
    perform public.sync_membership_tickets_for_customer(r.id);
  end loop;
end $$;
