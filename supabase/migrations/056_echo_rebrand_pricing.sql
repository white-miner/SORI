-- 056: Echo rebrand pricing — 1 Echo = ₩100 peg, faucet caps, tier rewards

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Ledger kinds: expire + tier grant
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
    'tier_grant',
    'expire',
    'refund',
    'adjust'
  ));

comment on table public.point_transactions is
  'SORI Echo 원장 (구 포인트). 1 Echo = ₩100 페그. 출금 금지.';

comment on column public.wallets.point_free_balance is
  'Free Echo (활동) — 출금 불가. 1E=₩100.';
comment on column public.wallets.point_paid_balance is
  'Paid Echo (IAP) — 출금 불가. 1E=₩100.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Reseed point_shop_items (Echo anchor prices)
-- ═══════════════════════════════════════════════════════════════════════════

update public.point_shop_items
set is_active = false, updated_at = now()
where category = 'booster';

insert into public.point_shop_items (
  sku, title, description, category, price_points, duration_hours, sort_order, metadata, is_active
) values
  (
    'boost_local_2h',
    '우리 지역 노출 부스터 · 2시간',
    'Home 「우리 지역」탭 최상단 고정 (AD) · 1 Echo = ₩100',
    'booster', 29, 2, 10,
    '{"placement":"home_local","label":"AD","currency":"echo"}'::jsonb,
    true
  ),
  (
    'boost_local_1d',
    '우리 지역 노출 부스터 · 1일',
    'Home 「우리 지역」탭 최상단 고정 24시간 · 히트 SKU',
    'booster', 89, 24, 20,
    '{"placement":"home_local","label":"AD","badge":"인기","currency":"echo"}'::jsonb,
    true
  ),
  (
    'boost_local_7d',
    '우리 지역 노출 부스터 · 7일',
    'Home 「우리 지역」탭 최상단 고정 7일',
    'booster', 449, 168, 30,
    '{"placement":"home_local","label":"AD","currency":"echo"}'::jsonb,
    true
  ),
  (
    'ai_report_weekly',
    'AI 주간 경영 리포트',
    '상권·이탈 요약 주간 스냅샷',
    'ai_report', 9, 0, 40,
    '{"currency":"echo"}'::jsonb,
    true
  ),
  (
    'ai_report_monthly',
    'AI 월간 심층 리포트',
    '월간 심층 분석 + 액션 3',
    'ai_report', 49, 0, 50,
    '{"currency":"echo"}'::jsonb,
    true
  ),
  (
    'template_private',
    '프라이빗 차트 템플릿',
    'VIP 차트 템플릿 1종 다운로드',
    'template', 19, 0, 60,
    '{"currency":"echo"}'::jsonb,
    true
  ),
  (
    'script_complain_pack',
    '컴플레인 방어 스크립트 팩',
    '환불·악평 대응 체크리스트',
    'knowledge', 29, 0, 70,
    '{"currency":"echo"}'::jsonb,
    true
  ),
  (
    'paywall_unlock',
    '페이월 잠금 열람',
    '골드+ 잠금 게시물 1회 열람 (참고 SKU)',
    'knowledge', 5, 0, 80,
    '{"currency":"echo","system":true}'::jsonb,
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
-- 3) Faucet quota counters + capped credit
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.echo_earn_quota (
  shop_id uuid not null references public.shops (id) on delete cascade,
  period_type text not null check (period_type in ('day', 'week', 'month')),
  period_key text not null,
  kind text not null,
  amount int not null default 0 check (amount >= 0),
  updated_at timestamptz not null default now(),
  primary key (shop_id, period_type, period_key, kind)
);

create index if not exists idx_echo_earn_quota_shop_month
  on public.echo_earn_quota (shop_id, period_type, period_key)
  where period_type = 'month';

comment on table public.echo_earn_quota is
  'Free Echo faucet 캡 카운터 — 월 ~70E 하드캡 + kind별 일/주 캡.';

alter table public.echo_earn_quota enable row level security;
drop policy if exists "mvp_echo_earn_quota_all" on public.echo_earn_quota;
create policy "mvp_echo_earn_quota_all"
  on public.echo_earn_quota for all using (true) with check (true);

create or replace function public.echo_period_key(
  p_type text,
  p_at timestamptz default now()
)
returns text
language sql
stable
as $$
  select case lower(p_type)
    when 'day' then to_char(p_at at time zone 'Asia/Seoul', 'YYYY-MM-DD')
    when 'week' then to_char(p_at at time zone 'Asia/Seoul', 'IYYY-"W"IW')
    when 'month' then to_char(p_at at time zone 'Asia/Seoul', 'YYYY-MM')
    else to_char(p_at at time zone 'Asia/Seoul', 'YYYY-MM')
  end;
$$;

-- Caps: monthly total 70; weekly case_share 15 (3×5); review 10 (2×5);
-- interior lumped in review; comment daily 5; best_comment weekly 15 (5×3)
create or replace function public.credit_free_echo_capped(
  p_shop_id uuid,
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
  v_day_key text := public.echo_period_key('day');
  v_month_used int := 0;
  v_kind_used int := 0;
  v_month_cap int := 70;
  v_kind_cap int := 0;
  v_period_type text := 'week';
  v_period_key text;
  v_grant int;
  v_tx public.point_transactions%rowtype;
begin
  if p_shop_id is null or v_want <= 0 then
    return jsonb_build_object('ok', false, 'granted', 0, 'reason', 'noop');
  end if;

  v_kind_cap := case v_kind
    when 'earn_case_share' then 15      -- 5E × 3/week
    when 'earn_review' then 10         -- 5E × 2/week (device) / interior shares budget
    when 'earn_comment' then 5         -- 1E × 5/day
    when 'earn_best_comment' then 15   -- 3E × 5/week
    else 10
  end;

  v_period_type := case when v_kind = 'earn_comment' then 'day' else 'week' end;
  v_period_key := case when v_kind = 'earn_comment' then v_day_key else v_week_key end;

  select coalesce(sum(amount), 0) into v_month_used
  from public.echo_earn_quota
  where shop_id = p_shop_id
    and period_type = 'month'
    and period_key = v_month_key;

  select coalesce(amount, 0) into v_kind_used
  from public.echo_earn_quota
  where shop_id = p_shop_id
    and period_type = v_period_type
    and period_key = v_period_key
    and kind = v_kind;

  v_grant := least(
    v_want,
    greatest(v_month_cap - v_month_used, 0),
    greatest(v_kind_cap - v_kind_used, 0)
  );

  if v_grant <= 0 then
    return jsonb_build_object(
      'ok', true,
      'granted', 0,
      'capped', true,
      'month_used', v_month_used,
      'kind_used', v_kind_used,
      'reason', 'faucet_cap'
    );
  end if;

  v_tx := public.credit_points(
    p_shop_id, v_grant, 'free', v_kind,
    coalesce(p_ref_type, ''), p_ref_id, null, coalesce(p_note, '')
  );

  insert into public.echo_earn_quota as q (
    shop_id, period_type, period_key, kind, amount, updated_at
  ) values
    (p_shop_id, 'month', v_month_key, '_total', v_grant, now()),
    (p_shop_id, v_period_type, v_period_key, v_kind, v_grant, now())
  on conflict (shop_id, period_type, period_key, kind) do update
    set amount = q.amount + excluded.amount,
        updated_at = now();

  return jsonb_build_object(
    'ok', true,
    'granted', v_grant,
    'requested', v_want,
    'capped', v_grant < v_want,
    'month_used', v_month_used + v_grant,
    'tx_id', v_tx.id
  );
end;
$$;

create or replace function public.earn_points_on_community_content()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'community_posts' then
    if new.status = 'published' and new.shop_id is not null then
      if new.post_type = 'case_share' then
        perform public.credit_free_echo_capped(
          new.shop_id, 5, 'earn_case_share',
          'community_post', new.id, '임상 차트 공유 +5 Echo'
        );
      elsif new.post_type = 'device_review' then
        perform public.credit_free_echo_capped(
          new.shop_id, 5, 'earn_review',
          'community_post', new.id, '기기 리뷰 +5 Echo'
        );
      elsif new.post_type = 'interior' then
        perform public.credit_free_echo_capped(
          new.shop_id, 3, 'earn_review',
          'community_post', new.id, '인테리어/노하우 +3 Echo'
        );
      end if;
    end if;
  elsif tg_table_name = 'community_comments' then
    if new.status = 'published' and new.author_shop_id is not null then
      perform public.credit_free_echo_capped(
        new.author_shop_id, 1, 'earn_comment',
        'community_comment', new.id, '댓글 +1 Echo'
      );
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.mark_best_community_comment(
  p_comment_id uuid,
  p_bonus int default 3
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_c public.community_comments%rowtype;
  v_bonus int := greatest(coalesce(p_bonus, 3), 1);
  v_res jsonb;
begin
  select * into v_c from public.community_comments where id = p_comment_id;
  if not found then
    raise exception 'comment not found';
  end if;
  if v_c.author_shop_id is null then
    raise exception 'comment has no author shop';
  end if;

  v_res := public.credit_free_echo_capped(
    v_c.author_shop_id, v_bonus, 'earn_best_comment',
    'community_comment', p_comment_id, '베스트 댓글 +3 Echo'
  );

  return jsonb_build_object(
    'ok', true,
    'comment_id', p_comment_id,
    'shop_id', v_c.author_shop_id,
    'bonus', v_bonus,
    'credit', v_res
  );
end;
$$;

-- Default paywall unlock cost → 5 Echo (054 function default)
create or replace function public.unlock_community_post_with_points(
  p_post_id uuid,
  p_viewer_shop_id uuid,
  p_cost int default 5,
  p_creator_share_pct int default 70
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.community_posts%rowtype;
  v_cost int := greatest(coalesce(p_cost, 5), 1);
  v_share_pct int := greatest(least(coalesce(p_creator_share_pct, 70), 100), 0);
  v_creator_share int;
  v_debit jsonb;
  v_media jsonb;
  v_unlocked boolean;
  v_creator_tx public.point_transactions%rowtype;
begin
  if p_post_id is null or p_viewer_shop_id is null then
    raise exception 'post_id and viewer_shop_id required';
  end if;

  select * into v_post from public.community_posts where id = p_post_id for share;
  if not found then
    raise exception 'post not found';
  end if;
  if v_post.shop_id = p_viewer_shop_id then
    raise exception 'cannot unlock own post';
  end if;

  if exists (
    select 1 from public.post_unlocks
    where post_id = p_post_id and shop_id = p_viewer_shop_id
  ) then
    v_unlocked := true;
  elsif public.can_view_community_post_full(
    v_post.visibility, v_post.shop_id, v_post.author_user_id, v_post.id
  ) then
    v_unlocked := true;
  else
    v_unlocked := false;
  end if;

  if not v_unlocked then
    v_creator_share := (v_cost * v_share_pct) / 100;

    v_debit := public.debit_points(
      p_viewer_shop_id, v_cost, 'unlock_spend',
      'community_post', p_post_id, v_post.shop_id, 'paywall unlock'
    );

    v_creator_tx := public.credit_points(
      v_post.shop_id,
      greatest(v_creator_share, 0),
      'free',
      'unlock_revenue',
      'community_post',
      p_post_id,
      p_viewer_shop_id,
      '창작 Echo(출금불가) ' || v_share_pct::text || '%'
    );

    if v_creator_tx.bucket is distinct from 'free'
       or v_creator_tx.kind is distinct from 'unlock_revenue' then
      raise exception 'creator share must remain non-withdrawable echo';
    end if;

    insert into public.post_unlocks (
      post_id, shop_id, user_id, points_spent, creator_share
    ) values (
      p_post_id, p_viewer_shop_id, auth.uid(), v_cost, v_creator_share
    )
    on conflict (post_id, shop_id) do nothing;
  else
    v_creator_share := 0;
    v_debit := '{}'::jsonb;
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'post_id', m.post_id,
      'image_url', m.image_url,
      'sort_order', m.sort_order
    )
    order by m.sort_order
  ), '[]'::jsonb)
  into v_media
  from public.post_media m
  where m.post_id = p_post_id;

  return jsonb_build_object(
    'ok', true,
    'already_unlocked', v_unlocked,
    'points_spent', case when v_unlocked then 0 else v_cost end,
    'creator_share', v_creator_share,
    'creator_currency', 'echo',
    'debit', v_debit,
    'post', jsonb_build_object(
      'id', v_post.id,
      'shop_id', v_post.shop_id,
      'author_user_id', v_post.author_user_id,
      'post_type', v_post.post_type,
      'title', v_post.title,
      'body', v_post.body,
      'style_tags', v_post.style_tags,
      'visibility', v_post.visibility,
      'status', v_post.status,
      'like_count', v_post.like_count,
      'comment_count', v_post.comment_count,
      'save_count', v_post.save_count,
      'source_chart_id', v_post.source_chart_id,
      'created_at', v_post.created_at,
      'is_body_locked', false,
      'unlock_cost', v_cost,
      'post_media', v_media
    )
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) Tier upgrade rewards + entitlements (Mentor+ lock-in coupons)
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.shop_entitlements (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  sku text not null,
  source text not null default 'tier_upgrade'
    check (source in ('tier_upgrade', 'subscription', 'promo', 'purchase')),
  status text not null default 'active'
    check (status in ('active', 'consumed', 'expired', 'void')),
  ref_tier text not null default '',
  note text not null default '',
  granted_at timestamptz not null default now(),
  expires_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_shop_entitlements_shop_active
  on public.shop_entitlements (shop_id, status, granted_at desc)
  where status = 'active';

comment on table public.shop_entitlements is
  'Echo 대체·보완 쿠폰 (부스터 등). Mentor+ 티어 락인용.';

alter table public.shop_entitlements enable row level security;
drop policy if exists "mvp_shop_entitlements_all" on public.shop_entitlements;
create policy "mvp_shop_entitlements_all"
  on public.shop_entitlements for all using (true) with check (true);

create table if not exists public.tier_upgrade_rewards_log (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  from_tier text not null default '',
  to_tier text not null,
  echo_granted int not null default 0,
  entitlement_sku text not null default '',
  created_at timestamptz not null default now(),
  unique (shop_id, to_tier)
);

comment on table public.tier_upgrade_rewards_log is
  '티어 승급 축하 Echo/쿠폰 지급 멱등 로그.';

alter table public.tier_upgrade_rewards_log enable row level security;
drop policy if exists "mvp_tier_upgrade_rewards_log_all" on public.tier_upgrade_rewards_log;
create policy "mvp_tier_upgrade_rewards_log_all"
  on public.tier_upgrade_rewards_log for all using (true) with check (true);

create or replace function public.tier_badge_rank(p_badge text)
returns int
language sql
immutable
as $$
  select case lower(trim(replace(coalesce(p_badge, 'none'), ' ', '_')))
    when 'iron' then 1
    when 'bronze' then 2
    when 'silver' then 3
    when 'gold' then 4
    when 'platinum' then 5
    when 'diamond' then 6
    when 'mentor' then 7
    when 'master' then 8
    when 'grand_master' then 9
    when 'grand_director' then 10
    else 0
  end;
$$;

create or replace function public.grant_tier_upgrade_reward(
  p_shop_id uuid,
  p_from_tier text,
  p_to_tier text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_to text := lower(trim(replace(coalesce(p_to_tier, ''), ' ', '_')));
  v_from text := lower(trim(replace(coalesce(p_from_tier, ''), ' ', '_')));
  v_echo int := 0;
  v_sku text := '';
  v_rank int;
begin
  if p_shop_id is null or v_to = '' or v_to = 'none' then
    return jsonb_build_object('ok', false, 'reason', 'noop');
  end if;
  if public.tier_badge_rank(v_to) <= public.tier_badge_rank(v_from) then
    return jsonb_build_object('ok', false, 'reason', 'not_upgrade');
  end if;

  if exists (
    select 1 from public.tier_upgrade_rewards_log
    where shop_id = p_shop_id and to_tier = v_to
  ) then
    return jsonb_build_object('ok', true, 'reason', 'already_granted');
  end if;

  v_rank := public.tier_badge_rank(v_to);

  -- Social track: full Echo. Mentor+ (7+): reduced Echo + booster coupon.
  v_echo := case v_to
    when 'iron' then 3
    when 'bronze' then 5
    when 'silver' then 8
    when 'gold' then 12
    when 'platinum' then 18
    when 'diamond' then 25
    when 'mentor' then 15          -- half cashy echo + coupon
    when 'master' then 20
    when 'grand_master' then 25
    when 'grand_director' then 30
    else 0
  end;

  v_sku := case
    when v_rank >= 7 then 'boost_local_1d'   -- Mentor+ lock-in coupon
    when v_to = 'platinum' then 'boost_local_2h'
    when v_to = 'diamond' then 'boost_local_2h'
    when v_to = 'gold' then 'ai_report_weekly'
    when v_to = 'silver' then 'template_private'
    else ''
  end;

  if v_echo > 0 then
    perform public.credit_points(
      p_shop_id, v_echo, 'free', 'tier_grant',
      'tier_upgrade', null, null,
      '티어 승급 축하 ' || v_to || ' +' || v_echo::text || ' Echo'
    );
  end if;

  if v_sku <> '' then
    insert into public.shop_entitlements (
      shop_id, sku, source, status, ref_tier, note, expires_at
    ) values (
      p_shop_id, v_sku, 'tier_upgrade', 'active', v_to,
      '티어 승급 쿠폰',
      now() + interval '90 days'
    );
  end if;

  insert into public.tier_upgrade_rewards_log (
    shop_id, from_tier, to_tier, echo_granted, entitlement_sku
  ) values (
    p_shop_id, v_from, v_to, v_echo, v_sku
  );

  return jsonb_build_object(
    'ok', true,
    'to_tier', v_to,
    'echo_granted', v_echo,
    'entitlement_sku', v_sku
  );
end;
$$;

create or replace function public.update_shop_tier_badge(p_shop_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shared int;
  v_likes int;
  v_followers int;
  v_requests int;
  v_seminars int;
  v_funding int;
  v_rolling int;
  v_social text := 'none';
  v_business text := 'none';
  v_badge text := 'none';
  v_prev text := 'none';
begin
  if p_shop_id is null then
    return 'none';
  end if;

  perform public.sync_shop_tier_metrics(p_shop_id);

  select
    coalesce(s.shared_case_count, 0),
    coalesce(s.total_likes, 0),
    coalesce(s.follower_count, 0),
    coalesce(s.seminar_request_count, 0),
    coalesce(s.completed_seminar_count, 0),
    coalesce(s.total_funding_amount, 0),
    coalesce(s.tier_badge::text, 'none')
  into v_shared, v_likes, v_followers, v_requests, v_seminars, v_funding, v_prev
  from public.shops s
  where s.id = p_shop_id;

  if not found then
    return 'none';
  end if;

  v_rolling := public.shop_rolling_12m_funding(p_shop_id);

  if v_shared >= 100 and v_likes >= 1200 and v_followers >= 500 then
    v_social := 'diamond';
  elsif v_shared >= 70 and v_likes >= 700 and v_followers >= 250 then
    v_social := 'platinum';
  elsif v_shared >= 45 and v_likes >= 350 and v_followers >= 120 then
    v_social := 'gold';
  elsif v_shared >= 25 and v_likes >= 150 and v_followers >= 60 then
    v_social := 'silver';
  elsif v_shared >= 10 and v_likes >= 60 and v_followers >= 25 then
    v_social := 'bronze';
  elsif v_shared >= 3 and v_likes >= 15 and v_followers >= 5 then
    v_social := 'iron';
  else
    v_social := 'none';
  end if;

  if v_requests >= 1000 and v_seminars >= 100 and v_rolling >= 100000000 then
    v_business := 'grand_director';
  elsif v_requests >= 200 and v_seminars >= 50 and v_funding >= 20000000 then
    v_business := 'grand_master';
  elsif v_requests >= 50 and v_seminars >= 10 and v_funding >= 5000000 then
    v_business := 'master';
  elsif v_requests >= 10 and v_seminars >= 1 then
    v_business := 'mentor';
  else
    v_business := 'none';
  end if;

  if v_business <> 'none' then
    v_badge := v_business;
  else
    v_badge := v_social;
  end if;

  update public.shops
  set tier_badge = v_badge::public.shop_tier_badge,
      updated_at = now()
  where id = p_shop_id;

  if public.tier_badge_rank(v_badge) > public.tier_badge_rank(v_prev) then
    perform public.grant_tier_upgrade_reward(p_shop_id, v_prev, v_badge);
  end if;

  return v_badge;
end;
$$;

grant execute on function public.echo_period_key(text, timestamptz)
  to anon, authenticated, service_role;
grant execute on function public.credit_free_echo_capped(uuid, int, text, text, uuid, text)
  to anon, authenticated, service_role;
grant execute on function public.tier_badge_rank(text)
  to anon, authenticated, service_role;
grant execute on function public.grant_tier_upgrade_reward(uuid, text, text)
  to anon, authenticated, service_role;
grant execute on function public.update_shop_tier_badge(uuid)
  to anon, authenticated, service_role;
grant execute on function public.mark_best_community_comment(uuid, int)
  to anon, authenticated, service_role;
grant execute on function public.unlock_community_post_with_points(uuid, uuid, int, int)
  to anon, authenticated, service_role;
