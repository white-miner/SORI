-- 084: E5-lite — 후원 기여 리포트 (후원자·원장 양쪽)

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) list_boost_gift_impact_reports — 고객 「내 후원 기여」
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_boost_gift_impact_reports(
  p_fan_customer_id uuid,
  p_limit int default 50
)
returns table (
  fan_gift_id uuid,
  target_type text,
  chart_id uuid,
  shop_id uuid,
  shop_name text,
  sku text,
  echo_spent int,
  gift_kind text,
  created_at timestamptz,
  case_title text,
  has_thank_you boolean,
  thank_you_post_id uuid,
  bookmarks_since_gift int,
  estimated_reach int,
  boost_still_active boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if p_fan_customer_id is null then
    raise exception 'fan_customer_id required';
  end if;

  return query
  with base as (
    select
      fg.id as gift_id,
      fg.target_type,
      case
        when fg.target_type = 'chart' then fg.target_id
        else cp.source_chart_id
      end as resolved_chart_id,
      fg.beneficiary_shop_id,
      coalesce(nullif(trim(s.name), ''), 'SORI') as shop_nm,
      fg.sku,
      fg.echo_spent,
      fg.gift_kind,
      fg.created_at as gift_created_at,
      coalesce(
        nullif(trim(cc.care_name), ''),
        nullif(trim(cc.treatment_summary), ''),
        '케이스'
      ) as case_nm,
      fg.boost_placement_id,
      fg.id as fg_id
    from public.fan_gifts fg
    join public.shops s on s.id = fg.beneficiary_shop_id
    left join public.customer_charts cc
      on fg.target_type = 'chart' and cc.id = fg.target_id
    left join public.community_posts cp
      on fg.target_type = 'community_post' and cp.id = fg.target_id
    where fg.fan_customer_id = p_fan_customer_id
      and fg.status = 'completed'
      and fg.gift_kind in (
        'boost', 'boost_with_ai_fill',
        'boost_special_gold', 'boost_special_platinum'
      )
    order by fg.created_at desc
    limit v_limit
  )
  select
    b.gift_id,
    b.target_type,
    b.resolved_chart_id,
    b.beneficiary_shop_id,
    b.shop_nm,
    b.sku,
    b.echo_spent,
    b.gift_kind,
    b.gift_created_at,
    b.case_nm,
    exists (
      select 1 from public.community_posts p
      where p.reply_to_fan_gift_id = b.gift_id
    ),
    (
      select p.id from public.community_posts p
      where p.reply_to_fan_gift_id = b.gift_id
      limit 1
    ),
    coalesce((
      select count(*)::int
      from public.case_bookmarks cb
      where b.resolved_chart_id is not null
        and cb.chart_id = b.resolved_chart_id
        and cb.created_at >= b.gift_created_at
    ), 0),
    (
      coalesce((
        select round(
          greatest(
            0,
            extract(epoch from (
              least(coalesce(bp.ends_at, now()), now()) - bp.starts_at
            )) / 3600.0
          ) * 15
        )::int
        from public.boost_placements bp
        where bp.id = b.boost_placement_id
      ), 0)
      + coalesce((
        select round(
          greatest(
            0,
            extract(epoch from (
              least(coalesce(ov.ends_at, now()), now()) - ov.starts_at
            )) / 3600.0
          ) * 25
        )::int
        from public.boost_premium_overlays ov
        where ov.fan_gift_id = b.fg_id
        order by ov.created_at desc
        limit 1
      ), 0)
    ),
    (
      exists (
        select 1 from public.boost_placements bp
        where bp.id = b.boost_placement_id
          and bp.status = 'active'
          and bp.ends_at > now()
      )
      or exists (
        select 1 from public.boost_premium_overlays ov
        where ov.fan_gift_id = b.fg_id
          and ov.status = 'active'
          and ov.ends_at > now()
      )
    )
  from base b;
end;
$$;

-- PostgREST alias
create or replace function public.list_boost_gift_impact_reports_for_customer(
  p_customer_id uuid,
  p_limit int default 50
)
returns table (
  fan_gift_id uuid,
  target_type text,
  chart_id uuid,
  shop_id uuid,
  shop_name text,
  sku text,
  echo_spent int,
  gift_kind text,
  created_at timestamptz,
  case_title text,
  has_thank_you boolean,
  thank_you_post_id uuid,
  bookmarks_since_gift int,
  estimated_reach int,
  boost_still_active boolean
)
language sql
security definer
set search_path = public
as $$
  select * from public.list_boost_gift_impact_reports(p_customer_id, p_limit);
$$;

grant execute on function public.list_boost_gift_impact_reports(uuid, int)
  to authenticated;
grant execute on function public.list_boost_gift_impact_reports_for_customer(uuid, int)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) get_shop_sponsorship_impact — 원장 30일 후원 기여 요약
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.get_shop_sponsorship_impact(
  p_shop_id uuid,
  p_period_days int default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days int := greatest(1, least(coalesce(p_period_days, 30), 90));
  v_since timestamptz := now() - make_interval(days => v_days);
  v_gift_count int := 0;
  v_echo_total int := 0;
  v_bookmarks int := 0;
  v_thank_yous int := 0;
  v_pending int := 0;
  v_reach int := 0;
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  select
    count(*)::int,
    coalesce(sum(fg.echo_spent), 0)::int,
    count(*) filter (
      where exists (
        select 1 from public.community_posts p
        where p.reply_to_fan_gift_id = fg.id
      )
    )::int,
    count(*) filter (
      where not exists (
        select 1 from public.community_posts p
        where p.reply_to_fan_gift_id = fg.id
      )
    )::int
  into v_gift_count, v_echo_total, v_thank_yous, v_pending
  from public.fan_gifts fg
  where fg.beneficiary_shop_id = p_shop_id
    and fg.status = 'completed'
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    )
    and fg.created_at >= v_since;

  select coalesce(count(*)::int, 0)
  into v_bookmarks
  from public.case_bookmarks cb
  join public.customer_charts cc on cc.id = cb.chart_id
  where cc.shop_id = p_shop_id
    and cb.created_at >= v_since
    and exists (
      select 1 from public.fan_gifts fg
      where fg.beneficiary_shop_id = p_shop_id
        and fg.status = 'completed'
        and fg.created_at >= v_since
        and (
          (fg.target_type = 'chart' and fg.target_id = cb.chart_id)
          or exists (
            select 1 from public.community_posts cp
            where cp.id = fg.target_id
              and cp.source_chart_id = cb.chart_id
          )
        )
    );

  select coalesce(sum(
    coalesce((
      select round(
        greatest(
          0,
          extract(epoch from (
            least(coalesce(bp.ends_at, now()), now()) - bp.starts_at
          )) / 3600.0
        ) * 15
      )::int
      from public.boost_placements bp
      where bp.id = fg.boost_placement_id
    ), 0)
    + coalesce((
      select round(
        greatest(
          0,
          extract(epoch from (
            least(coalesce(ov.ends_at, now()), now()) - ov.starts_at
          )) / 3600.0
        ) * 25
      )::int
      from public.boost_premium_overlays ov
      where ov.fan_gift_id = fg.id
      order by ov.created_at desc
      limit 1
    ), 0)
  ), 0)::int
  into v_reach
  from public.fan_gifts fg
  where fg.beneficiary_shop_id = p_shop_id
    and fg.status = 'completed'
    and fg.created_at >= v_since
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    );

  return jsonb_build_object(
    'ok', true,
    'period_days', v_days,
    'gift_count', v_gift_count,
    'echo_total', v_echo_total,
    'bookmarks_received', v_bookmarks,
    'thank_yous_sent', v_thank_yous,
    'pending_thanks', v_pending,
    'estimated_total_reach', v_reach
  );
end;
$$;

grant execute on function public.get_shop_sponsorship_impact(uuid, int)
  to authenticated;
