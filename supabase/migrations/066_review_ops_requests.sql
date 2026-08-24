-- 066_review_ops_requests.sql
-- Review ops P1: request → convert → remind pipeline.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Table
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.review_request_events (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete cascade,
  chart_id uuid references public.customer_charts (id) on delete set null,
  channel text not null default 'qr'
    check (channel in ('qr', 'link', 'alimtalk', 'manual')),
  status text not null default 'sent'
    check (status in ('sent', 'opened', 'converted', 'expired', 'cancelled')),
  sent_at timestamptz not null default now(),
  opened_at timestamptz,
  converted_review_id uuid references public.customer_reviews (id) on delete set null,
  remind_at timestamptz,
  reminded_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists review_request_events_shop_sent_idx
  on public.review_request_events (shop_id, sent_at desc);

create index if not exists review_request_events_customer_status_idx
  on public.review_request_events (customer_id, status);

create index if not exists review_request_events_remind_due_idx
  on public.review_request_events (remind_at)
  where reminded_at is null and status = 'sent';

comment on table public.review_request_events is
  'Director review-request pipeline: sent → converted (+ optional remind).';

alter table public.review_request_events enable row level security;

drop policy if exists review_request_events_shop_select on public.review_request_events;
create policy review_request_events_shop_select
  on public.review_request_events for select
  using (
    exists (
      select 1 from public.shops s
      where s.id = shop_id
        and (
          s.owner_user_id = auth.uid()
          or exists (
            select 1 from public.shop_memberships m
            where m.shop_id = s.id and m.user_id = auth.uid()
          )
        )
    )
  );

-- Writes via security definer RPCs only.
grant select on public.review_request_events to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) insert_review_request_event
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.insert_review_request_event(
  p_customer_id uuid,
  p_chart_id uuid default null,
  p_channel text default 'qr',
  p_shop_id uuid default null,
  p_remind_hours int default 24
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_channel text := lower(trim(coalesce(p_channel, 'qr')));
  v_hours int := greatest(1, least(coalesce(p_remind_hours, 24), 168));
  v_id uuid;
  v_row public.review_request_events%rowtype;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_customer_id is null then
    raise exception 'customer_id required';
  end if;
  if v_channel not in ('qr', 'link', 'alimtalk', 'manual') then
    v_channel := 'qr';
  end if;

  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;

  if v_shop is null
     or not exists (
       select 1 from public.shops s
       where s.id = v_shop
         and (
           s.owner_user_id = v_uid
           or exists (
             select 1 from public.shop_memberships m
             where m.shop_id = s.id and m.user_id = v_uid
           )
         )
     ) then
    raise exception 'shop access denied';
  end if;

  if not exists (
    select 1 from public.customers c
    where c.id = p_customer_id and c.shop_id = v_shop
  ) then
    raise exception 'customer not in shop';
  end if;

  insert into public.review_request_events (
    shop_id, customer_id, chart_id, channel, status,
    sent_at, remind_at, created_by
  ) values (
    v_shop,
    p_customer_id,
    p_chart_id,
    v_channel,
    'sent',
    now(),
    now() + make_interval(hours => v_hours),
    v_uid
  )
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

grant execute on function public.insert_review_request_event(uuid, uuid, text, uuid, int)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) list_review_request_events
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_review_request_events(
  p_shop_id uuid default null,
  p_limit int default 80
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_limit int := greatest(1, least(coalesce(p_limit, 80), 200));
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;

  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;
  if v_shop is null then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(to_jsonb(e) order by e.sent_at desc)
    from (
      select *
      from public.review_request_events r
      where r.shop_id = v_shop
      order by r.sent_at desc
      limit v_limit
    ) e
  ), '[]'::jsonb);
end;
$$;

grant execute on function public.list_review_request_events(uuid, int)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) convert open requests when review appears
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.convert_review_request_events(
  p_customer_id uuid,
  p_review_id uuid,
  p_shop_id uuid default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_count int := 0;
begin
  if v_uid is null or p_customer_id is null or p_review_id is null then
    return 0;
  end if;

  if v_shop is null then
    select shop_id into v_shop from public.customer_reviews where id = p_review_id;
  end if;
  if v_shop is null then
    return 0;
  end if;

  update public.review_request_events r
  set
    status = 'converted',
    converted_review_id = p_review_id,
    updated_at = now()
  where r.shop_id = v_shop
    and r.customer_id = p_customer_id
    and r.status in ('sent', 'opened')
    and r.converted_review_id is null;

  get diagnostics v_count = row_count;
  return coalesce(v_count, 0);
end;
$$;

grant execute on function public.convert_review_request_events(uuid, uuid, uuid)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) mark reminded
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.mark_review_request_reminded(p_event_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or p_event_id is null then
    return false;
  end if;

  update public.review_request_events r
  set reminded_at = now(), updated_at = now()
  where r.id = p_event_id
    and r.reminded_at is null
    and exists (
      select 1 from public.shops s
      where s.id = r.shop_id
        and (
          s.owner_user_id = v_uid
          or exists (
            select 1 from public.shop_memberships m
            where m.shop_id = s.id and m.user_id = v_uid
          )
        )
    );

  return found;
end;
$$;

grant execute on function public.mark_review_request_reminded(uuid)
  to authenticated;
