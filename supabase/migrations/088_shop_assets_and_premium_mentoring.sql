-- 088: Asset dashboard SSOT + Premium Mentoring pipeline (PO P0 sign-off)
-- Depends: 083 case_bookmarks, 087 shop_notifications kinds

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) chart_view_events — B/A 조회 SSOT
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.chart_view_events (
  id          uuid primary key default gen_random_uuid(),
  chart_id    uuid not null references public.customer_charts (id) on delete cascade,
  shop_id     uuid not null references public.shops (id) on delete cascade,
  viewer_id   uuid references public.profiles (id) on delete set null,
  session_key text,
  created_at  timestamptz not null default now()
);

create index if not exists idx_chart_view_events_chart
  on public.chart_view_events (chart_id, created_at desc);

create index if not exists idx_chart_view_events_shop
  on public.chart_view_events (shop_id, created_at desc);

comment on table public.chart_view_events is
  'B/A case detail view events — Asset Tier 1 ba_view_total SSOT.';

alter table public.chart_view_events enable row level security;
drop policy if exists "mvp_chart_view_events_all" on public.chart_view_events;
create policy "mvp_chart_view_events_all"
  on public.chart_view_events for all using (true) with check (true);

create or replace function public.record_chart_view(
  p_chart_id uuid,
  p_session_key text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_shop uuid;
  v_session text := nullif(trim(coalesce(p_session_key, '')), '');
  v_recent timestamptz;
begin
  if p_chart_id is null then
    raise exception 'chart_id required';
  end if;

  select cc.shop_id into v_shop
  from public.customer_charts cc
  where cc.id = p_chart_id;

  if v_shop is null then
    raise exception 'chart not found';
  end if;

  if v_uid is not null then
    select max(cve.created_at) into v_recent
    from public.chart_view_events cve
    where cve.chart_id = p_chart_id
      and cve.viewer_id = v_uid
      and cve.created_at > now() - interval '24 hours';
  elsif v_session is not null then
    select max(cve.created_at) into v_recent
    from public.chart_view_events cve
    where cve.chart_id = p_chart_id
      and cve.session_key = v_session
      and cve.created_at > now() - interval '24 hours';
  end if;

  if v_recent is not null then
    return jsonb_build_object('ok', true, 'deduped', true);
  end if;

  insert into public.chart_view_events (chart_id, shop_id, viewer_id, session_key)
  values (p_chart_id, v_shop, v_uid, v_session);

  return jsonb_build_object('ok', true, 'deduped', false);
end;
$$;

grant execute on function public.record_chart_view(uuid, text)
  to anon, authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Premium Mentoring — mentoring_requests + mentoring_posts
--    (shop_assets view in §3 — requires mentoring_posts)
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.mentoring_requests (
  id                  uuid primary key default gen_random_uuid(),
  chart_id            uuid not null references public.customer_charts (id) on delete cascade,
  requestor_shop_id   uuid not null references public.shops (id) on delete cascade,
  requestor_user_id   uuid not null references public.profiles (id) on delete cascade,
  question_body       text not null check (char_length(trim(question_body)) >= 20),
  status              text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'cancelled', 'expired')),
  author_response_at  timestamptz,
  created_at          timestamptz not null default now()
);

create unique index if not exists idx_mentoring_requests_pending_unique
  on public.mentoring_requests (chart_id, requestor_shop_id)
  where status = 'pending';

create index if not exists idx_mentoring_requests_chart
  on public.mentoring_requests (chart_id, created_at desc);

comment on table public.mentoring_requests is
  'B2B mentoring request track — other director asks case author.';

alter table public.mentoring_requests enable row level security;
drop policy if exists "mvp_mentoring_requests_all" on public.mentoring_requests;
create policy "mvp_mentoring_requests_all"
  on public.mentoring_requests for all using (true) with check (true);

create table if not exists public.mentoring_posts (
  id                      uuid primary key default gen_random_uuid(),
  chart_id                uuid not null references public.customer_charts (id) on delete cascade,
  author_shop_id          uuid not null references public.shops (id) on delete cascade,
  author_user_id          uuid not null references public.profiles (id) on delete cascade,
  origin                  text not null
    check (origin in ('proactive', 'request')),
  request_id              uuid references public.mentoring_requests (id) on delete set null,
  title                   text not null default 'Premium Mentoring',
  preview_teaser          text not null default '',
  body_locked             text not null default '',
  price_echo              int not null default 50 check (price_echo >= 1),
  status                  text not null default 'draft'
    check (status in (
      'draft',
      'active',
      'enhancement_required',
      'purchase_disabled',
      'archived'
    )),
  help_count              int not null default 0 check (help_count >= 0),
  not_help_count          int not null default 0 check (not_help_count >= 0),
  purchase_count          int not null default 0 check (purchase_count >= 0),
  revenue_echo_total      int not null default 0 check (revenue_echo_total >= 0),
  enhancement_started_at  timestamptz,
  enhancement_deadline_at timestamptz,
  last_body_updated_at    timestamptz,
  published_at            timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create unique index if not exists idx_mentoring_posts_one_live_per_chart
  on public.mentoring_posts (chart_id)
  where status not in ('archived');

create index if not exists idx_mentoring_posts_author
  on public.mentoring_posts (author_shop_id, status, updated_at desc);

comment on table public.mentoring_posts is
  'Premium Mentoring content locked to B/A chart — 1 live per chart.';

alter table public.mentoring_posts enable row level security;
drop policy if exists "mvp_mentoring_posts_all" on public.mentoring_posts;
create policy "mvp_mentoring_posts_all"
  on public.mentoring_posts for all using (true) with check (true);

create table if not exists public.mentoring_purchases (
  id                  uuid primary key default gen_random_uuid(),
  mentoring_post_id   uuid not null references public.mentoring_posts (id) on delete restrict,
  buyer_customer_id   uuid not null references public.customers (id) on delete cascade,
  buyer_shop_id       uuid references public.shops (id) on delete set null,
  echo_paid           int not null check (echo_paid > 0),
  price_at_purchase   int not null check (price_at_purchase > 0),
  point_tx_id         uuid references public.point_transactions (id) on delete set null,
  created_at          timestamptz not null default now(),
  unique (mentoring_post_id, buyer_customer_id)
);

comment on table public.mentoring_purchases is
  'Premium Mentoring unlock ledger — non-refundable.';

alter table public.mentoring_purchases enable row level security;
drop policy if exists "mvp_mentoring_purchases_all" on public.mentoring_purchases;
create policy "mvp_mentoring_purchases_all"
  on public.mentoring_purchases for all using (true) with check (true);

create table if not exists public.mentoring_feedback (
  purchase_id   uuid primary key references public.mentoring_purchases (id) on delete cascade,
  vote          text not null check (vote in ('helpful', 'not_helpful')),
  created_at    timestamptz not null default now()
);

comment on table public.mentoring_feedback is
  'Buyer quality vote — triggers downvote ratio check (min 5 votes).';

alter table public.mentoring_feedback enable row level security;
drop policy if exists "mvp_mentoring_feedback_all" on public.mentoring_feedback;
create policy "mvp_mentoring_feedback_all"
  on public.mentoring_feedback for all using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) shop_assets view + get_shop_assets RPC (after mentoring_posts)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace view public.shop_assets as
select
  s.id as shop_id,
  (
    select count(*)::int
    from public.customer_charts cc
    where cc.shop_id = s.id
  ) as chart_count_total,
  (
    select count(*)::int
    from public.customer_charts cc
    where cc.shop_id = s.id
      and coalesce(cc.is_case_shared, cc.case_shared, false) = true
  ) as ba_published_count,
  (
    select count(*)::int
    from public.chart_view_events cve
    where cve.shop_id = s.id
  ) as ba_view_total,
  (
    select count(*)::int
    from public.case_bookmarks cb
    join public.customer_charts cc on cc.id = cb.chart_id
    where cc.shop_id = s.id
  ) as bookmark_total,
  (
    select count(*)::int
    from public.seminar_classes sc
    where sc.director_shop_id = s.id
      and sc.status in ('open', 'held', 'completed')
  ) as seminar_hosted_count,
  (
    select count(*)::int
    from public.seminar_requests sr
    join public.customer_charts cc on cc.id = sr.case_id
    where cc.shop_id = s.id
  ) as seminar_request_received_count,
  (
    select count(*)::int
    from public.seminar_requests sr
    where sr.requestor_shop_id = s.id
  ) as seminar_request_sent_count,
  coalesce(s.follower_count, 0)::int as follower_count,
  (
    select count(distinct fg.fan_customer_id)::int
    from public.fan_gifts fg
    where fg.beneficiary_shop_id = s.id
      and fg.status = 'completed'
  ) as supporter_count,
  coalesce((
    select sum(mp.revenue_echo_total)::int
    from public.mentoring_posts mp
    where mp.author_shop_id = s.id
      and mp.status in ('active', 'enhancement_required', 'purchase_disabled')
  ), 0) as mentoring_revenue_echo_total
from public.shops s;

comment on view public.shop_assets is
  'Per-shop business asset aggregates — Asset tab Tier 1–2 SSOT.';

create or replace function public.get_shop_assets(p_shop_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row public.shop_assets%rowtype;
  v_t3 jsonb := '[]'::jsonb;
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  select * into v_row
  from public.shop_assets sa
  where sa.shop_id = p_shop_id;

  if not found then
    raise exception 'shop not found';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'customer_id', sub.customer_id,
      'display_name', sub.display_name,
      'avatar_url', sub.avatar_url,
      'echo_total', sub.echo_total,
      'last_interaction_at', sub.last_interaction_at
    )
    order by sub.echo_total desc
  ), '[]'::jsonb)
  into v_t3
  from (
    select
      fg.fan_customer_id as customer_id,
      coalesce(
        nullif(trim(max(fg.fan_display_name)), ''),
        nullif(trim(max(c.name)), ''),
        'Supporter'
      ) as display_name,
      coalesce(nullif(trim(max(p.avatar_url)), ''), '') as avatar_url,
      sum(fg.echo_spent)::int as echo_total,
      max(fg.created_at) as last_interaction_at
    from public.fan_gifts fg
    left join public.customers c on c.id = fg.fan_customer_id
    left join public.profiles p on p.id = c.user_id
    where fg.beneficiary_shop_id = p_shop_id
      and fg.status = 'completed'
    group by fg.fan_customer_id
    order by echo_total desc
    limit 20
  ) sub;

  return jsonb_build_object(
    'tier1', jsonb_build_object(
      'chart_count_total', v_row.chart_count_total,
      'ba_published_count', v_row.ba_published_count,
      'ba_view_total', v_row.ba_view_total,
      'bookmark_total', v_row.bookmark_total
    ),
    'tier2', jsonb_build_object(
      'seminar_hosted_count', v_row.seminar_hosted_count,
      'seminar_request_received_count', v_row.seminar_request_received_count,
      'seminar_request_sent_count', v_row.seminar_request_sent_count,
      'follower_count', v_row.follower_count,
      'supporter_count', v_row.supporter_count,
      'mentoring_revenue_echo_total', v_row.mentoring_revenue_echo_total
    ),
    'tier3_preview', v_t3,
    'refreshed_at', now()
  );
end;
$$;

grant execute on function public.get_shop_assets(uuid)
  to authenticated, service_role;

create or replace function public.get_supporter_interaction_statement(
  p_shop_id uuid,
  p_supporter_customer_id uuid,
  p_limit int default 50
)
returns table (
  occurred_at timestamptz,
  kind text,
  echo_amount int,
  target_label text,
  target_id uuid,
  metadata jsonb
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if p_shop_id is null or p_supporter_customer_id is null then
    raise exception 'shop_id and supporter_customer_id required';
  end if;

  return query
  (
    select
      fg.created_at,
      'supporter_gift'::text,
      fg.echo_spent,
      coalesce(
        nullif(trim(cc.care_name), ''),
        nullif(trim(cc.treatment_summary), ''),
        'Case boost'
      ),
      case when fg.target_type = 'chart' then fg.target_id else cp.source_chart_id end,
      jsonb_build_object(
        'fan_gift_id', fg.id,
        'sku', fg.sku,
        'gift_kind', fg.gift_kind
      )
    from public.fan_gifts fg
    left join public.customer_charts cc
      on fg.target_type = 'chart' and cc.id = fg.target_id
    left join public.community_posts cp
      on fg.target_type = 'community_post' and cp.id = fg.target_id
    where fg.beneficiary_shop_id = p_shop_id
      and fg.fan_customer_id = p_supporter_customer_id
      and fg.status = 'completed'
  )
  union all
  (
    select
      mp.created_at,
      'mentoring_purchase'::text,
      mp.echo_paid,
      coalesce(nullif(trim(mpost.title), ''), 'Premium Mentoring'),
      mpost.chart_id,
      jsonb_build_object('purchase_id', mp.id, 'mentoring_post_id', mpost.id)
    from public.mentoring_purchases mp
    join public.mentoring_posts mpost on mpost.id = mp.mentoring_post_id
    where mpost.author_shop_id = p_shop_id
      and mp.buyer_customer_id = p_supporter_customer_id
  )
  union all
  (
    select
      cb.created_at,
      'case_bookmark'::text,
      0,
      coalesce(nullif(trim(cc.care_name), ''), 'Case bookmark'),
      cb.chart_id,
      jsonb_build_object('folder', cb.folder)
    from public.case_bookmarks cb
    join public.customers c on c.id = p_supporter_customer_id
    join public.customer_charts cc on cc.id = cb.chart_id
    where cc.shop_id = p_shop_id
      and cb.user_id = c.user_id
  )
  order by occurred_at desc
  limit v_limit;
end;
$$;

grant execute on function public.get_supporter_interaction_statement(uuid, uuid, int)
  to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) point_transactions + shop_notifications kind extension
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
    'earn_visit',
    'earn_qa',
    'purchase',
    'unlock_spend',
    'unlock_revenue',
    'shop_spend',
    'boost_spend',
    'fan_boost_spend',
    'mentoring_purchase',
    'mentoring_sale',
    'subscription_grant',
    'promo_grant',
    'tier_grant',
    'expire',
    'refund',
    'adjust'
  ));

alter table public.shop_notifications
  drop constraint if exists shop_notifications_kind_check;

alter table public.shop_notifications
  add constraint shop_notifications_kind_check
  check (kind in (
    'fan_boost',
    'special_supporter',
    'case_bookmark',
    'market_inquiry',
    'tip',
    'system',
    'whisper',
    'like',
    'comment',
    'mentoring_request_received',
    'mentoring_request_accepted',
    'mentoring_enhance_request',
    'mentoring_purchase_received'
  ));

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) Mentoring RPCs + quality self-correction
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.get_mentoring_for_chart(p_chart_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_post public.mentoring_posts%rowtype;
  v_uid uuid := auth.uid();
  v_customer uuid;
  v_purchased boolean := false;
begin
  if p_chart_id is null then
    raise exception 'chart_id required';
  end if;

  select * into v_post
  from public.mentoring_posts mp
  where mp.chart_id = p_chart_id
    and mp.status <> 'archived'
  order by mp.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object('exists', false);
  end if;

  if v_uid is not null then
    select c.id into v_customer
    from public.customers c
    where c.user_id = v_uid
    limit 1;

    if v_customer is not null then
      select exists (
        select 1 from public.mentoring_purchases mp
        where mp.mentoring_post_id = v_post.id
          and mp.buyer_customer_id = v_customer
      ) into v_purchased;
    end if;
  end if;

  return jsonb_build_object(
    'exists', true,
    'id', v_post.id,
    'chart_id', v_post.chart_id,
    'author_shop_id', v_post.author_shop_id,
    'origin', v_post.origin,
    'title', v_post.title,
    'preview_teaser', v_post.preview_teaser,
    'body_locked', case
      when v_purchased
        or v_post.author_user_id = v_uid
        then v_post.body_locked
      else null
    end,
    'price_echo', v_post.price_echo,
    'status', v_post.status,
    'help_count', v_post.help_count,
    'not_help_count', v_post.not_help_count,
    'purchase_count', v_post.purchase_count,
    'purchased', v_purchased,
    'can_purchase', v_post.status = 'active' and not v_purchased,
    'published_at', v_post.published_at
  );
end;
$$;

grant execute on function public.get_mentoring_for_chart(uuid)
  to anon, authenticated, service_role;

create or replace function public.update_mentoring_price(
  p_mentoring_id uuid,
  p_price_echo int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_post public.mentoring_posts%rowtype;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if p_price_echo is null or p_price_echo < 1 then
    raise exception 'price_echo must be >= 1';
  end if;

  select * into v_post from public.mentoring_posts where id = p_mentoring_id;
  if not found then raise exception 'mentoring not found'; end if;
  if v_post.author_user_id <> v_uid then raise exception 'forbidden'; end if;
  if v_post.status = 'archived' then raise exception 'archived'; end if;

  update public.mentoring_posts
  set price_echo = p_price_echo, updated_at = now()
  where id = p_mentoring_id;

  return jsonb_build_object('ok', true, 'price_echo', p_price_echo);
end;
$$;

grant execute on function public.update_mentoring_price(uuid, int)
  to authenticated;

create or replace function public.purchase_mentoring_unlock(
  p_mentoring_id uuid,
  p_buyer_customer_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_post public.mentoring_posts%rowtype;
  v_buyer uuid := p_buyer_customer_id;
  v_wallet public.wallets%rowtype;
  v_debit jsonb;
  v_tx_id uuid;
  v_purchase_id uuid;
begin
  if v_uid is null and v_buyer is null then
    raise exception 'auth required';
  end if;

  select * into v_post
  from public.mentoring_posts
  where id = p_mentoring_id
  for update;

  if not found then raise exception 'mentoring not found'; end if;
  if v_post.status <> 'active' then
    raise exception 'mentoring not available for purchase (status=%)', v_post.status;
  end if;

  if v_buyer is null then
    select c.id into v_buyer from public.customers c where c.user_id = v_uid limit 1;
  end if;
  if v_buyer is null then raise exception 'buyer customer not found'; end if;

  if exists (
    select 1 from public.mentoring_purchases mp
    where mp.mentoring_post_id = p_mentoring_id
      and mp.buyer_customer_id = v_buyer
  ) then
    return jsonb_build_object(
      'ok', true,
      'already_purchased', true,
      'body_locked', v_post.body_locked
    );
  end if;

  v_wallet := public.ensure_customer_wallet(v_buyer);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  v_debit := public.debit_echo_wallet(
    v_wallet.id,
    v_post.price_echo,
    'mentoring_purchase',
    'mentoring_post',
    v_post.id,
    'Premium Mentoring unlock',
    v_post.author_shop_id
  );

  v_tx_id := nullif(trim(coalesce(v_debit->>'tx_id', '')), '')::uuid;

  perform public.credit_points(
    v_post.author_shop_id,
    v_post.price_echo,
    'paid',
    'mentoring_sale',
    'mentoring_post',
    v_post.id,
    null,
    'Premium Mentoring sale'
  );

  insert into public.mentoring_purchases (
    mentoring_post_id,
    buyer_customer_id,
    echo_paid,
    price_at_purchase,
    point_tx_id
  ) values (
    v_post.id,
    v_buyer,
    v_post.price_echo,
    v_post.price_echo,
    v_tx_id
  )
  returning id into v_purchase_id;

  update public.mentoring_posts
  set
    purchase_count = purchase_count + 1,
    revenue_echo_total = revenue_echo_total + v_post.price_echo,
    updated_at = now()
  where id = v_post.id;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_post.author_shop_id,
    'mentoring_purchase_received',
    'Premium Mentoring sold',
    format('%sE mentoring unlocked on your case', v_post.price_echo),
    jsonb_build_object(
      'mentoring_post_id', v_post.id,
      'purchase_id', v_purchase_id,
      'echo_paid', v_post.price_echo
    )
  );

  return jsonb_build_object(
    'ok', true,
    'purchase_id', v_purchase_id,
    'echo_paid', v_post.price_echo,
    'body_locked', v_post.body_locked
  );
end;
$$;

grant execute on function public.purchase_mentoring_unlock(uuid, uuid)
  to authenticated;

create or replace function public.submit_mentoring_feedback(
  p_purchase_id uuid,
  p_vote text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_customer uuid;
  v_vote text := lower(trim(coalesce(p_vote, '')));
  v_purchase public.mentoring_purchases%rowtype;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if v_vote not in ('helpful', 'not_helpful') then
    raise exception 'invalid vote';
  end if;

  select c.id into v_customer from public.customers c where c.user_id = v_uid limit 1;
  if v_customer is null then raise exception 'customer not found'; end if;

  select * into v_purchase
  from public.mentoring_purchases
  where id = p_purchase_id;

  if not found then raise exception 'purchase not found'; end if;
  if v_purchase.buyer_customer_id <> v_customer then raise exception 'forbidden'; end if;

  insert into public.mentoring_feedback (purchase_id, vote)
  values (p_purchase_id, v_vote)
  on conflict (purchase_id) do update set vote = excluded.vote;

  return jsonb_build_object('ok', true, 'vote', v_vote);
end;
$$;

grant execute on function public.submit_mentoring_feedback(uuid, text)
  to authenticated;

create or replace function public.trg_mentoring_feedback_quality()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_id uuid;
  v_post public.mentoring_posts%rowtype;
  v_help int;
  v_not int;
  v_total int;
  v_ratio numeric;
begin
  select mpu.mentoring_post_id into v_post_id
  from public.mentoring_purchases mpu
  where mpu.id = coalesce(new.purchase_id, old.purchase_id);

  if v_post_id is null then return coalesce(new, old); end if;

  select * into v_post from public.mentoring_posts where id = v_post_id;
  if not found then return coalesce(new, old); end if;

  select
    count(*) filter (where mf.vote = 'helpful'),
    count(*) filter (where mf.vote = 'not_helpful')
  into v_help, v_not
  from public.mentoring_feedback mf
  join public.mentoring_purchases mpu on mpu.id = mf.purchase_id
  where mpu.mentoring_post_id = v_post_id;

  v_total := coalesce(v_help, 0) + coalesce(v_not, 0);
  if v_total < 5 then return coalesce(new, old); end if;

  v_ratio := coalesce(v_not, 0)::numeric / v_total;

  if v_ratio > 0.30 and v_post.status = 'active' then
    update public.mentoring_posts
    set
      status = 'enhancement_required',
      enhancement_started_at = now(),
      enhancement_deadline_at = now() + interval '48 hours',
      updated_at = now()
    where id = v_post_id
      and status = 'active';

    insert into public.shop_notifications (
      shop_id, kind, title, body, payload
    ) values (
      v_post.author_shop_id,
      'mentoring_enhance_request',
      'Mentoring content needs improvement',
      format(
        'Downvote ratio %.0f%% exceeded 30%%. Update within 48h or new purchases will be disabled.',
        v_ratio * 100
      ),
      jsonb_build_object(
        'mentoring_post_id', v_post_id,
        'downvote_ratio', v_ratio,
        'deadline_at', now() + interval '48 hours'
      )
    );
  end if;

  return coalesce(new, old);
end;
$$;

create or replace function public.trg_mentoring_feedback_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_id uuid;
  v_help int;
  v_not int;
begin
  select mpu.mentoring_post_id into v_post_id
  from public.mentoring_purchases mpu
  where mpu.id = coalesce(new.purchase_id, old.purchase_id);

  if v_post_id is null then return coalesce(new, old); end if;

  select
    count(*) filter (where mf.vote = 'helpful'),
    count(*) filter (where mf.vote = 'not_helpful')
  into v_help, v_not
  from public.mentoring_feedback mf
  join public.mentoring_purchases mpu on mpu.id = mf.purchase_id
  where mpu.mentoring_post_id = v_post_id;

  update public.mentoring_posts
  set
    help_count = coalesce(v_help, 0),
    not_help_count = coalesce(v_not, 0),
    updated_at = now()
  where id = v_post_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_mentoring_feedback_counts on public.mentoring_feedback;
create trigger trg_mentoring_feedback_counts
  after insert or update or delete on public.mentoring_feedback
  for each row execute function public.trg_mentoring_feedback_counts();

drop trigger if exists trg_mentoring_feedback_quality on public.mentoring_feedback;
create trigger trg_mentoring_feedback_quality
  after insert or update on public.mentoring_feedback
  for each row execute function public.trg_mentoring_feedback_quality();

create or replace function public.expire_mentoring_enhancement_grace()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
begin
  update public.mentoring_posts mp
  set
    status = 'purchase_disabled',
    updated_at = now()
  where mp.status = 'enhancement_required'
    and mp.enhancement_deadline_at is not null
    and now() > mp.enhancement_deadline_at
    and coalesce(mp.last_body_updated_at, mp.published_at, mp.created_at)
        <= mp.enhancement_started_at;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.expire_mentoring_enhancement_grace()
  to service_role;

-- Body update resolves enhancement_required → active
create or replace function public.trg_mentoring_body_updated()
returns trigger
language plpgsql
as $$
begin
  if new.body_locked is distinct from old.body_locked
     or new.preview_teaser is distinct from old.preview_teaser then
    new.last_body_updated_at := now();
    if new.status = 'enhancement_required'
       and new.last_body_updated_at > coalesce(new.enhancement_started_at, '-infinity'::timestamptz) then
      new.status := 'active';
      new.enhancement_started_at := null;
      new.enhancement_deadline_at := null;
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_mentoring_posts_body_updated on public.mentoring_posts;
create trigger trg_mentoring_posts_body_updated
  before update on public.mentoring_posts
  for each row execute function public.trg_mentoring_body_updated();

create or replace function public.create_mentoring_request(
  p_chart_id uuid,
  p_question_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_chart public.customer_charts%rowtype;
  v_requestor_shop uuid;
  v_req public.mentoring_requests%rowtype;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if char_length(trim(coalesce(p_question_body, ''))) < 20 then
    raise exception 'question too short';
  end if;

  select * into v_chart from public.customer_charts where id = p_chart_id;
  if not found then raise exception 'chart not found'; end if;

  select s.id into v_requestor_shop
  from public.shops s
  join public.profiles p on p.id = s.owner_user_id
  where p.id = v_uid
  limit 1;

  if v_requestor_shop is null then raise exception 'requestor shop not found'; end if;
  if v_requestor_shop = v_chart.shop_id then
    raise exception 'cannot request mentoring on own case';
  end if;

  insert into public.mentoring_requests (
    chart_id, requestor_shop_id, requestor_user_id, question_body
  ) values (
    p_chart_id, v_requestor_shop, v_uid, trim(p_question_body)
  )
  returning * into v_req;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_chart.shop_id,
    'mentoring_request_received',
    'Mentoring request received',
    left(trim(p_question_body), 120),
    jsonb_build_object(
      'request_id', v_req.id,
      'chart_id', p_chart_id,
      'requestor_shop_id', v_requestor_shop
    )
  );

  return jsonb_build_object('ok', true, 'request_id', v_req.id);
end;
$$;

grant execute on function public.create_mentoring_request(uuid, text)
  to authenticated;

create or replace function public.respond_mentoring_request(
  p_request_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.mentoring_requests%rowtype;
  v_chart public.customer_charts%rowtype;
  v_post_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  select * into v_req
  from public.mentoring_requests
  where id = p_request_id
  for update;

  if not found then raise exception 'request not found'; end if;
  if v_req.status <> 'pending' then raise exception 'request not pending'; end if;

  select * into v_chart from public.customer_charts where id = v_req.chart_id;
  if v_chart.shop_id is null then raise exception 'chart shop missing'; end if;

  if not exists (
    select 1 from public.shops s
    where s.id = v_chart.shop_id and s.owner_user_id = v_uid
  ) then
    raise exception 'forbidden';
  end if;

  if not p_accept then
    update public.mentoring_requests
    set status = 'rejected', author_response_at = now()
    where id = p_request_id;
    return jsonb_build_object('ok', true, 'accepted', false);
  end if;

  update public.mentoring_requests
  set status = 'accepted', author_response_at = now()
  where id = p_request_id;

  begin
    insert into public.mentoring_posts (
      chart_id, author_shop_id, author_user_id,
      origin, request_id, preview_teaser, status
    ) values (
      v_req.chart_id,
      v_chart.shop_id,
      v_uid,
      'request',
      v_req.id,
      left(v_req.question_body, 200),
      'draft'
    )
    returning id into v_post_id;
  exception when unique_violation then
    select mp.id into v_post_id
    from public.mentoring_posts mp
    where mp.chart_id = v_req.chart_id
      and mp.status <> 'archived'
    limit 1;
  end;

  if v_post_id is null then
    select mp.id into v_post_id
    from public.mentoring_posts mp
    where mp.chart_id = v_req.chart_id
      and mp.status <> 'archived'
    limit 1;
  end if;

  return jsonb_build_object(
    'ok', true,
    'accepted', true,
    'mentoring_post_id', v_post_id
  );
end;
$$;

grant execute on function public.respond_mentoring_request(uuid, boolean)
  to authenticated;

create or replace function public.upsert_proactive_mentoring(
  p_chart_id uuid,
  p_teaser text,
  p_body text,
  p_price_echo int default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_chart public.customer_charts%rowtype;
  v_post public.mentoring_posts%rowtype;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if p_price_echo is null or p_price_echo < 1 then
    raise exception 'price_echo must be >= 1';
  end if;
  if char_length(trim(coalesce(p_body, ''))) < 20 then
    raise exception 'body too short';
  end if;

  select * into v_chart from public.customer_charts where id = p_chart_id;
  if not found then raise exception 'chart not found'; end if;

  if not exists (
    select 1 from public.shops s
    where s.id = v_chart.shop_id and s.owner_user_id = v_uid
  ) then
    raise exception 'forbidden';
  end if;

  select * into v_post
  from public.mentoring_posts mp
  where mp.chart_id = p_chart_id
    and mp.status <> 'archived'
  limit 1;

  if found then
    update public.mentoring_posts
    set
      preview_teaser = coalesce(nullif(trim(p_teaser), ''), preview_teaser),
      body_locked = trim(p_body),
      price_echo = p_price_echo,
      origin = 'proactive',
      updated_at = now()
    where id = v_post.id
    returning * into v_post;
  else
    insert into public.mentoring_posts (
      chart_id, author_shop_id, author_user_id,
      origin, preview_teaser, body_locked, price_echo, status
    ) values (
      p_chart_id, v_chart.shop_id, v_uid,
      'proactive', coalesce(trim(p_teaser), ''), trim(p_body), p_price_echo, 'draft'
    )
    returning * into v_post;
  end if;

  return jsonb_build_object(
    'ok', true,
    'mentoring_post_id', v_post.id,
    'status', v_post.status
  );
end;
$$;

grant execute on function public.upsert_proactive_mentoring(uuid, text, text, int)
  to authenticated;

create or replace function public.publish_mentoring_post(p_mentoring_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_post public.mentoring_posts%rowtype;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  select * into v_post from public.mentoring_posts where id = p_mentoring_id;
  if not found then raise exception 'mentoring not found'; end if;
  if v_post.author_user_id <> v_uid then raise exception 'forbidden'; end if;
  if char_length(trim(v_post.body_locked)) < 20 then
    raise exception 'body too short';
  end if;

  update public.mentoring_posts
  set
    status = 'active',
    published_at = coalesce(published_at, now()),
    updated_at = now()
  where id = p_mentoring_id;

  return jsonb_build_object('ok', true, 'status', 'active');
end;
$$;

grant execute on function public.publish_mentoring_post(uuid)
  to authenticated;
