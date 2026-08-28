-- 078_fan_gift_boost_and_fill.sql
-- S1: fan_gifts SSOT, purchase_fan_gift, Boost & Fill (sync + edge queue).

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) fan_gifts ledger
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.fan_gifts (
  id uuid primary key default gen_random_uuid(),
  beneficiary_shop_id uuid not null references public.shops (id) on delete cascade,
  target_type text not null check (target_type in ('chart', 'community_post')),
  target_id uuid not null,
  fan_customer_id uuid not null references public.customers (id) on delete cascade,
  fan_wallet_id uuid references public.wallets (id) on delete set null,
  fan_display_name text not null default '팬',
  gift_kind text not null check (gift_kind in ('boost', 'boost_with_ai_fill', 'ai_tool')),
  sku text not null,
  echo_spent int not null default 0 check (echo_spent >= 0),
  boost_placement_id uuid references public.boost_placements (id) on delete set null,
  ai_tool_job_id uuid references public.ai_tool_jobs (id) on delete set null,
  point_tx_id uuid references public.point_transactions (id) on delete set null,
  status text not null default 'completed'
    check (status in ('completed', 'cancelled', 'pending_owner')),
  created_at timestamptz not null default now()
);

create index if not exists idx_fan_gifts_target
  on public.fan_gifts (target_type, target_id, created_at desc);

create index if not exists idx_fan_gifts_beneficiary
  on public.fan_gifts (beneficiary_shop_id, created_at desc);

comment on table public.fan_gifts is
  'Fan gift ledger — boost / boost+AI fill / AI copy (S2).';

alter table public.fan_gifts enable row level security;
drop policy if exists "mvp_fan_gifts_all" on public.fan_gifts;
create policy "mvp_fan_gifts_all"
  on public.fan_gifts for all using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) ai_tool_jobs + community_posts extensions
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.ai_tool_jobs
  add column if not exists fan_customer_id uuid references public.customers (id) on delete set null,
  add column if not exists fan_display_name text,
  add column if not exists community_post_id uuid references public.community_posts (id) on delete set null,
  add column if not exists fan_gift_id uuid references public.fan_gifts (id) on delete set null;

alter table public.community_posts
  add column if not exists ai_filled_by_fan_gift_id uuid references public.fan_gifts (id) on delete set null;

alter table public.ai_tool_jobs
  drop constraint if exists ai_tool_jobs_charged_via_check;

alter table public.ai_tool_jobs
  add constraint ai_tool_jobs_charged_via_check
  check (charged_via in ('free_quota', 'echo_wallet', 'promo', 'fan_boost_bundle'));

alter table public.community_posts
  drop constraint if exists community_posts_body_source_check;

alter table public.community_posts
  add constraint community_posts_body_source_check
  check (
    body_source is null
    or body_source in ('manual', 'ai', 'ai_edited', 'fan_boost_fill')
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Boost & Fill helpers
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.post_body_needs_fan_fill(
  p_body text,
  p_summary text default '',
  p_insight text default '',
  p_care_name text default ''
)
returns boolean
language plpgsql
immutable
as $$
declare
  v_body text := trim(coalesce(p_body, ''));
  v_summary text := trim(coalesce(p_summary, ''));
  v_insight text := trim(coalesce(p_insight, ''));
  v_care text := trim(coalesce(p_care_name, ''));
  v_generic text;
begin
  if v_summary <> '' and length(v_summary) >= 80 then
    return false;
  end if;
  if v_insight <> '' and length(v_insight) >= 80 then
    return false;
  end if;
  if v_body = '' then
    return true;
  end if;
  if length(v_body) < 80 then
    return true;
  end if;
  if v_care <> '' then
    v_generic := v_care || ' 임상 기록 공유 (고객 정보는 비식별화되었습니다)';
    if v_body = v_generic then
      return true;
    end if;
  end if;
  if v_body ilike '%임상 기록 공유 (고객 정보는 비식별화되었습니다)%'
     and length(v_body) < 120 then
    return true;
  end if;
  return false;
end;
$$;

create or replace function public.fan_boost_build_fill_copy(
  p_chart public.customer_charts,
  p_customer public.customers default null
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_care text := coalesce(nullif(trim(p_chart.care_name), ''), '케어');
  v_concern text;
  v_chips text[];
  v_who text := '';
  v_age int;
  v_device text := nullif(trim(coalesce(p_chart.device_info, '')), '');
  v_insight text := coalesce(
    nullif(trim(p_chart.director_insight), ''),
    nullif(trim(p_chart.treatment_summary), ''),
    ''
  );
  v_body text;
  v_clinical text;
  v_title text;
begin
  v_chips := coalesce(p_chart.concern_chips, '{}'::text[]);
  v_concern := coalesce(
    nullif(v_chips[1], ''),
    '피부 컨디션'
  );

  if p_customer is not null and p_customer.birth_date is not null then
    v_age := extract(year from age(current_date, p_customer.birth_date::date))::int;
    if v_age between 0 and 120 then
      if v_age < 20 then
        v_who := '10대';
      elsif v_age < 30 then
        v_who := '20대';
      elsif v_age < 40 then
        v_who := '30대';
      elsif v_age < 50 then
        v_who := '40대';
      else
        v_who := '50대 이상';
      end if;
    end if;
    if coalesce(p_customer.gender, '') ilike any (array['female', 'f', '여', '여성']) then
      v_who := trim(v_who || ' 여성');
    elsif coalesce(p_customer.gender, '') ilike any (array['male', 'm', '남', '남성']) then
      v_who := trim(v_who || ' 남성');
    end if;
  end if;
  if v_who = '' then
    v_who := '고객';
  end if;

  v_body := format(
    '%s 분의 %s 고민에 맞춰 %s를 진행했습니다.%s %s',
    v_who,
    v_concern,
    v_care,
    case when v_device is not null then ' ' || v_device || '를 활용해' else '' end,
    case
      when v_insight <> '' then left(v_insight, 200)
      else '시술 전후 변화를 기록해 두었습니다. 개인 식별 정보는 포함되지 않습니다.'
    end
  );

  v_clinical := format(
    '【임상 참고 · 의료 진단 아님】 시술 %s, 주요 고민 %s.%s 원장 메모: %s',
    v_care,
    coalesce(nullif(array_to_string(v_chips, ', '), ''), '피부 컨디션'),
    case when v_device is not null then ' 사용 기기: ' || v_device || '.' else '' end,
    case when v_insight <> '' then left(v_insight, 200) else '추가 관찰 기록 없음.' end
  );

  v_title := left(v_care || ' · 임상 케이스', 28);

  return jsonb_build_object(
    'title', v_title,
    'body', v_body,
    'clinical_report', v_clinical,
    'hashtags', jsonb_build_array('#SORI', '#비포애프터', '#에스테틱'),
    'source', 'fan_boost_fill_sync'
  );
end;
$$;

create or replace function public.fan_boost_apply_fill(
  p_chart_id uuid,
  p_fill jsonb,
  p_fan_gift_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chart public.customer_charts%rowtype;
  v_post public.community_posts%rowtype;
  v_body text := trim(coalesce(p_fill->>'body', ''));
  v_clinical text := trim(coalesce(p_fill->>'clinical_report', ''));
  v_title text := trim(coalesce(p_fill->>'title', ''));
  v_combined text;
  v_post_id uuid;
begin
  if p_chart_id is null or v_body = '' then
    return jsonb_build_object('ok', false, 'reason', 'empty_fill');
  end if;

  select * into v_chart from public.customer_charts where id = p_chart_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'chart_not_found');
  end if;

  v_combined := v_body;
  if v_clinical <> '' then
    v_combined := v_body || E'\n\n' || v_clinical;
  end if;

  update public.customer_charts
  set
    treatment_summary = v_body,
    director_insight = case
      when v_clinical <> '' then v_clinical
      else director_insight
    end,
    updated_at = now()
  where id = p_chart_id;

  select p.*
  into v_post
  from public.community_posts p
  where p.source_chart_id = p_chart_id
    and p.status = 'published'
  order by p.created_at desc
  limit 1;

  if found then
    update public.community_posts
    set
      title = case when v_title <> '' then v_title else title end,
      body = v_combined,
      ai_generated_body = v_combined,
      ai_generated_at = now(),
      ai_model = coalesce(p_fill->>'source', 'fan_boost_fill_sync'),
      body_source = 'fan_boost_fill',
      ai_filled_by_fan_gift_id = coalesce(p_fan_gift_id, ai_filled_by_fan_gift_id),
      updated_at = now()
    where id = v_post.id
    returning id into v_post_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'chart_id', p_chart_id,
    'community_post_id', v_post_id,
    'body_length', length(v_combined)
  );
end;
$$;

-- Queue async Edge upgrade (pg_net) when extension is available.
create or replace function public.queue_fan_boost_edge_fill(
  p_job_id uuid,
  p_chart_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_key text;
begin
  if p_job_id is null or p_chart_id is null then
    return;
  end if;

  begin
    select decrypted_secret into v_url
    from vault.decrypted_secrets
    where name = 'supabase_url'
    limit 1;
    select decrypted_secret into v_key
    from vault.decrypted_secrets
    where name = 'service_role_key'
    limit 1;
  exception when others then
    return;
  end;

  if coalesce(v_url, '') = '' or coalesce(v_key, '') = '' then
    return;
  end if;

  begin
    perform net.http_post(
      url := rtrim(v_url, '/') || '/functions/v1/ai-case-story',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_key
      ),
      body := jsonb_build_object(
        'chart_id', p_chart_id,
        'mode', 'dual',
        'job_id', p_job_id,
        'internal_fan_fill', true
      )
    );
  exception when others then
    null;
  end;
end;
$$;

create or replace function public.run_fan_boost_ai_fill(
  p_shop_id uuid,
  p_chart_id uuid,
  p_fan_customer_id uuid,
  p_fan_display_name text,
  p_fan_gift_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chart public.customer_charts%rowtype;
  v_customer public.customers%rowtype;
  v_post public.community_posts%rowtype;
  v_fill jsonb;
  v_job public.ai_tool_jobs%rowtype;
  v_apply jsonb;
  v_post_body text := '';
begin
  select * into v_chart from public.customer_charts where id = p_chart_id;
  if not found then
    return jsonb_build_object('ok', false, 'skipped', true, 'reason', 'no_chart');
  end if;

  select * into v_customer from public.customers where id = v_chart.customer_id;

  select p.* into v_post
  from public.community_posts p
  where p.source_chart_id = p_chart_id and p.status = 'published'
  order by p.created_at desc
  limit 1;
  if found then
    v_post_body := coalesce(v_post.body, '');
  end if;

  if not public.post_body_needs_fan_fill(
    v_post_body,
    v_chart.treatment_summary,
    v_chart.director_insight,
    v_chart.care_name
  ) then
    return jsonb_build_object('ok', true, 'skipped', true, 'reason', 'body_sufficient');
  end if;

  insert into public.ai_tool_jobs (
    shop_id, chart_id, sku, mode, status,
    charged_echo, charged_via,
    fan_customer_id, fan_display_name, community_post_id, fan_gift_id
  ) values (
    p_shop_id, p_chart_id, 'ai_copy_dual', 'dual', 'queued',
    0, 'fan_boost_bundle',
    p_fan_customer_id, coalesce(nullif(trim(p_fan_display_name), ''), '팬'),
    v_post.id, p_fan_gift_id
  )
  returning * into v_job;

  update public.fan_gifts
  set
    gift_kind = 'boost_with_ai_fill',
    ai_tool_job_id = v_job.id
  where id = p_fan_gift_id;

  -- Immediate sync fill (edge-equivalent fallback) inside transaction.
  v_fill := public.fan_boost_build_fill_copy(v_chart, v_customer);
  v_apply := public.fan_boost_apply_fill(p_chart_id, v_fill, p_fan_gift_id);

  update public.ai_tool_jobs
  set
    status = 'done',
    result = v_fill || jsonb_build_object('apply', v_apply),
    completed_at = now()
  where id = v_job.id
  returning * into v_job;

  -- Async OpenAI upgrade when vault + pg_net configured.
  perform public.queue_fan_boost_edge_fill(v_job.id, p_chart_id);

  return jsonb_build_object(
    'ok', true,
    'skipped', false,
    'job_id', v_job.id,
    'fill', v_fill,
    'apply', v_apply,
    'edge_queued', true
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) purchase_fan_gift (+ purchase_fan_boost alias)
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
    'Fan gift boost ' || v_item.title,
    v_target_shop
  );

  v_tx_id := nullif(trim(coalesce(v_debit->>'tx_id', '')), '')::uuid;

  select settlement_balance into v_settlement_after
  from public.wallets where id = v_shop_wallet.id;
  if v_settlement_after is distinct from v_settlement_before then
    raise exception 'Fan gift must not change shop settlement_balance';
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

  select coalesce(nullif(trim(p_fan_display_name), ''), c.name, '팬')
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
    'fan_boost', p_fan_customer_id, v_wallet.id, coalesce(v_name, '팬')
  )
  returning * into v_placement;

  insert into public.fan_gifts (
    beneficiary_shop_id, target_type, target_id,
    fan_customer_id, fan_wallet_id, fan_display_name,
    gift_kind, sku, echo_spent,
    boost_placement_id, point_tx_id, status
  ) values (
    v_target_shop, v_type, p_target_id,
    p_fan_customer_id, v_wallet.id, coalesce(v_name, '팬'),
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
      coalesce(v_name, '팬'),
      v_gift.id
    );
  end if;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_target_shop,
    'fan_boost',
    '팬 응원 선물',
    case
      when coalesce(v_ai_fill->>'skipped', 'true') = 'false' then
        format('팬 %s님이 응원하며 케이스 스토리를 완성해 주었어요!', coalesce(v_name, '○○'))
      else
        format('팬 %s님이 끌어올리기를 선물했어요!', coalesce(v_name, '○○'))
    end,
    jsonb_build_object(
      'placement_id', v_placement.id,
      'fan_gift_id', v_gift.id,
      'customer_id', p_fan_customer_id,
      'sku', v_item.sku,
      'chart_id', v_chart_id,
      'fan_name', coalesce(v_name, '팬'),
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

comment on function public.purchase_fan_gift(uuid, text, text, uuid, text, text) is
  'Fan boost gift + optional Boost&Fill AI copy (bundled in boost SKU).';

create or replace function public.purchase_fan_boost(
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
  select public.purchase_fan_gift(
    p_customer_id, p_sku, p_target_type, p_target_id, p_fan_display_name, p_region_code
  );
$$;

comment on function public.purchase_fan_boost(uuid, text, text, uuid, text, text) is
  'Deprecated alias — use purchase_fan_gift.';

grant execute on function public.purchase_fan_gift(uuid, text, text, uuid, text, text)
  to anon, authenticated, service_role;
grant execute on function public.post_body_needs_fan_fill(text, text, text, text)
  to anon, authenticated, service_role;
grant execute on function public.run_fan_boost_ai_fill(uuid, uuid, uuid, text, uuid)
  to anon, authenticated, service_role;
