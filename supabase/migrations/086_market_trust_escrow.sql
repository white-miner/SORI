-- 086: E3 — 마켓 신뢰 (리스팅↔평판·문의·에스크로 라이트)
-- + 085 get_shop_trust_score seminar_classes 컬럼 치유

-- ═══════════════════════════════════════════════════════════════════════════
-- 0) 085 치유 — seminar_classes.director_shop_id
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.get_shop_trust_score(p_shop_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_bookmarks int := 0;
  v_echo int := 0;
  v_gifts int := 0;
  v_review_avg numeric := 0;
  v_review_count int := 0;
  v_seminar_count int := 0;
  v_thank_yous int := 0;
  v_pending int := 0;
  v_thank_rate numeric := 0;
  v_raw numeric := 0;
  v_score int := 0;
  v_label text := '성장 중';
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  select count(*)::int
  into v_bookmarks
  from public.case_bookmarks cb
  join public.customer_charts cc on cc.id = cb.chart_id
  where cc.shop_id = p_shop_id;

  select
    coalesce(sum(fg.echo_spent), 0)::int,
    count(*)::int,
    count(*) filter (
      where exists (
        select 1 from public.community_posts p
        where p.reply_to_fan_gift_id = fg.id
      )
    )::int
  into v_echo, v_gifts, v_thank_yous
  from public.fan_gifts fg
  where fg.beneficiary_shop_id = p_shop_id
    and fg.status = 'completed'
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    );

  if v_gifts > 0 then
    v_thank_rate := v_thank_yous::numeric / v_gifts::numeric;
  end if;

  select
    coalesce(avg(r.rating), 0),
    count(*)::int
  into v_review_avg, v_review_count
  from public.customer_reviews r
  where r.shop_id = p_shop_id
    and r.rating is not null
    and r.rating > 0;

  select count(*)::int
  into v_seminar_count
  from public.seminar_classes sc
  where sc.director_shop_id = p_shop_id;

  v_raw :=
    15 * ln(1 + v_bookmarks)
    + 25 * ln(1 + greatest(v_echo, 0) / 50.0)
    + 10 * ln(1 + v_gifts)
    + case
        when v_review_count > 0 then 20 * (v_review_avg / 5.0)
        else 0
      end
    + 10 * ln(1 + v_seminar_count)
    + 20 * v_thank_rate;

  v_score := round(least(100, greatest(0, v_raw)))::int;

  v_label := case
    when v_score >= 75 then '검증된 레퍼런스'
    when v_score >= 45 then '신뢰 쌓이는 중'
    else '성장 중'
  end;

  return jsonb_build_object(
    'ok', true,
    'score', v_score,
    'tier_label', v_label,
    'bookmark_count', v_bookmarks,
    'supporter_echo', v_echo,
    'supporter_gift_count', v_gifts,
    'review_avg', round(v_review_avg, 1),
    'review_count', v_review_count,
    'seminar_count', v_seminar_count,
    'thank_you_rate', round(v_thank_rate, 2)
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) market_listings — 판매자 신뢰 스냅샷
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.market_listings
  add column if not exists seller_trust_score int not null default 0,
  add column if not exists seller_trust_label text not null default '성장 중';

comment on column public.market_listings.seller_trust_score is
  '리스팅 시점 판매자 신뢰 스코어 스냅샷 (get_shop_trust_score).';

create or replace function public.refresh_market_listing_trust(p_listing_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop uuid;
  v_trust jsonb;
begin
  select shop_id into v_shop
  from public.market_listings
  where id = p_listing_id;

  if v_shop is null then return; end if;

  v_trust := public.get_shop_trust_score(v_shop);

  update public.market_listings
  set seller_trust_score = coalesce((v_trust->>'score')::int, 0),
      seller_trust_label = coalesce(v_trust->>'tier_label', '성장 중'),
      updated_at = now()
  where id = p_listing_id;
end;
$$;

create or replace function public.trg_market_listing_trust_refresh()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.refresh_market_listing_trust(NEW.id);
  return NEW;
end;
$$;

drop trigger if exists trg_market_listing_trust on public.market_listings;
create trigger trg_market_listing_trust
  after insert on public.market_listings
  for each row
  execute function public.trg_market_listing_trust_refresh();

-- 백필
do $$
declare r record;
begin
  for r in select id from public.market_listings loop
    perform public.refresh_market_listing_trust(r.id);
  end loop;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) market_escrow_holds — 라이트 에스크로
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.market_escrow_holds (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.market_listings (id) on delete cascade,
  inquiry_id uuid references public.listing_inquiries (id) on delete set null,
  buyer_shop_id uuid references public.shops (id) on delete set null,
  buyer_user_id uuid references public.profiles (id) on delete set null,
  amount int not null default 0 check (amount >= 0),
  status text not null default 'held'
    check (status in ('held', 'completed', 'refunded', 'cancelled')),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create unique index if not exists uq_market_escrow_held_listing
  on public.market_escrow_holds (listing_id)
  where status = 'held';

create index if not exists idx_market_escrow_listing
  on public.market_escrow_holds (listing_id, status, created_at desc);

comment on table public.market_escrow_holds is
  'E3 라이트 에스크로 — listing 1건당 held 1개 (완료/환불 시 종료).';

alter table public.market_escrow_holds enable row level security;
drop policy if exists "mvp_market_escrow_holds_all" on public.market_escrow_holds;
create policy "mvp_market_escrow_holds_all"
  on public.market_escrow_holds for all using (true) with check (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) list_market_listings_scored — 신뢰순 정렬
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_market_listings_scored(
  p_device_name text default '',
  p_limit int default 50
)
returns table (
  listing_id uuid,
  post_id uuid,
  shop_id uuid,
  shop_name text,
  device_name text,
  price int,
  listing_status text,
  seller_trust_score int,
  seller_trust_label text,
  escrow_status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
  v_q text := lower(trim(coalesce(p_device_name, '')));
begin
  return query
  select
    ml.id,
    ml.post_id,
    ml.shop_id,
    coalesce(nullif(trim(s.name), ''), 'SORI'),
    ml.device_name,
    ml.price,
    ml.listing_status,
    ml.seller_trust_score,
    ml.seller_trust_label,
    coalesce((
      select eh.status
      from public.market_escrow_holds eh
      where eh.listing_id = ml.id
        and eh.status = 'held'
      limit 1
    ), ''),
    ml.created_at
  from public.market_listings ml
  join public.shops s on s.id = ml.shop_id
  where ml.listing_status in ('active', 'reserved', 'sold')
    and (
      v_q = ''
      or lower(ml.device_name) like '%' || v_q || '%'
      or lower(ml.brand) like '%' || v_q || '%'
      or lower(ml.model) like '%' || v_q || '%'
    )
  order by
    case ml.listing_status
      when 'active' then 0
      when 'reserved' then 1
      else 2
    end,
    ml.seller_trust_score desc,
    ml.created_at desc
  limit v_limit;
end;
$$;

grant execute on function public.list_market_listings_scored(text, int)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) create_market_listing_inquiry
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.create_market_listing_inquiry(
  p_listing_id uuid,
  p_message text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_listing public.market_listings%rowtype;
  v_msg text := trim(coalesce(p_message, ''));
  v_inquiry_id uuid;
  v_buyer_shop uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_listing_id is null then
    raise exception 'listing_id required';
  end if;

  select * into v_listing
  from public.market_listings
  where id = p_listing_id;

  if not found then
    raise exception 'listing not found';
  end if;
  if v_listing.listing_status not in ('active', 'reserved') then
    raise exception 'listing not available';
  end if;
  if v_msg = '' then
    v_msg := '구매 문의드립니다.';
  end if;

  select p.shop_id into v_buyer_shop
  from public.profiles p
  where p.id = v_uid;

  insert into public.listing_inquiries (
    listing_id, buyer_shop_id, buyer_user_id, message
  ) values (
    p_listing_id, v_buyer_shop, v_uid, v_msg
  )
  returning id into v_inquiry_id;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_listing.shop_id,
    'market_inquiry',
    '중고 거래 문의',
    left(v_msg, 120),
    jsonb_build_object(
      'listing_id', p_listing_id,
      'inquiry_id', v_inquiry_id,
      'device_name', v_listing.device_name
    )
  );

  return jsonb_build_object(
    'ok', true,
    'inquiry_id', v_inquiry_id,
    'listing_id', p_listing_id
  );
end;
$$;

grant execute on function public.create_market_listing_inquiry(uuid, text)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) hold / complete / refund escrow (판매자)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.hold_market_escrow(
  p_listing_id uuid,
  p_inquiry_id uuid default null,
  p_amount int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing public.market_listings%rowtype;
  v_amount int;
  v_id uuid;
begin
  if p_listing_id is null then
    raise exception 'listing_id required';
  end if;

  select * into v_listing from public.market_listings where id = p_listing_id;
  if not found then raise exception 'listing not found'; end if;

  v_amount := coalesce(p_amount, v_listing.price);
  if v_amount < 0 then v_amount := 0; end if;

  if exists (
    select 1 from public.market_escrow_holds
    where listing_id = p_listing_id and status = 'held'
  ) then
    raise exception 'escrow already held';
  end if;

  insert into public.market_escrow_holds (
    listing_id, inquiry_id, amount, status
  ) values (
    p_listing_id, p_inquiry_id, v_amount, 'held'
  )
  returning id into v_id;

  update public.market_listings
  set listing_status = 'reserved', updated_at = now()
  where id = p_listing_id;

  return jsonb_build_object('ok', true, 'escrow_id', v_id, 'status', 'held');
end;
$$;

create or replace function public.complete_market_escrow(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  update public.market_escrow_holds
  set status = 'completed', completed_at = now()
  where listing_id = p_listing_id and status = 'held'
  returning id into v_id;

  if v_id is null then
    raise exception 'no held escrow';
  end if;

  update public.market_listings
  set listing_status = 'sold',
      sold_at = now(),
      updated_at = now()
  where id = p_listing_id;

  return jsonb_build_object('ok', true, 'escrow_id', v_id, 'status', 'completed');
end;
$$;

create or replace function public.refund_market_escrow(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  update public.market_escrow_holds
  set status = 'refunded', completed_at = now()
  where listing_id = p_listing_id and status = 'held'
  returning id into v_id;

  if v_id is null then
    raise exception 'no held escrow';
  end if;

  update public.market_listings
  set listing_status = 'active', updated_at = now()
  where id = p_listing_id;

  return jsonb_build_object('ok', true, 'escrow_id', v_id, 'status', 'refunded');
end;
$$;

grant execute on function public.hold_market_escrow(uuid, uuid, int) to authenticated;
grant execute on function public.complete_market_escrow(uuid) to authenticated;
grant execute on function public.refund_market_escrow(uuid) to authenticated;
