-- 080_supporter_copy_and_shop_supporters.sql
-- UI-facing copy: 후원자/팔로워 (no 「팬」 in notifications).
-- Shop-level supporter aggregation for My Page Facepile.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) purchase_fan_gift — supporter notification copy
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.purchase_fan_gift(
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
  v_placement public.boost_placements%rowtype;
  v_gift public.fan_gifts%rowtype;
  v_sku text := lower(trim(coalesce(p_sku, '')));
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_need int;
  v_starts timestamptz := now();
  v_ends timestamptz;
  v_chart_id uuid;
  v_post_id uuid;
  v_name text;
  v_tx_id uuid;
  v_ai_fill jsonb;
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
  where sku = v_sku and is_active = true and category = 'booster';
  if not found then
    raise exception 'booster sku not found: %', v_sku;
  end if;

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
    'Supporter boost ' || v_item.title,
    v_target_shop
  );

  v_tx_id := nullif(trim(coalesce(v_debit->>'tx_id', '')), '')::uuid;

  select settlement_balance into v_settlement_after
  from public.wallets where id = v_shop_wallet.id;
  if v_settlement_after is distinct from v_settlement_before then
    raise exception 'Supporter gift must not change shop settlement_balance';
  end if;

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

  select coalesce(nullif(trim(p_fan_display_name), ''), c.name, '후원자')
  into v_name
  from public.customers c where c.id = p_fan_customer_id;

  insert into public.boost_placements (
    shop_id, item_id, item_sku, target_type, target_id,
    post_id, chart_id, region_code,
    starts_at, ends_at, status, points_spent,
    source, paid_by_customer_id, paid_by_wallet_id, fan_display_name
  ) values (
    v_target_shop, v_item.id, v_item.sku, v_type, p_target_id,
    v_post_id, v_chart_id, coalesce(p_region_code, ''),
    v_starts, v_ends, 'active', v_need,
    'fan_boost', p_fan_customer_id, v_wallet.id, coalesce(v_name, '후원자')
  )
  returning * into v_placement;

  insert into public.fan_gifts (
    beneficiary_shop_id, target_type, target_id,
    fan_customer_id, fan_wallet_id, fan_display_name,
    gift_kind, sku, echo_spent,
    boost_placement_id, point_tx_id, status
  ) values (
    v_target_shop, v_type, p_target_id,
    p_fan_customer_id, v_wallet.id, coalesce(v_name, '후원자'),
    'boost', v_item.sku, v_need,
    v_placement.id, v_tx_id, 'completed'
  )
  returning * into v_gift;

  v_ai_fill := jsonb_build_object('ok', false, 'skipped', true);
  if v_chart_id is not null then
    v_ai_fill := public.run_fan_boost_ai_fill(
      v_target_shop,
      v_chart_id,
      p_fan_customer_id,
      coalesce(v_name, '후원자'),
      v_gift.id
    );
  end if;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_target_shop,
    'fan_boost',
    '후원 알림',
    case
      when coalesce(v_ai_fill->>'skipped', 'true') = 'false' then
        format('%s님이 부스터를 지원하며 케이스 스토리를 완성해 주었습니다', coalesce(v_name, '○○'))
      else
        format('%s님이 부스터를 지원했습니다', coalesce(v_name, '○○'))
    end,
    jsonb_build_object(
      'placement_id', v_placement.id,
      'fan_gift_id', v_gift.id,
      'customer_id', p_fan_customer_id,
      'sku', v_item.sku,
      'chart_id', v_chart_id,
      'supporter_name', coalesce(v_name, '후원자'),
      'fan_name', coalesce(v_name, '후원자'),
      'ai_fill', v_ai_fill
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
    'fan_gift', to_jsonb(v_gift),
    'ai_fill', v_ai_fill,
    'notification', true
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Fallback display name → 후원자
-- ═══════════════════════════════════════════════════════════════════════════

drop function if exists public.list_fan_boost_supporters(text, uuid, int);
drop function if exists public.list_fan_boost_supporters_batch(text, uuid[], int);

create or replace function public.list_fan_boost_supporters(
  p_target_type text default 'chart',
  p_target_id uuid default null,
  p_limit int default 200
)
returns table (
  target_id uuid,
  paid_by_customer_id uuid,
  paid_by_wallet_id uuid,
  fan_display_name text,
  avatar_url text,
  echo_spent int,
  boost_count int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
begin
  if p_target_id is null then raise exception 'target_id required'; end if;
  if v_type not in ('chart', 'community_post') then raise exception 'invalid target_type'; end if;

  return query
  with agg as (
    select
      bp.paid_by_wallet_id as wid,
      (array_agg(bp.paid_by_customer_id order by bp.created_at desc)
        filter (where bp.paid_by_customer_id is not null))[1] as cid,
      coalesce(nullif(trim((
        array_agg(bp.fan_display_name order by bp.created_at desc)
          filter (where nullif(trim(bp.fan_display_name), '') is not null)
      )[1]), ''), '후원자') as fname,
      sum(bp.points_spent)::int as spent,
      count(*)::int as cnt
    from public.boost_placements bp
    where bp.source = 'fan_boost'
      and bp.target_type = v_type
      and bp.target_id = p_target_id
      and bp.paid_by_wallet_id is not null
    group by bp.paid_by_wallet_id
  )
  select
    p_target_id, a.cid, a.wid, a.fname,
    coalesce(nullif(trim(p.avatar_url), ''), ''),
    a.spent, a.cnt
  from agg a
  left join public.customers c on c.id = a.cid
  left join public.profiles p on p.id = c.user_id
  order by a.spent desc, a.fname asc
  limit v_limit;
end;
$$;

create or replace function public.list_fan_boost_supporters_batch(
  p_target_type text default 'chart',
  p_target_ids uuid[] default '{}',
  p_limit_per_target int default 50
)
returns table (
  target_id uuid,
  paid_by_customer_id uuid,
  paid_by_wallet_id uuid,
  fan_display_name text,
  avatar_url text,
  echo_spent int,
  boost_count int,
  rank_in_target int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_per int := greatest(1, least(coalesce(p_limit_per_target, 50), 200));
begin
  if p_target_ids is null or cardinality(p_target_ids) = 0 then return; end if;
  if v_type not in ('chart', 'community_post') then raise exception 'invalid target_type'; end if;

  return query
  with agg as (
    select
      bp.target_id as tid,
      bp.paid_by_wallet_id as wid,
      (array_agg(bp.paid_by_customer_id order by bp.created_at desc)
        filter (where bp.paid_by_customer_id is not null))[1] as cid,
      coalesce(nullif(trim((
        array_agg(bp.fan_display_name order by bp.created_at desc)
          filter (where nullif(trim(bp.fan_display_name), '') is not null)
      )[1]), ''), '후원자') as fname,
      sum(bp.points_spent)::int as spent,
      count(*)::int as cnt
    from public.boost_placements bp
    where bp.source = 'fan_boost'
      and bp.target_type = v_type
      and bp.target_id = any (p_target_ids)
      and bp.paid_by_wallet_id is not null
    group by bp.target_id, bp.paid_by_wallet_id
  ),
  ranked as (
    select
      a.tid, a.cid, a.wid, a.fname,
      coalesce(nullif(trim(p.avatar_url), ''), '') as av,
      a.spent, a.cnt,
      row_number() over (partition by a.tid order by a.spent desc, a.fname asc)::int as rnk
    from agg a
    left join public.customers c on c.id = a.cid
    left join public.profiles p on p.id = c.user_id
  )
  select r.tid, r.cid, r.wid, r.fname, r.av, r.spent, r.cnt, r.rnk
  from ranked r
  where r.rnk <= v_per
  order by r.tid, r.rnk;
end;
$$;

grant execute on function public.list_fan_boost_supporters(text, uuid, int)
  to anon, authenticated, service_role;
grant execute on function public.list_fan_boost_supporters_batch(text, uuid[], int)
  to anon, authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Shop-level supporters (My Page Facepile — Echo DESC)
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
  with agg as (
    select
      bp.paid_by_customer_id as cid,
      coalesce(nullif(trim((
        array_agg(bp.fan_display_name order by bp.created_at desc)
          filter (where nullif(trim(bp.fan_display_name), '') is not null)
      )[1]), ''), '후원자') as fname,
      sum(bp.points_spent)::int as spent,
      count(*)::int as cnt,
      max(bp.created_at) as last_at
    from public.boost_placements bp
    where bp.shop_id = p_shop_id
      and bp.source = 'fan_boost'
      and bp.paid_by_customer_id is not null
    group by bp.paid_by_customer_id
  ),
  ranked as (
    select
      a.*,
      row_number() over (order by a.spent desc, a.fname asc)::int as rnk
    from agg a
  )
  select
    r.cid,
    r.fname,
    coalesce(nullif(trim(p.avatar_url), ''), ''),
    r.spent,
    r.cnt,
    r.last_at,
    case
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
begin
  if p_shop_id is null then
    return jsonb_build_object('follower_count', 0, 'supporter_count', 0, 'facepile', '[]'::jsonb);
  end if;

  select count(*)::int into v_followers
  from public.shop_followers sf where sf.shop_id = p_shop_id;

  select count(distinct bp.paid_by_customer_id)::int into v_supporters
  from public.boost_placements bp
  where bp.shop_id = p_shop_id
    and bp.source = 'fan_boost'
    and bp.paid_by_customer_id is not null;

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

  return jsonb_build_object(
    'follower_count', v_followers,
    'supporter_count', v_supporters,
    'facepile', v_facepile,
    'top_supporter', coalesce(v_top, 'null'::jsonb)
  );
end;
$$;

grant execute on function public.list_shop_supporters(uuid, text, int)
  to anon, authenticated, service_role;
grant execute on function public.get_shop_supporter_header(uuid)
  to anon, authenticated, service_role;
