-- 075: Split & Micro pricing — ai_tool quota/jobs, repriced boosters, legacy credits

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) point_shop_items — allow ai_tool category
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.point_shop_items
  drop constraint if exists point_shop_items_category_check;

alter table public.point_shop_items
  add constraint point_shop_items_category_check
  check (category in (
    'booster', 'knowledge', 'ai_report', 'template', 'bundle', 'ai_tool', 'subscription'
  ));

-- Deactivate legacy high-price boosters
update public.point_shop_items
set is_active = false, updated_at = now()
where sku in ('boost_local_2h', 'boost_local_1d', 'boost_local_7d');

-- New micro boosters
insert into public.point_shop_items (
  sku, title, description, category, price_points, duration_hours, sort_order, metadata, is_active
) values
  (
    'boost_bump_4h',
    '피드 끌어올리기 · 4시간',
    '카테고리 피드 상단 재정렬 · 500원',
    'booster', 5, 4, 11,
    '{"placement":"category_bump","label":"BUMP","currency":"echo"}'::jsonb,
    true
  ),
  (
    'boost_spotlight_12h',
    '스포트라이트 · 12시간',
    'Home+커뮤니티 인터리브 슬롯 · 900원',
    'booster', 9, 12, 21,
    '{"placement":"home_local","label":"AD","currency":"echo"}'::jsonb,
    true
  ),
  (
    'boost_spotlight_24h',
    '스포트라이트 · 24시간',
    'Home+커뮤니티 인터리브 슬롯 24시간 · 1,500원',
    'booster', 15, 24, 22,
    '{"placement":"home_local","label":"AD","badge":"인기","currency":"echo"}'::jsonb,
    true
  ),
  (
    'boost_spotlight_7d',
    '스포트라이트 · 7일',
    'Home+커뮤니티 인터리브 슬롯 7일 · 5,900원',
    'booster', 59, 168, 23,
    '{"placement":"home_local","label":"AD","currency":"echo"}'::jsonb,
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

-- AI tool SKUs
insert into public.point_shop_items (
  sku, title, description, category, price_points, duration_hours, sort_order, metadata, is_active
) values
  (
    'ai_copy_marketing',
    'AI 마케팅 카피',
    '인스타·네이버용 감성 마케팅 카피 1회 · 200원',
    'ai_tool', 2, 0, 30,
    '{"currency":"echo","mode":"marketing"}'::jsonb,
    true
  ),
  (
    'ai_copy_clinical',
    'AI 임상 요약',
    '원장용 임상 요약 리포트 1회 · 300원',
    'ai_tool', 3, 0, 31,
    '{"currency":"echo","mode":"clinical"}'::jsonb,
    true
  ),
  (
    'ai_copy_dual',
    'AI 듀얼 생성',
    '마케팅 카피 + 임상 요약 동시 생성 · 400원',
    'ai_tool', 4, 0, 32,
    '{"currency":"echo","mode":"dual"}'::jsonb,
    true
  ),
  (
    'ai_regenerate',
    'AI 재생성',
    '동일 차트 AI 재생성 1회 · 100원',
    'ai_tool', 1, 0, 33,
    '{"currency":"echo","mode":"regenerate","no_free_quota":true}'::jsonb,
    true
  )
on conflict (sku) do update set
  title = excluded.title,
  description = excluded.description,
  category = excluded.category,
  price_points = excluded.price_points,
  sort_order = excluded.sort_order,
  metadata = excluded.metadata,
  is_active = true,
  updated_at = now();

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) ai_tool_quota — server-side monthly free tier (5/month)
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.ai_tool_quota (
  shop_id uuid not null references public.shops (id) on delete cascade,
  period_key text not null,
  free_used int not null default 0 check (free_used >= 0),
  free_limit int not null default 5 check (free_limit > 0),
  updated_at timestamptz not null default now(),
  primary key (shop_id, period_key)
);

comment on table public.ai_tool_quota is
  'AI tool monthly free quota per shop (default 5).';

alter table public.ai_tool_quota enable row level security;
drop policy if exists "mvp_ai_tool_quota_all" on public.ai_tool_quota;
create policy "mvp_ai_tool_quota_all"
  on public.ai_tool_quota for all using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) ai_tool_jobs — paid generation ledger
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.ai_tool_jobs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  chart_id uuid not null references public.customer_charts (id) on delete cascade,
  sku text not null,
  mode text not null default 'marketing'
    check (mode in ('marketing', 'clinical', 'dual', 'regenerate')),
  status text not null default 'queued'
    check (status in ('queued', 'processing', 'done', 'failed')),
  charged_echo int not null default 0 check (charged_echo >= 0),
  charged_via text not null default 'free_quota'
    check (charged_via in ('free_quota', 'echo_wallet', 'promo')),
  point_tx_id uuid references public.point_transactions (id) on delete set null,
  result jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists idx_ai_tool_jobs_shop_created
  on public.ai_tool_jobs (shop_id, created_at desc);

create index if not exists idx_ai_tool_jobs_chart
  on public.ai_tool_jobs (chart_id, created_at desc);

comment on table public.ai_tool_jobs is
  'AI tool purchase + generation job SSOT.';

alter table public.ai_tool_jobs enable row level security;
drop policy if exists "mvp_ai_tool_jobs_all" on public.ai_tool_jobs;
create policy "mvp_ai_tool_jobs_all"
  on public.ai_tool_jobs for all using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) shop_promo_credits — legacy boost compensation + future promos
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.shop_promo_credits (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  credit_sku text not null,
  balance int not null default 0 check (balance >= 0),
  source text not null default '',
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, credit_sku, source)
);

create index if not exists idx_shop_promo_credits_shop
  on public.shop_promo_credits (shop_id, credit_sku)
  where balance > 0;

comment on table public.shop_promo_credits is
  'Promotional SKU credits (e.g. legacy boost_local_1d → spotlight coupons).';

alter table public.shop_promo_credits enable row level security;
drop policy if exists "mvp_shop_promo_credits_all" on public.shop_promo_credits;
create policy "mvp_shop_promo_credits_all"
  on public.shop_promo_credits for all using (true) with check (true);

-- One-time grant: past boost_local_1d buyers → 10× boost_spotlight_12h
insert into public.shop_promo_credits (shop_id, credit_sku, balance, source, note)
select distinct
  bp.shop_id,
  'boost_spotlight_12h',
  10,
  'legacy_boost_89e',
  '기존 1일 부스터(89E) 구매 보상 — 스포트라이트 12h 쿠폰 10장'
from public.boost_placements bp
where bp.item_sku = 'boost_local_1d'
  and bp.shop_id is not null
on conflict (shop_id, credit_sku, source) do update set
  balance = greatest(shop_promo_credits.balance, excluded.balance),
  note = excluded.note,
  updated_at = now();

-- Also grant from point_transactions metadata if placements were expired
insert into public.shop_promo_credits (shop_id, credit_sku, balance, source, note)
select distinct
  pt.shop_id,
  'boost_spotlight_12h',
  10,
  'legacy_boost_89e',
  '기존 1일 부스터(89E) 구매 보상 — 스포트라이트 12h 쿠폰 10장'
from public.point_transactions pt
join public.point_shop_items psi on psi.id = pt.ref_id
where pt.kind = 'boost_spend'
  and psi.sku = 'boost_local_1d'
  and pt.shop_id is not null
on conflict (shop_id, credit_sku, source) do nothing;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) Helpers
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.ai_tool_period_key(p_at timestamptz default now())
returns text
language sql
stable
as $$
  select to_char(p_at at time zone 'Asia/Seoul', 'YYYY-MM');
$$;

create or replace function public.get_ai_tool_quota(p_shop_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_key text := public.ai_tool_period_key();
  v_used int := 0;
  v_limit int := 5;
begin
  if p_shop_id is null then
    return jsonb_build_object('free_used', 0, 'free_limit', 5, 'free_remaining', 5);
  end if;

  select coalesce(q.free_used, 0), coalesce(q.free_limit, 5)
  into v_used, v_limit
  from public.ai_tool_quota q
  where q.shop_id = p_shop_id and q.period_key = v_key;

  return jsonb_build_object(
    'period_key', v_key,
    'free_used', v_used,
    'free_limit', v_limit,
    'free_remaining', greatest(v_limit - v_used, 0)
  );
end;
$$;

create or replace function public.get_shop_promo_credits(p_shop_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rows jsonb;
begin
  if p_shop_id is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'credit_sku', c.credit_sku,
    'balance', c.balance,
    'source', c.source,
    'note', c.note
  ) order by c.credit_sku), '[]'::jsonb)
  into v_rows
  from public.shop_promo_credits c
  where c.shop_id = p_shop_id and c.balance > 0;

  return v_rows;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 6) purchase_ai_tool — quota-first micro billing
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.purchase_ai_tool(
  p_shop_id uuid,
  p_chart_id uuid,
  p_sku text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.point_shop_items%rowtype;
  v_sku text := lower(trim(coalesce(p_sku, '')));
  v_chart_shop uuid;
  v_period text := public.ai_tool_period_key();
  v_used int := 0;
  v_limit int := 5;
  v_no_free boolean := false;
  v_mode text := 'marketing';
  v_charged int := 0;
  v_via text := 'free_quota';
  v_debit jsonb;
  v_wallet public.wallets%rowtype;
  v_have int;
  v_job public.ai_tool_jobs%rowtype;
  v_settlement_before int;
begin
  if p_shop_id is null or p_chart_id is null or v_sku = '' then
    raise exception 'shop_id, chart_id, sku required';
  end if;

  select shop_id into v_chart_shop
  from public.customer_charts where id = p_chart_id;
  if v_chart_shop is null or v_chart_shop is distinct from p_shop_id then
    raise exception 'chart does not belong to shop';
  end if;

  select * into v_item
  from public.point_shop_items
  where sku = v_sku and is_active = true and category = 'ai_tool';
  if not found then
    raise exception 'ai_tool sku not found: %', v_sku;
  end if;

  v_mode := coalesce(nullif(v_item.metadata->>'mode', ''), 'marketing');
  v_no_free := coalesce((v_item.metadata->>'no_free_quota')::boolean, false);

  if not v_no_free then
    insert into public.ai_tool_quota as q (shop_id, period_key, free_used, free_limit)
    values (p_shop_id, v_period, 0, 5)
    on conflict (shop_id, period_key) do nothing;

    select q.free_used, q.free_limit
    into v_used, v_limit
    from public.ai_tool_quota q
    where q.shop_id = p_shop_id and q.period_key = v_period
    for update;

    if v_used < v_limit then
      v_charged := 0;
      v_via := 'free_quota';
      update public.ai_tool_quota
      set free_used = free_used + 1, updated_at = now()
      where shop_id = p_shop_id and period_key = v_period;
    else
      v_charged := v_item.price_points;
      v_via := 'echo_wallet';
    end if;
  else
    v_charged := v_item.price_points;
    v_via := 'echo_wallet';
  end if;

  if v_charged > 0 then
    v_wallet := public.ensure_shop_wallet(p_shop_id);
    select * into v_wallet from public.wallets where id = v_wallet.id for update;
    v_settlement_before := v_wallet.settlement_balance;
    v_have := v_wallet.point_free_balance + v_wallet.point_paid_balance;
    if v_have < v_charged then
      raise exception 'insufficient points: have %, need %', v_have, v_charged
        using errcode = 'P0001', hint = format('gap=%s', v_charged - v_have);
    end if;

    v_debit := public.debit_points(
      p_shop_id,
      v_charged,
      'shop_spend',
      'ai_tool_job',
      v_item.id,
      null,
      coalesce(v_item.title, v_sku)
    );

    select * into v_wallet from public.wallets where shop_id = p_shop_id;
    if v_wallet.settlement_balance is distinct from v_settlement_before then
      raise exception 'settlement_balance must not change on ai_tool purchase';
    end if;
  end if;

  insert into public.ai_tool_jobs (
    shop_id, chart_id, sku, mode, status, charged_echo, charged_via
  ) values (
    p_shop_id, p_chart_id, v_item.sku, v_mode, 'queued', v_charged, v_via
  )
  returning * into v_job;

  return jsonb_build_object(
    'ok', true,
    'job_id', v_job.id,
    'sku', v_item.sku,
    'mode', v_mode,
    'charged_echo', v_charged,
    'charged_via', v_via,
    'quota', public.get_ai_tool_quota(p_shop_id),
    'debit', v_debit
  );
end;
$$;

create or replace function public.complete_ai_tool_job(
  p_job_id uuid,
  p_result jsonb,
  p_status text default 'done',
  p_error_message text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job public.ai_tool_jobs%rowtype;
  v_st text := lower(trim(coalesce(p_status, 'done')));
begin
  if p_job_id is null then
    raise exception 'job_id required';
  end if;
  if v_st not in ('done', 'failed') then
    raise exception 'invalid status %', v_st;
  end if;

  update public.ai_tool_jobs
  set
    status = v_st,
    result = case when v_st = 'done' then p_result else result end,
    error_message = nullif(trim(p_error_message), ''),
    completed_at = now()
  where id = p_job_id
  returning * into v_job;

  if not found then
    raise exception 'job not found';
  end if;

  return jsonb_build_object('ok', true, 'job', to_jsonb(v_job));
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 7) purchase_point_shop_item — promo credit for matching boost SKU
-- ═══════════════════════════════════════════════════════════════════════════

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
  v_promo_id uuid;
  v_promo_balance int := 0;
  v_used_promo boolean := false;
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

  v_wallet := public.ensure_shop_wallet(p_shop_id);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;
  v_settlement_before := v_wallet.settlement_balance;
  v_have := v_wallet.point_free_balance + v_wallet.point_paid_balance;
  v_need := v_item.price_points;

  -- Promo credit (e.g. legacy spotlight coupons)
  if v_item.category = 'booster' then
    select c.id, c.balance into v_promo_id, v_promo_balance
    from public.shop_promo_credits c
    where c.shop_id = p_shop_id
      and c.credit_sku = v_item.sku
      and c.balance > 0
    order by c.created_at
    limit 1
    for update;

    if v_promo_balance > 0 then
      update public.shop_promo_credits
      set balance = balance - 1, updated_at = now()
      where id = v_promo_id;
      v_need := 0;
      v_used_promo := true;
    end if;
  end if;

  if v_need > 0 and v_have < v_need then
    raise exception 'insufficient points: have %, need %', v_have, v_need
      using errcode = 'P0001',
            hint = format('gap=%s', v_need - v_have);
  end if;

  if v_need > 0 then
    v_debit := public.debit_points(
      p_shop_id,
      v_need,
      case when v_item.category = 'booster' then 'boost_spend' else 'shop_spend' end,
      'point_shop_item',
      v_item.id,
      null,
      coalesce(v_item.title, v_sku)
    );
  end if;

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
      v_starts, v_ends, 'active',
      case when v_used_promo then 0 else v_need end
    )
    returning * into v_placement;
  end if;

  return jsonb_build_object(
    'ok', true,
    'sku', v_item.sku,
    'category', v_item.category,
    'points_spent', case when v_used_promo then 0 else v_need end,
    'used_promo_credit', v_used_promo,
    'debit', v_debit,
    'promo_credits', public.get_shop_promo_credits(p_shop_id),
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

-- ═══════════════════════════════════════════════════════════════════════════
-- 8) Grants
-- ═══════════════════════════════════════════════════════════════════════════

grant execute on function public.ai_tool_period_key(timestamptz)
  to anon, authenticated, service_role;
grant execute on function public.get_ai_tool_quota(uuid)
  to anon, authenticated, service_role;
grant execute on function public.get_shop_promo_credits(uuid)
  to anon, authenticated, service_role;
grant execute on function public.purchase_ai_tool(uuid, uuid, text)
  to anon, authenticated, service_role;
grant execute on function public.complete_ai_tool_job(uuid, jsonb, text, text)
  to anon, authenticated, service_role;
