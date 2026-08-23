-- 055: Point shop + local exposure boosters (non-settlement spend only)

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Extend point ledger kinds for shop spend
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.point_transactions
  drop constraint if exists point_transactions_kind_check;

alter table public.point_transactions
  add constraint point_transactions_kind_check
  check (kind in (
    'earn_review',
    'earn_case_share',
    'earn_comment',
    'earn_best_comment',
    'purchase',
    'unlock_spend',
    'unlock_revenue',
    'shop_spend',
    'boost_spend',
    'subscription_grant',
    'promo_grant',
    'refund',
    'adjust'
  ));

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) point_shop_items — product master
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.point_shop_items (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique,
  title text not null,
  description text not null default '',
  category text not null
    check (category in ('booster', 'knowledge', 'ai_report', 'template', 'bundle')),
  price_points int not null check (price_points > 0),
  duration_hours int not null default 0 check (duration_hours >= 0),
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  sort_order int not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_point_shop_items_active
  on public.point_shop_items (category, is_active, sort_order)
  where is_active = true;

comment on table public.point_shop_items is
  'SORI 포인트 상점 마스터 — 출금불가 포인트로만 구매.';

alter table public.point_shop_items enable row level security;
drop policy if exists "mvp_point_shop_items_all" on public.point_shop_items;
create policy "mvp_point_shop_items_all"
  on public.point_shop_items for all using (true) with check (true);

-- Seed P0 boosters (gap design: free earn ~800 → 1d 900P ≈ 112%)
insert into public.point_shop_items (
  sku, title, description, category, price_points, duration_hours, sort_order, metadata
) values
  (
    'boost_local_2h',
    '우리 지역 노출 부스터 · 2시간',
    'Home 「우리 지역」탭 최상단 고정 노출 (AD)',
    'booster',
    300,
    2,
    10,
    '{"placement":"home_local","label":"AD"}'::jsonb
  ),
  (
    'boost_local_1d',
    '우리 지역 노출 부스터 · 1일',
    'Home 「우리 지역」탭 최상단 고정 노출 24시간',
    'booster',
    900,
    24,
    20,
    '{"placement":"home_local","label":"AD","badge":"인기"}'::jsonb
  ),
  (
    'boost_local_7d',
    '우리 지역 노출 부스터 · 7일',
    'Home 「우리 지역」탭 최상단 고정 노출 7일 (일당 할인)',
    'booster',
    4500,
    168,
    30,
    '{"placement":"home_local","label":"AD"}'::jsonb
  )
on conflict (sku) do update set
  title = excluded.title,
  description = excluded.description,
  price_points = excluded.price_points,
  duration_hours = excluded.duration_hours,
  sort_order = excluded.sort_order,
  metadata = excluded.metadata,
  is_active = true,
  updated_at = now();

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) boost_placements — active pin runtime
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.boost_placements (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  item_id uuid references public.point_shop_items (id) on delete set null,
  item_sku text not null default '',
  -- Home clinical cases are charts; community posts optional
  target_type text not null
    check (target_type in ('chart', 'community_post')),
  target_id uuid not null,
  post_id uuid references public.community_posts (id) on delete cascade,
  chart_id uuid,
  region_code text not null default '',
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  status text not null default 'active'
    check (status in ('active', 'expired', 'cancelled')),
  points_spent int not null default 0 check (points_spent >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint boost_placements_target_check check (
    (target_type = 'chart' and chart_id is not null)
    or (target_type = 'community_post' and post_id is not null)
  )
);

create index if not exists idx_boost_placements_active_ends
  on public.boost_placements (status, ends_at desc)
  where status = 'active';

create index if not exists idx_boost_placements_chart_active
  on public.boost_placements (chart_id, status, ends_at desc)
  where chart_id is not null and status = 'active';

create index if not exists idx_boost_placements_post_active
  on public.boost_placements (post_id, status, ends_at desc)
  where post_id is not null and status = 'active';

create index if not exists idx_boost_placements_shop
  on public.boost_placements (shop_id, created_at desc);

comment on table public.boost_placements is
  '로컬 노출 부스터 런타임 — Home 우리 지역 핀 정렬 SSOT.';

alter table public.boost_placements enable row level security;
drop policy if exists "mvp_boost_placements_all" on public.boost_placements;
create policy "mvp_boost_placements_all"
  on public.boost_placements for all using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) Helpers + purchase RPC (points ONLY — never settlement)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.expire_stale_boost_placements()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  update public.boost_placements
  set status = 'expired', updated_at = now()
  where status = 'active' and ends_at <= now();
  get diagnostics v_n = row_count;
  return coalesce(v_n, 0);
end;
$$;

create or replace function public.list_active_boost_placements(
  p_limit int default 40
)
returns setof public.boost_placements
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.expire_stale_boost_placements();
  return query
  select *
  from public.boost_placements
  where status = 'active'
    and ends_at > now()
  order by ends_at desc
  limit greatest(coalesce(p_limit, 40), 1);
end;
$$;

create or replace function public.purchase_point_shop_item(
  p_shop_id uuid,
  p_sku text,
  p_target_type text default 'chart',
  p_target_id uuid default null,
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
  v_debit jsonb;
  v_placement public.boost_placements%rowtype;
  v_sku text := lower(trim(coalesce(p_sku, '')));
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_need int;
  v_have int;
  v_starts timestamptz := now();
  v_ends timestamptz;
  v_chart_id uuid;
  v_post_id uuid;
  v_settlement_before int;
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;
  if v_sku = '' then
    raise exception 'sku required';
  end if;
  if v_type not in ('chart', 'community_post') then
    raise exception 'invalid target_type %', v_type;
  end if;
  if p_target_id is null then
    raise exception 'target_id required';
  end if;

  select * into v_item
  from public.point_shop_items
  where sku = v_sku and is_active = true;
  if not found then
    raise exception 'shop item not found: %', v_sku;
  end if;

  if v_item.category = 'booster' and v_item.duration_hours <= 0 then
    raise exception 'booster requires duration_hours';
  end if;

  -- Snapshot settlement BEFORE any write — must remain unchanged
  v_wallet := public.ensure_shop_wallet(p_shop_id);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;
  v_settlement_before := v_wallet.settlement_balance;
  v_have := v_wallet.point_free_balance + v_wallet.point_paid_balance;
  v_need := v_item.price_points;

  if v_have < v_need then
    raise exception 'insufficient points: have %, need %', v_have, v_need
      using errcode = 'P0001',
            hint = format('gap=%s', v_need - v_have);
  end if;

  -- STRICT: debit points only (free-first inside debit_points)
  v_debit := public.debit_points(
    p_shop_id,
    v_need,
    case when v_item.category = 'booster' then 'boost_spend' else 'shop_spend' end,
    'point_shop_item',
    v_item.id,
    null,
    coalesce(v_item.title, v_sku)
  );

  -- Guard: settlement must not move
  select * into v_wallet from public.wallets where shop_id = p_shop_id;
  if v_wallet.settlement_balance is distinct from v_settlement_before then
    raise exception 'settlement_balance must not change on point shop purchase';
  end if;

  if v_item.category = 'booster' then
    v_ends := v_starts + make_interval(hours => v_item.duration_hours);

    if v_type = 'chart' then
      v_chart_id := p_target_id;
      v_post_id := null;
    else
      v_post_id := p_target_id;
      v_chart_id := null;
    end if;

    -- Expire overlapping active boosts on same target (re-buy extends cleanly)
    update public.boost_placements
    set status = 'cancelled', updated_at = now()
    where status = 'active'
      and target_type = v_type
      and target_id = p_target_id;

    insert into public.boost_placements (
      shop_id, item_id, item_sku, target_type, target_id,
      post_id, chart_id, region_code,
      starts_at, ends_at, status, points_spent
    ) values (
      p_shop_id, v_item.id, v_item.sku, v_type, p_target_id,
      v_post_id, v_chart_id, coalesce(p_region_code, ''),
      v_starts, v_ends, 'active', v_need
    )
    returning * into v_placement;
  end if;

  return jsonb_build_object(
    'ok', true,
    'sku', v_item.sku,
    'category', v_item.category,
    'points_spent', v_need,
    'debit', v_debit,
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'settlement_balance', v_wallet.settlement_balance,
    'placement', case
      when v_placement.id is null then null
      else to_jsonb(v_placement)
    end
  );
end;
$$;

comment on function public.purchase_point_shop_item(uuid, text, text, uuid, text) is
  '포인트 상점 구매 — point_*만 차감(무료 우선). settlement_balance 절대 미참조 차감.';

grant execute on function public.expire_stale_boost_placements()
  to anon, authenticated, service_role;
grant execute on function public.list_active_boost_placements(int)
  to anon, authenticated, service_role;
grant execute on function public.purchase_point_shop_item(uuid, text, text, uuid, text)
  to anon, authenticated, service_role;
