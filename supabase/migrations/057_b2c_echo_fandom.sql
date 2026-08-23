-- 057: B2C customer Echo wallets, Fan-Boost, customer faucet cap 25E/mo

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Wallets: owner_type shop | customer
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.wallets
  add column if not exists owner_type text,
  add column if not exists customer_id uuid references public.customers (id) on delete cascade;

update public.wallets
set owner_type = 'shop'
where owner_type is null;

alter table public.wallets
  alter column owner_type set default 'shop';

alter table public.wallets
  alter column owner_type set not null;

alter table public.wallets
  drop constraint if exists wallets_owner_type_check;

alter table public.wallets
  add constraint wallets_owner_type_check
  check (owner_type in ('shop', 'customer'));

-- Relax shop_id for customer wallets
alter table public.wallets alter column shop_id drop not null;

-- Drop legacy unique(shop_id) if present; replace with partial uniques
do $$
declare
  cname text;
begin
  select conname into cname
  from pg_constraint
  where conrelid = 'public.wallets'::regclass
    and contype = 'u'
    and pg_get_constraintdef(oid) ilike '%shop_id%';
  if cname is not null then
    execute format('alter table public.wallets drop constraint %I', cname);
  end if;
exception when others then
  null;
end $$;

drop index if exists public.wallets_shop_id_key;
create unique index if not exists wallets_shop_owner_unique
  on public.wallets (shop_id)
  where owner_type = 'shop' and shop_id is not null;

create unique index if not exists wallets_customer_owner_unique
  on public.wallets (customer_id)
  where owner_type = 'customer' and customer_id is not null;

alter table public.wallets
  drop constraint if exists wallets_owner_shape_check;

alter table public.wallets
  add constraint wallets_owner_shape_check check (
    (owner_type = 'shop' and shop_id is not null and customer_id is null)
    or (owner_type = 'customer' and customer_id is not null)
  );

comment on column public.wallets.owner_type is
  'shop = 원장/B2B 지갑 · customer = B2C 고객 Echo 지갑';
comment on column public.wallets.customer_id is
  'B2C 지갑 소유 고객 (owner_type=customer)';

-- point_transactions: allow customer ledger rows
alter table public.point_transactions
  add column if not exists customer_id uuid references public.customers (id) on delete set null;

alter table public.point_transactions
  alter column shop_id drop not null;

alter table public.point_transactions
  drop constraint if exists point_transactions_kind_check;

alter table public.point_transactions
  add constraint point_transactions_kind_check
  check (kind in (
    'earn_review',
    'earn_case_share',
    'earn_comment',
    'earn_best_comment',
    'earn_visit',
    'earn_qa',
    'purchase',
    'unlock_spend',
    'unlock_revenue',
    'shop_spend',
    'boost_spend',
    'fan_boost_spend',
    'subscription_grant',
    'promo_grant',
    'tier_grant',
    'expire',
    'refund',
    'adjust'
  ));

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) boost_placements: Fan-Boost payer + source label
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.boost_placements
  add column if not exists source text,
  add column if not exists paid_by_customer_id uuid
    references public.customers (id) on delete set null,
  add column if not exists paid_by_wallet_id uuid
    references public.wallets (id) on delete set null,
  add column if not exists fan_display_name text not null default '';

update public.boost_placements
set source = coalesce(nullif(source, ''), 'shop_ad')
where source is null or source = '';

alter table public.boost_placements
  alter column source set default 'shop_ad';

alter table public.boost_placements
  drop constraint if exists boost_placements_source_check;

alter table public.boost_placements
  add constraint boost_placements_source_check
  check (source in ('shop_ad', 'fan_boost'));

comment on column public.boost_placements.source is
  'shop_ad = 원장 자비 부스터 · fan_boost = 고객 Fan-Boost (정산금 무관)';
comment on column public.boost_placements.paid_by_customer_id is
  'Fan-Boost 결제 고객';

-- In-app fan gift notifications (push channel stub)
create table if not exists public.shop_notifications (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  kind text not null default 'fan_boost'
    check (kind in ('fan_boost', 'tip', 'system')),
  title text not null default '',
  body text not null default '',
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_shop_notifications_shop_created
  on public.shop_notifications (shop_id, created_at desc);

alter table public.shop_notifications enable row level security;
drop policy if exists "mvp_shop_notifications_all" on public.shop_notifications;
create policy "mvp_shop_notifications_all"
  on public.shop_notifications for all using (true) with check (true);

-- Customer faucet quota (parallel to shop echo_earn_quota)
create table if not exists public.echo_earn_quota_customer (
  customer_id uuid not null references public.customers (id) on delete cascade,
  period_type text not null check (period_type in ('day', 'week', 'month')),
  period_key text not null,
  kind text not null,
  amount int not null default 0 check (amount >= 0),
  updated_at timestamptz not null default now(),
  primary key (customer_id, period_type, period_key, kind)
);

comment on table public.echo_earn_quota_customer is
  'B2C Free Echo faucet 캡 — 월 하드캡 25E.';

alter table public.echo_earn_quota_customer enable row level security;
drop policy if exists "mvp_echo_earn_quota_customer_all" on public.echo_earn_quota_customer;
create policy "mvp_echo_earn_quota_customer_all"
  on public.echo_earn_quota_customer for all using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) ensure_customer_wallet + debit/credit by wallet
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.ensure_shop_wallet(p_shop_id uuid)
returns public.wallets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.wallets%rowtype;
  v_owner uuid;
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  select * into v_row
  from public.wallets
  where owner_type = 'shop' and shop_id = p_shop_id;
  if found then
    return v_row;
  end if;

  select owner_user_id into v_owner from public.shops where id = p_shop_id;

  insert into public.wallets (shop_id, owner_user_id, owner_type)
  select p_shop_id, v_owner, 'shop'
  where not exists (
    select 1 from public.wallets
    where owner_type = 'shop' and shop_id = p_shop_id
  );

  select * into v_row
  from public.wallets
  where owner_type = 'shop' and shop_id = p_shop_id;

  return v_row;
end;
$$;

create or replace function public.ensure_customer_wallet(p_customer_id uuid)
returns public.wallets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.wallets%rowtype;
  v_user uuid;
  v_shop uuid;
begin
  if p_customer_id is null then
    raise exception 'customer_id required';
  end if;

  select * into v_row
  from public.wallets
  where owner_type = 'customer' and customer_id = p_customer_id;
  if found then
    return v_row;
  end if;

  select user_id, shop_id into v_user, v_shop
  from public.customers where id = p_customer_id;
  if not found then
    raise exception 'customer not found';
  end if;

  insert into public.wallets (
    shop_id, owner_user_id, owner_type, customer_id
  )
  select v_shop, v_user, 'customer', p_customer_id
  where not exists (
    select 1 from public.wallets
    where owner_type = 'customer' and customer_id = p_customer_id
  );

  select * into v_row
  from public.wallets
  where owner_type = 'customer' and customer_id = p_customer_id;

  return v_row;
end;
$$;

create or replace function public.debit_echo_wallet(
  p_wallet_id uuid,
  p_amount int,
  p_kind text,
  p_ref_type text default '',
  p_ref_id uuid default null,
  p_note text default '',
  p_ledger_shop_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.wallets%rowtype;
  v_need int := coalesce(p_amount, 0);
  v_from_free int := 0;
  v_from_paid int := 0;
  v_total int;
  v_tx_id uuid;
  v_kind text := lower(trim(coalesce(p_kind, '')));
  v_settlement_before int;
  v_shop uuid;
begin
  if v_need <= 0 then
    raise exception 'debit amount must be > 0';
  end if;
  if v_kind like 'withdraw%' or v_kind in ('market_sale', 'affiliate_payout', 'seminar_settle') then
    raise exception 'kind % forbidden on echo ledger', v_kind;
  end if;

  select * into v_wallet from public.wallets where id = p_wallet_id for update;
  if not found then
    raise exception 'wallet not found';
  end if;

  v_settlement_before := v_wallet.settlement_balance;
  v_total := v_wallet.point_free_balance + v_wallet.point_paid_balance;
  if v_total < v_need then
    raise exception 'insufficient points: have %, need %', v_total, v_need
      using errcode = 'P0001';
  end if;

  v_from_free := least(v_wallet.point_free_balance, v_need);
  v_from_paid := v_need - v_from_free;

  update public.wallets
  set point_free_balance = point_free_balance - v_from_free,
      point_paid_balance = point_paid_balance - v_from_paid,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  if v_wallet.settlement_balance is distinct from v_settlement_before then
    raise exception 'settlement_balance must not change on echo debit';
  end if;

  v_shop := coalesce(p_ledger_shop_id, v_wallet.shop_id);

  if v_from_free > 0 then
    insert into public.point_transactions (
      wallet_id, shop_id, customer_id, amount, bucket, kind,
      ref_type, ref_id, note,
      balance_point_free_after, balance_point_paid_after
    ) values (
      v_wallet.id, v_shop, v_wallet.customer_id, -v_from_free, 'free', v_kind,
      coalesce(p_ref_type, ''), p_ref_id, coalesce(p_note, ''),
      v_wallet.point_free_balance, v_wallet.point_paid_balance
    )
    returning id into v_tx_id;
  end if;

  if v_from_paid > 0 then
    insert into public.point_transactions (
      wallet_id, shop_id, customer_id, amount, bucket, kind,
      ref_type, ref_id, note,
      balance_point_free_after, balance_point_paid_after
    ) values (
      v_wallet.id, v_shop, v_wallet.customer_id, -v_from_paid, 'paid', v_kind,
      coalesce(p_ref_type, ''), p_ref_id, coalesce(p_note, ''),
      v_wallet.point_free_balance, v_wallet.point_paid_balance
    )
    returning id into v_tx_id;
  end if;

  return jsonb_build_object(
    'wallet_id', v_wallet.id,
    'spent', v_need,
    'from_free', v_from_free,
    'from_paid', v_from_paid,
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'settlement_balance', v_wallet.settlement_balance,
    'tx_id', v_tx_id
  );
end;
$$;

create or replace function public.credit_free_echo_customer(
  p_customer_id uuid,
  p_amount int,
  p_kind text,
  p_ref_type text default '',
  p_ref_id uuid default null,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_want int := greatest(coalesce(p_amount, 0), 0);
  v_kind text := lower(trim(coalesce(p_kind, '')));
  v_month_key text := public.echo_period_key('month');
  v_week_key text := public.echo_period_key('week');
  v_month_used int := 0;
  v_kind_used int := 0;
  v_month_cap int := 25; -- B2C hard cap
  v_kind_cap int := 0;
  v_grant int;
  v_wallet public.wallets%rowtype;
  v_tx public.point_transactions%rowtype;
begin
  if p_customer_id is null or v_want <= 0 then
    return jsonb_build_object('ok', false, 'granted', 0, 'reason', 'noop');
  end if;

  -- kind caps (monthly-ish via week for sparse missions)
  v_kind_cap := case v_kind
    when 'earn_review' then 10   -- 5E × 2/mo tracked as week budget
    when 'earn_visit' then 12    -- 3E × 4/mo
    when 'earn_qa' then 6        -- 2E × 3/week
    else 5
  end;

  select coalesce(sum(amount), 0) into v_month_used
  from public.echo_earn_quota_customer
  where customer_id = p_customer_id
    and period_type = 'month'
    and period_key = v_month_key
    and kind = '_total';

  select coalesce(amount, 0) into v_kind_used
  from public.echo_earn_quota_customer
  where customer_id = p_customer_id
    and period_type = 'week'
    and period_key = v_week_key
    and kind = v_kind;

  v_grant := least(
    v_want,
    greatest(v_month_cap - v_month_used, 0),
    greatest(v_kind_cap - v_kind_used, 0)
  );

  if v_grant <= 0 then
    return jsonb_build_object(
      'ok', true, 'granted', 0, 'capped', true,
      'month_used', v_month_used, 'reason', 'faucet_cap'
    );
  end if;

  v_wallet := public.ensure_customer_wallet(p_customer_id);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  update public.wallets
  set point_free_balance = point_free_balance + v_grant,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  insert into public.point_transactions (
    wallet_id, shop_id, customer_id, amount, bucket, kind,
    ref_type, ref_id, note,
    balance_point_free_after, balance_point_paid_after
  ) values (
    v_wallet.id, v_wallet.shop_id, p_customer_id, v_grant, 'free', v_kind,
    coalesce(p_ref_type, ''), p_ref_id, coalesce(p_note, ''),
    v_wallet.point_free_balance, v_wallet.point_paid_balance
  )
  returning * into v_tx;

  insert into public.echo_earn_quota_customer as q (
    customer_id, period_type, period_key, kind, amount, updated_at
  ) values
    (p_customer_id, 'month', v_month_key, '_total', v_grant, now()),
    (p_customer_id, 'week', v_week_key, v_kind, v_grant, now())
  on conflict (customer_id, period_type, period_key, kind) do update
    set amount = q.amount + excluded.amount,
        updated_at = now();

  return jsonb_build_object(
    'ok', true,
    'granted', v_grant,
    'requested', v_want,
    'capped', v_grant < v_want,
    'month_used', v_month_used + v_grant,
    'point_free_balance', v_wallet.point_free_balance,
    'settlement_balance', v_wallet.settlement_balance
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) Customer faucet triggers
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.earn_echo_on_customer_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_text text;
begin
  if tg_op = 'INSERT'
     or (tg_op = 'UPDATE' and old.status is distinct from new.status) then
    if new.status in ('published', 'accepted') and new.customer_id is not null then
      v_text := coalesce(new.original_text, '');
      if char_length(trim(v_text)) >= 80 then
        perform public.credit_free_echo_customer(
          new.customer_id, 5, 'earn_review',
          'customer_review', new.id,
          '시술 B/A 리뷰 +5 Echo'
        );
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_earn_echo_customer_review on public.customer_reviews;
create trigger trg_earn_echo_customer_review
  after insert or update of status on public.customer_reviews
  for each row execute function public.earn_echo_on_customer_review();

create or replace function public.earn_echo_on_visit_checked()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.visit_checked = true
     and (tg_op = 'INSERT' or coalesce(old.visit_checked, false) = false)
     and new.customer_id is not null then
    perform public.credit_free_echo_customer(
      new.customer_id, 3, 'earn_visit',
      'customer_chart', new.id,
      '방문 완료 +3 Echo'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_earn_echo_visit_checked on public.customer_charts;
create trigger trg_earn_echo_visit_checked
  after insert or update of visit_checked on public.customer_charts
  for each row execute function public.earn_echo_on_visit_checked();

-- Q&A: community_posts authored by a linked customer (interior as skin Q for MVP)
create or replace function public.earn_echo_on_customer_qa_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer uuid;
begin
  if new.status = 'published'
     and new.author_user_id is not null
     and char_length(trim(coalesce(new.body, ''))) >= 60 then
    select c.id into v_customer
    from public.customers c
    where c.user_id = new.author_user_id
    order by c.updated_at desc nulls last
    limit 1;
    if v_customer is not null then
      perform public.credit_free_echo_customer(
        v_customer, 2, 'earn_qa',
        'community_post', new.id,
        '피부 고민 Q&A +2 Echo'
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_earn_echo_customer_qa on public.community_posts;
create trigger trg_earn_echo_customer_qa
  after insert on public.community_posts
  for each row execute function public.earn_echo_on_customer_qa_post();

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) purchase_fan_boost — customer Echo sink, shop placement, no settlement
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.purchase_fan_boost(
  p_customer_id uuid,
  p_sku text,
  p_target_type text default 'chart',
  p_target_id uuid default null,
  p_fan_display_name text default '',
  p_region_code text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.point_shop_items%rowtype;
  v_wallet public.wallets%rowtype;
  v_target_shop uuid;
  v_shop_wallet public.wallets%rowtype;
  v_settlement_before int;
  v_settlement_after int;
  v_debit jsonb;
  v_placement public.boost_placements%rowtype;
  v_sku text := lower(trim(coalesce(p_sku, '')));
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_need int;
  v_starts timestamptz := now();
  v_ends timestamptz;
  v_chart_id uuid;
  v_post_id uuid;
  v_name text;
begin
  if p_customer_id is null then
    raise exception 'customer_id required';
  end if;
  if v_sku = '' or p_target_id is null then
    raise exception 'sku and target_id required';
  end if;
  if v_type not in ('chart', 'community_post') then
    raise exception 'invalid target_type';
  end if;

  select * into v_item
  from public.point_shop_items
  where sku = v_sku and is_active = true and category = 'booster';
  if not found then
    raise exception 'booster sku not found: %', v_sku;
  end if;

  if v_type = 'chart' then
    select shop_id into v_target_shop from public.customer_charts where id = p_target_id;
    v_chart_id := p_target_id;
  else
    select shop_id into v_target_shop from public.community_posts where id = p_target_id;
    v_post_id := p_target_id;
  end if;

  if v_target_shop is null then
    raise exception 'target shop not found';
  end if;

  -- Lock target shop settlement as proof it never moves
  v_shop_wallet := public.ensure_shop_wallet(v_target_shop);
  select * into v_shop_wallet from public.wallets where id = v_shop_wallet.id for update;
  v_settlement_before := v_shop_wallet.settlement_balance;

  v_wallet := public.ensure_customer_wallet(p_customer_id);
  v_need := v_item.price_points;

  v_debit := public.debit_echo_wallet(
    v_wallet.id, v_need, 'fan_boost_spend',
    'point_shop_item', v_item.id,
    'Fan-Boost ' || v_item.title,
    v_target_shop
  );

  select settlement_balance into v_settlement_after
  from public.wallets where id = v_shop_wallet.id;
  if v_settlement_after is distinct from v_settlement_before then
    raise exception 'Fan-Boost must not change shop settlement_balance';
  end if;

  -- Customer wallet settlement must stay 0 / unchanged
  select * into v_wallet from public.wallets where id = v_wallet.id;
  if coalesce(v_wallet.settlement_balance, 0) <> 0 then
    raise exception 'customer wallet must not hold settlement';
  end if;

  v_ends := v_starts + make_interval(hours => v_item.duration_hours);

  update public.boost_placements
  set status = 'cancelled', updated_at = now()
  where status = 'active'
    and target_type = v_type
    and target_id = p_target_id;

  select coalesce(nullif(trim(p_fan_display_name), ''), c.name, '팬')
  into v_name
  from public.customers c where c.id = p_customer_id;

  insert into public.boost_placements (
    shop_id, item_id, item_sku, target_type, target_id,
    post_id, chart_id, region_code,
    starts_at, ends_at, status, points_spent,
    source, paid_by_customer_id, paid_by_wallet_id, fan_display_name
  ) values (
    v_target_shop, v_item.id, v_item.sku, v_type, p_target_id,
    v_post_id, v_chart_id, coalesce(p_region_code, ''),
    v_starts, v_ends, 'active', v_need,
    'fan_boost', p_customer_id, v_wallet.id, coalesce(v_name, '팬')
  )
  returning * into v_placement;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_target_shop,
    'fan_boost',
    '팬 부스터 선물',
    format('팬 %s님이 노출 부스터를 선물했습니다!', coalesce(v_name, '○○')),
    jsonb_build_object(
      'placement_id', v_placement.id,
      'customer_id', p_customer_id,
      'sku', v_item.sku,
      'chart_id', v_chart_id,
      'fan_name', coalesce(v_name, '팬')
    )
  );

  return jsonb_build_object(
    'ok', true,
    'sku', v_item.sku,
    'points_spent', v_need,
    'source', 'fan_boost',
    'target_shop_id', v_target_shop,
    'settlement_balance', v_settlement_after,
    'settlement_unchanged', true,
    'debit', v_debit,
    'placement', to_jsonb(v_placement),
    'notification', true
  );
end;
$$;

comment on function public.purchase_fan_boost(uuid, text, text, uuid, text, text) is
  '고객 Echo로 원장 케이스 Fan-Boost. settlement_balance 절대 미변경.';

create or replace function public.get_customer_wallet(p_customer_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_w public.wallets%rowtype;
begin
  v_w := public.ensure_customer_wallet(p_customer_id);
  select * into v_w from public.wallets where id = v_w.id;
  return jsonb_build_object(
    'id', v_w.id,
    'owner_type', v_w.owner_type,
    'customer_id', v_w.customer_id,
    'shop_id', v_w.shop_id,
    'point_free_balance', v_w.point_free_balance,
    'point_paid_balance', v_w.point_paid_balance,
    'point_total', v_w.point_free_balance + v_w.point_paid_balance,
    'settlement_balance', v_w.settlement_balance,
    'updated_at', v_w.updated_at
  );
end;
$$;

create or replace function public.purchase_sori_points_customer(
  p_customer_id uuid,
  p_amount int,
  p_sku text default 'sori_e_55',
  p_order_ref text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_amount int := coalesce(p_amount, 0);
  v_wallet public.wallets%rowtype;
begin
  if v_amount <= 0 then
    raise exception 'purchase amount must be > 0';
  end if;
  v_wallet := public.ensure_customer_wallet(p_customer_id);
  update public.wallets
  set point_paid_balance = point_paid_balance + v_amount,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  insert into public.point_transactions (
    wallet_id, shop_id, customer_id, amount, bucket, kind,
    ref_type, note,
    balance_point_free_after, balance_point_paid_after
  ) values (
    v_wallet.id, v_wallet.shop_id, p_customer_id, v_amount, 'paid', 'purchase',
    'iap_order', coalesce(nullif(trim(p_order_ref), ''), p_sku),
    v_wallet.point_free_balance, v_wallet.point_paid_balance
  );

  return jsonb_build_object(
    'ok', true,
    'customer_id', p_customer_id,
    'amount', v_amount,
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'settlement_balance', v_wallet.settlement_balance
  );
end;
$$;

grant execute on function public.ensure_customer_wallet(uuid)
  to anon, authenticated, service_role;
grant execute on function public.debit_echo_wallet(uuid, int, text, text, uuid, text, uuid)
  to anon, authenticated, service_role;
grant execute on function public.credit_free_echo_customer(uuid, int, text, text, uuid, text)
  to anon, authenticated, service_role;
grant execute on function public.purchase_fan_boost(uuid, text, text, uuid, text, text)
  to anon, authenticated, service_role;
grant execute on function public.get_customer_wallet(uuid)
  to anon, authenticated, service_role;
grant execute on function public.purchase_sori_points_customer(uuid, int, text, text)
  to anon, authenticated, service_role;
