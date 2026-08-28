-- 081: VIP 스페셜 후원 — Premium Overlay (기존 부스트 취소 없이 스택)
-- SKUs: boost_special_gold_24h (39E), boost_special_platinum_7d (149E)

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) point_shop_items — supporter_gift category
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.point_shop_items
  drop constraint if exists point_shop_items_category_check;

alter table public.point_shop_items
  add constraint point_shop_items_category_check
  check (category in (
    'booster', 'knowledge', 'ai_report', 'template', 'bundle', 'ai_tool',
    'subscription', 'supporter_gift'
  ));

insert into public.point_shop_items (
  sku, title, description, category, price_points, duration_hours, sort_order, metadata, is_active
) values
  (
    'boost_special_gold_24h',
    '스페셜 후원 · 골드 24시간',
    '기존 부스트 위에 골드 오로라·피드 가중치 · 3,900원',
    'supporter_gift', 39, 24, 41,
    '{"tier":"gold","overlay":true,"placement":"premium_overlay","currency":"echo","badge":"골드"}'::jsonb,
    true
  ),
  (
    'boost_special_platinum_7d',
    '스페셜 후원 · 플래티넘 7일',
    '마이페이지 히어로 슬롯 + 플래티넘 오로라 · 14,900원',
    'supporter_gift', 149, 168, 42,
    '{"tier":"platinum","overlay":true,"placement":"premium_overlay","currency":"echo","badge":"플래티넘"}'::jsonb,
    true
  )
on conflict (sku) do update set
  title = excluded.title,
  description = excluded.description,
  category = excluded.category,
  price_points = excluded.price_points,
  duration_hours = excluded.duration_hours,
  sort_order = excluded.sort_order,
  metadata = excluded.metadata,
  is_active = true,
  updated_at = now();

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) boost_premium_overlays ledger
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.boost_premium_overlays (
  id uuid primary key default gen_random_uuid(),
  beneficiary_shop_id uuid not null references public.shops (id) on delete cascade,
  target_type text not null check (target_type in ('chart', 'community_post')),
  target_id uuid not null,
  chart_id uuid references public.customer_charts (id) on delete cascade,
  post_id uuid references public.community_posts (id) on delete cascade,
  tier text not null check (tier in ('gold', 'platinum')),
  sku text not null,
  fan_customer_id uuid not null references public.customers (id) on delete cascade,
  fan_wallet_id uuid references public.wallets (id) on delete set null,
  fan_display_name text not null default '후원자',
  echo_spent int not null default 0 check (echo_spent >= 0),
  fan_gift_id uuid references public.fan_gifts (id) on delete set null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  status text not null default 'active'
    check (status in ('active', 'expired', 'cancelled')),
  created_at timestamptz not null default now()
);

create index if not exists idx_boost_premium_overlays_target
  on public.boost_premium_overlays (target_type, target_id, status, ends_at desc);

create index if not exists idx_boost_premium_overlays_shop
  on public.boost_premium_overlays (beneficiary_shop_id, tier, status, ends_at desc);

comment on table public.boost_premium_overlays is
  'VIP 스페셜 후원 오버레이 — 기존 boost_placements 를 취소하지 않음.';

alter table public.boost_premium_overlays enable row level security;
drop policy if exists "mvp_boost_premium_overlays_all" on public.boost_premium_overlays;
create policy "mvp_boost_premium_overlays_all"
  on public.boost_premium_overlays for all using (true) with check (true);

-- fan_gifts gift_kind 확장
alter table public.fan_gifts
  drop constraint if exists fan_gifts_gift_kind_check;

alter table public.fan_gifts
  add constraint fan_gifts_gift_kind_check
  check (gift_kind in (
    'boost', 'boost_with_ai_fill', 'ai_tool',
    'boost_special_gold', 'boost_special_platinum'
  ));

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Helpers
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.expire_stale_premium_overlays()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  update public.boost_premium_overlays
  set status = 'expired'
  where status = 'active' and ends_at <= now();
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

create or replace function public.sku_premium_tier(p_sku text)
returns text
language sql
immutable
as $$
  select case lower(trim(coalesce(p_sku, '')))
    when 'boost_special_gold_24h' then 'gold'
    when 'boost_special_platinum_7d' then 'platinum'
    else coalesce(
      (select lower(trim(metadata->>'tier'))
       from public.point_shop_items
       where sku = lower(trim(coalesce(p_sku, '')))
       limit 1),
      ''
    )
  end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) purchase_special_supporter_gift
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.purchase_special_supporter_gift(
  p_fan_customer_id uuid,
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
  v_overlay public.boost_premium_overlays%rowtype;
  v_gift public.fan_gifts%rowtype;
  v_sku text := lower(trim(coalesce(p_sku, '')));
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_tier text;
  v_gift_kind text;
  v_need int;
  v_starts timestamptz := now();
  v_ends timestamptz;
  v_chart_id uuid;
  v_post_id uuid;
  v_name text;
  v_tx_id uuid;
begin
  if p_fan_customer_id is null then
    raise exception 'fan_customer_id required';
  end if;
  if v_sku = '' or p_target_id is null then
    raise exception 'sku and target_id required';
  end if;
  if v_type not in ('chart', 'community_post') then
    raise exception 'invalid target_type';
  end if;

  select * into v_item
  from public.point_shop_items
  where sku = v_sku and is_active = true and category = 'supporter_gift';
  if not found then
    raise exception 'supporter_gift sku not found: %', v_sku;
  end if;

  v_tier := public.sku_premium_tier(v_sku);
  if v_tier not in ('gold', 'platinum') then
    raise exception 'invalid premium tier for sku: %', v_sku;
  end if;
  v_gift_kind := case v_tier
    when 'gold' then 'boost_special_gold'
    else 'boost_special_platinum'
  end;

  if v_type = 'chart' then
    select shop_id into v_target_shop from public.customer_charts where id = p_target_id;
    v_chart_id := p_target_id;
  else
    select shop_id, source_chart_id into v_target_shop, v_chart_id
    from public.community_posts where id = p_target_id;
    v_post_id := p_target_id;
  end if;

  if v_target_shop is null then
    raise exception 'target shop not found';
  end if;

  v_shop_wallet := public.ensure_shop_wallet(v_target_shop);
  select * into v_shop_wallet from public.wallets where id = v_shop_wallet.id for update;
  v_settlement_before := v_shop_wallet.settlement_balance;

  v_wallet := public.ensure_customer_wallet(p_fan_customer_id);
  v_need := v_item.price_points;

  v_debit := public.debit_echo_wallet(
    v_wallet.id, v_need, 'fan_boost_spend',
    'point_shop_item', v_item.id,
    'Special supporter ' || v_item.title,
    v_target_shop
  );

  v_tx_id := nullif(trim(coalesce(v_debit->>'tx_id', '')), '')::uuid;

  select settlement_balance into v_settlement_after
  from public.wallets where id = v_shop_wallet.id;
  if v_settlement_after is distinct from v_settlement_before then
    raise exception 'Special supporter gift must not change shop settlement_balance';
  end if;

  select * into v_wallet from public.wallets where id = v_wallet.id;
  if coalesce(v_wallet.settlement_balance, 0) <> 0 then
    raise exception 'customer wallet must not hold settlement';
  end if;

  v_ends := v_starts + make_interval(hours => v_item.duration_hours);

  -- Overlay stacks — do NOT cancel boost_placements.
  -- Same-tier active overlay on same target is replaced.
  update public.boost_premium_overlays
  set status = 'cancelled'
  where status = 'active'
    and target_type = v_type
    and target_id = p_target_id
    and tier = v_tier;

  select coalesce(nullif(trim(p_fan_display_name), ''), c.name, '후원자')
  into v_name
  from public.customers c where c.id = p_fan_customer_id;

  insert into public.boost_premium_overlays (
    beneficiary_shop_id, target_type, target_id, chart_id, post_id,
    tier, sku, fan_customer_id, fan_wallet_id, fan_display_name,
    echo_spent, starts_at, ends_at, status
  ) values (
    v_target_shop, v_type, p_target_id, v_chart_id, v_post_id,
    v_tier, v_item.sku, p_fan_customer_id, v_wallet.id, coalesce(v_name, '후원자'),
    v_need, v_starts, v_ends, 'active'
  )
  returning * into v_overlay;

  insert into public.fan_gifts (
    beneficiary_shop_id, target_type, target_id,
    fan_customer_id, fan_wallet_id, fan_display_name,
    gift_kind, sku, echo_spent,
    point_tx_id, status
  ) values (
    v_target_shop, v_type, p_target_id,
    p_fan_customer_id, v_wallet.id, coalesce(v_name, '후원자'),
    v_gift_kind, v_item.sku, v_need,
    v_tx_id, 'completed'
  )
  returning * into v_gift;

  update public.boost_premium_overlays
  set fan_gift_id = v_gift.id
  where id = v_overlay.id;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_target_shop,
    'special_supporter',
    '스페셜 후원 알림',
    format(
      '%s님이 %s 스페셜 후원을 보냈습니다',
      coalesce(v_name, '○○'),
      case v_tier when 'platinum' then '플래티넘' else '골드' end
    ),
    jsonb_build_object(
      'overlay_id', v_overlay.id,
      'fan_gift_id', v_gift.id,
      'customer_id', p_fan_customer_id,
      'sku', v_item.sku,
      'tier', v_tier,
      'chart_id', v_chart_id,
      'supporter_name', coalesce(v_name, '후원자'),
      'overlay_stacks', true
    )
  );

  return jsonb_build_object(
    'ok', true,
    'sku', v_item.sku,
    'tier', v_tier,
    'points_spent', v_need,
    'source', 'special_supporter',
    'target_shop_id', v_target_shop,
    'settlement_balance', v_settlement_after,
    'settlement_unchanged', true,
    'debit', v_debit,
    'overlay', to_jsonb(v_overlay),
    'fan_gift', to_jsonb(v_gift),
    'notification', true
  );
end;
$$;

comment on function public.purchase_special_supporter_gift(uuid, text, text, uuid, text, text) is
  'VIP 스페셜 후원 — 기존 부스트 유지, premium overlay 스택.';

grant execute on function public.purchase_special_supporter_gift(uuid, text, text, uuid, text, text)
  to anon, authenticated, service_role;

-- PostgREST alias (Flutter p_customer_id)
create or replace function public.purchase_special_gift(
  p_customer_id uuid,
  p_sku text,
  p_target_type text default 'chart',
  p_target_id uuid default null,
  p_fan_display_name text default '',
  p_region_code text default ''
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.purchase_special_supporter_gift(
    p_customer_id, p_sku, p_target_type, p_target_id, p_fan_display_name, p_region_code
  );
$$;

comment on function public.purchase_special_gift(uuid, text, text, uuid, text, text) is
  'Alias for purchase_special_supporter_gift (PostgREST p_customer_id).';

grant execute on function public.purchase_special_gift(uuid, text, text, uuid, text, text)
  to anon, authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) list_active_premium_overlays
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_active_premium_overlays(p_limit int default 80)
returns table (
  id uuid,
  beneficiary_shop_id uuid,
  target_type text,
  target_id uuid,
  chart_id uuid,
  tier text,
  sku text,
  fan_customer_id uuid,
  fan_display_name text,
  echo_spent int,
  starts_at timestamptz,
  ends_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 80), 200));
begin
  perform public.expire_stale_premium_overlays();

  return query
  select
    o.id,
    o.beneficiary_shop_id,
    o.target_type,
    o.target_id,
    o.chart_id,
    o.tier,
    o.sku,
    o.fan_customer_id,
    o.fan_display_name,
    o.echo_spent,
    o.starts_at,
    o.ends_at
  from public.boost_premium_overlays o
  where o.status = 'active'
    and o.ends_at > now()
  order by o.ends_at desc
  limit v_limit;
end;
$$;

grant execute on function public.list_active_premium_overlays(int)
  to anon, authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- 6) Feed scoring — overlay tier bonus
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_boost_candidates_scored(
  p_segment text default 'case',
  p_limit int default 200
)
returns table (
  placement_id uuid,
  target_type text,
  target_id uuid,
  source text,
  points_spent int,
  starts_at timestamptz,
  ends_at timestamptz,
  fandom_echo int,
  paid_ratio numeric,
  recency numeric,
  fan_bonus numeric,
  score numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_seg text := lower(trim(coalesce(p_segment, 'case')));
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
  v_tau double precision := 12.0;
begin
  perform public.expire_stale_boost_placements();
  perform public.expire_stale_premium_overlays();

  return query
  with active as (
    select bp.*
    from public.boost_placements bp
    where bp.status = 'active'
      and bp.ends_at > now()
      and public.boost_feed_segment(bp.target_type, bp.target_id) = v_seg
  ),
  fandom as (
    select
      bp.target_type,
      bp.target_id,
      sum(bp.points_spent)::int as echo_sum
    from public.boost_placements bp
    where bp.source = 'fan_boost'
    group by bp.target_type, bp.target_id
  ),
  overlay as (
    select
      o.target_type,
      o.target_id,
      max(case o.tier when 'platinum' then 2 when 'gold' then 1 else 0 end)::int as tier_rank,
      max(case o.tier when 'platinum' then 0.22 when 'gold' then 0.12 else 0 end)::numeric
        as tier_bonus
    from public.boost_premium_overlays o
    where o.status = 'active' and o.ends_at > now()
    group by o.target_type, o.target_id
  )
  select
    a.id,
    a.target_type,
    a.target_id,
    a.source,
    a.points_spent,
    a.starts_at,
    a.ends_at,
    coalesce(f.echo_sum, 0)::int as fandom_echo,
    (case when a.source = 'fan_boost' then 0.85 else 0.55 end)::numeric
      as paid_ratio,
    (exp(
      - greatest(0, extract(epoch from (now() - a.starts_at)) / 3600.0) / v_tau
    ))::numeric as recency,
    (case when a.source = 'fan_boost' then 1.0 else 0.45 end)::numeric
      as fan_bonus,
    (
      0.40 * least(
        1.0,
        ln(1 + coalesce(f.echo_sum, 0)::double precision) / ln(1 + 5000)
      )
      + 0.25 * (case when a.source = 'fan_boost' then 0.85 else 0.55 end)
      + 0.20 * exp(
        - greatest(0, extract(epoch from (now() - a.starts_at)) / 3600.0) / v_tau
      )
      + 0.15 * (case when a.source = 'fan_boost' then 1.0 else 0.45 end)
      + coalesce(ov.tier_bonus, 0)
    )::numeric as score
  from active a
  left join fandom f
    on f.target_type = a.target_type
   and f.target_id = a.target_id
  left join overlay ov
    on ov.target_type = a.target_type
   and ov.target_id = a.target_id
  order by score desc, a.starts_at desc
  limit v_limit;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 7) Shop supporters — include special gifts + platinum hero
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_shop_supporters(
  p_shop_id uuid,
  p_sort text default 'echo_desc',
  p_limit int default 50
)
returns table (
  supporter_customer_id uuid,
  display_name text,
  avatar_url text,
  echo_spent int,
  boost_count int,
  last_boost_at timestamptz,
  supporter_tier text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sort text := lower(trim(coalesce(p_sort, 'echo_desc')));
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if p_shop_id is null then raise exception 'shop_id required'; end if;

  return query
  with gifts as (
    select
      fg.fan_customer_id as cid,
      coalesce(nullif(trim(fg.fan_display_name), ''), '후원자') as fname,
      sum(fg.echo_spent)::int as spent,
      count(*)::int as cnt,
      max(fg.created_at) as last_at,
      max(case fg.gift_kind
        when 'boost_special_platinum' then 3
        when 'boost_special_gold' then 2
        else 1
      end)::int as gift_rank
    from public.fan_gifts fg
    where fg.beneficiary_shop_id = p_shop_id
      and fg.status = 'completed'
      and fg.gift_kind in (
        'boost', 'boost_with_ai_fill',
        'boost_special_gold', 'boost_special_platinum'
      )
    group by fg.fan_customer_id, coalesce(nullif(trim(fg.fan_display_name), ''), '후원자')
  ),
  ranked as (
    select
      a.*,
      row_number() over (order by a.spent desc, a.fname asc)::int as rnk
    from gifts a
  )
  select
    r.cid,
    r.fname,
    coalesce(nullif(trim(p.avatar_url), ''), ''),
    r.spent,
    r.cnt,
    r.last_at,
    case
      when r.gift_rank >= 3 then 'platinum'
      when r.gift_rank >= 2 then 'gold'
      when r.rnk = 1 and r.spent >= 50 then 'top'
      when r.rnk <= 3 and r.spent >= 200 then 'premium'
      else 'supporter'
    end
  from ranked r
  left join public.customers c on c.id = r.cid
  left join public.profiles p on p.id = c.user_id
  order by
    case when v_sort = 'recent' then extract(epoch from r.last_at) end desc nulls last,
    case when v_sort = 'count_desc' then r.cnt end desc nulls last,
    case when v_sort = 'echo_desc' or v_sort not in ('recent', 'count_desc') then r.spent end desc nulls last,
    r.fname asc
  limit v_limit;
end;
$$;

create or replace function public.get_shop_supporter_header(p_shop_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_followers int := 0;
  v_supporters int := 0;
  v_facepile jsonb;
  v_top jsonb;
  v_special_hero jsonb;
begin
  if p_shop_id is null then
    return jsonb_build_object('follower_count', 0, 'supporter_count', 0, 'facepile', '[]'::jsonb);
  end if;

  perform public.expire_stale_premium_overlays();

  select count(*)::int into v_followers
  from public.shop_followers sf where sf.shop_id = p_shop_id;

  select count(distinct fg.fan_customer_id)::int into v_supporters
  from public.fan_gifts fg
  where fg.beneficiary_shop_id = p_shop_id
    and fg.status = 'completed'
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    );

  select coalesce(jsonb_agg(jsonb_build_object(
    'paid_by_customer_id', s.supporter_customer_id,
    'fan_display_name', s.display_name,
    'avatar_url', s.avatar_url,
    'echo_spent', s.echo_spent,
    'boost_count', s.boost_count,
    'supporter_tier', s.supporter_tier
  ) order by s.echo_spent desc), '[]'::jsonb)
  into v_facepile
  from public.list_shop_supporters(p_shop_id, 'echo_desc', 3) s;

  select to_jsonb(s) into v_top
  from public.list_shop_supporters(p_shop_id, 'echo_desc', 1) s
  limit 1;

  select jsonb_build_object(
    'paid_by_customer_id', o.fan_customer_id,
    'fan_display_name', o.fan_display_name,
    'avatar_url', coalesce(nullif(trim(p.avatar_url), ''), ''),
    'echo_spent', o.echo_spent,
    'supporter_tier', 'platinum',
    'tier', 'platinum',
    'ends_at', o.ends_at
  )
  into v_special_hero
  from public.boost_premium_overlays o
  left join public.customers c on c.id = o.fan_customer_id
  left join public.profiles p on p.id = c.user_id
  where o.beneficiary_shop_id = p_shop_id
    and o.tier = 'platinum'
    and o.status = 'active'
    and o.ends_at > now()
  order by o.ends_at desc
  limit 1;

  return jsonb_build_object(
    'follower_count', v_followers,
    'supporter_count', v_supporters,
    'facepile', v_facepile,
    'top_supporter', coalesce(v_top, 'null'::jsonb),
    'special_hero', coalesce(v_special_hero, 'null'::jsonb)
  );
end;
$$;
