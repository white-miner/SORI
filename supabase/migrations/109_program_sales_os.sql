-- PRD v7.1 — Program 탭 세일즈 OS
--
-- 운영 메뉴(shop_menus) / 타이머 프리셋과 분리한다.
-- 차트 care_name 에 패키지 정가가 흘러 들어가면 관리 케이스 피드가 견적서가 된다.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) 카테고리 · 패키지 · 구성 라인
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.program_categories (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null references public.shops(id) on delete cascade,
  name        text not null,
  subtitle    text not null default '',
  sort_order  int  not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (shop_id, name)
);

comment on table public.program_categories is
  'PRD v7.1 — 상담 보드 섹션. 운영 shop_menus 와 별개.';

create table if not exists public.program_packages (
  id              uuid primary key default gen_random_uuid(),
  shop_id         uuid not null references public.shops(id) on delete cascade,
  category_id     uuid not null references public.program_categories(id) on delete cascade,
  name            text not null,
  visit_count     int  not null check (visit_count > 0),
  list_price_krw  int  not null check (list_price_krw >= 0),
  tier            text not null default 'target'
                  check (tier in ('anchor', 'target', 'decoy')),
  is_active       boolean not null default true,
  sort_order      int  not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on column public.program_packages.list_price_krw is
  '정가. 프로모션이 덮어쓰지 않는다. 보드 앵커는 카테고리 내 max 로 파생.';
comment on column public.program_packages.tier is
  '분석/시드용. 고객 UI 라벨이 아님. 앵커 노출은 가격 max.';

create index if not exists program_packages_category_idx
  on public.program_packages (category_id, is_active, list_price_krw desc);

create table if not exists public.program_package_lines (
  id            uuid primary key default gen_random_uuid(),
  package_id    uuid not null references public.program_packages(id) on delete cascade,
  kind          text not null check (kind in ('step', 'device', 'ampoule', 'perk')),
  label         text not null,
  minutes       int,
  shop_menu_id  uuid references public.shop_menus(id) on delete set null,
  sort_order    int  not null default 0
);

comment on column public.program_package_lines.shop_menu_id is
  '선택 힌트. 라벨은 비정규화 — 운영 메뉴 개명이 지난 견적을 따라가지 않는다.';

create index if not exists program_package_lines_pkg_idx
  on public.program_package_lines (package_id, sort_order);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) 프로모션 카탈로그 · 견적
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.program_promotions (
  id              uuid primary key default gen_random_uuid(),
  shop_id         uuid not null references public.shops(id) on delete cascade,
  kind            text not null check (kind in (
                    'extra_session',
                    'gift',
                    'instant_discount',
                    'next_visit_credit'
                  )),
  title           text not null,
  subtitle        text not null default '',
  value_krw       int  not null default 0 check (value_krw >= 0),
  extra_visits    int  not null default 0 check (extra_visits >= 0),
  discount_krw    int  not null default 0 check (discount_krw >= 0),
  is_active       boolean not null default true,
  sort_order      int  not null default 0,
  valid_from      timestamptz,
  valid_until     timestamptz,
  created_at      timestamptz not null default now()
);

comment on column public.program_promotions.value_krw is
  '고객에게 보여주는 혜택 환산액. payable 과 별개.';
comment on column public.program_promotions.discount_krw is
  '오늘 결제액에서만 뺀다. gift / extra_session 은 0.';

create table if not exists public.program_quotes (
  id                 uuid primary key default gen_random_uuid(),
  shop_id            uuid not null references public.shops(id) on delete cascade,
  author_id          uuid references public.profiles(id) on delete set null,
  customer_id        uuid references public.customers(id) on delete set null,
  left_package_id    uuid references public.program_packages(id) on delete set null,
  right_package_id   uuid references public.program_packages(id) on delete set null,
  chosen_package_id  uuid references public.program_packages(id) on delete set null,
  snapshot           jsonb not null default '{}'::jsonb,
  list_price_krw     int  not null default 0,
  benefit_value_krw  int  not null default 0,
  payable_krw        int  not null default 0,
  status             text not null default 'draft'
                     check (status in ('draft', 'presented', 'accepted', 'abandoned')),
  presented_at       timestamptz,
  accepted_at        timestamptz,
  created_at         timestamptz not null default now()
);

create table if not exists public.program_quote_promos (
  quote_id      uuid not null references public.program_quotes(id) on delete cascade,
  promotion_id  uuid not null references public.program_promotions(id) on delete restrict,
  sort_order    int  not null default 0,
  primary key (quote_id, promotion_id)
);

create index if not exists program_quotes_shop_idx
  on public.program_quotes (shop_id, created_at desc);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) RLS — 원장 프라이빗. 가격표가 공개 API 로 나가지 않는다.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.program_shop_is_director(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.shop_memberships sm
    where sm.shop_id = p_shop_id
      and sm.user_id = auth.uid()
      and sm.role in ('owner', 'director')
  );
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'program_categories',
    'program_packages',
    'program_package_lines',
    'program_promotions',
    'program_quotes',
    'program_quote_promos'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

drop policy if exists program_categories_director on public.program_categories;
create policy program_categories_director
  on public.program_categories for all
  using (public.program_shop_is_director(shop_id))
  with check (public.program_shop_is_director(shop_id));

drop policy if exists program_packages_director on public.program_packages;
create policy program_packages_director
  on public.program_packages for all
  using (public.program_shop_is_director(shop_id))
  with check (public.program_shop_is_director(shop_id));

drop policy if exists program_package_lines_director on public.program_package_lines;
create policy program_package_lines_director
  on public.program_package_lines for all
  using (
    exists (
      select 1 from public.program_packages p
      where p.id = package_id
        and public.program_shop_is_director(p.shop_id)
    )
  )
  with check (
    exists (
      select 1 from public.program_packages p
      where p.id = package_id
        and public.program_shop_is_director(p.shop_id)
    )
  );

drop policy if exists program_promotions_director on public.program_promotions;
create policy program_promotions_director
  on public.program_promotions for all
  using (public.program_shop_is_director(shop_id))
  with check (public.program_shop_is_director(shop_id));

drop policy if exists program_quotes_director on public.program_quotes;
create policy program_quotes_director
  on public.program_quotes for all
  using (public.program_shop_is_director(shop_id))
  with check (public.program_shop_is_director(shop_id));

drop policy if exists program_quote_promos_director on public.program_quote_promos;
create policy program_quote_promos_director
  on public.program_quote_promos for all
  using (
    exists (
      select 1 from public.program_quotes q
      where q.id = quote_id
        and public.program_shop_is_director(q.shop_id)
    )
  )
  with check (
    exists (
      select 1 from public.program_quotes q
      where q.id = quote_id
        and public.program_shop_is_director(q.shop_id)
    )
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) accept_program_quote — 견적 수락 + 회원권 jsonb 발급
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.accept_program_quote(
  p_quote_id    uuid,
  p_customer_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote     public.program_quotes;
  v_chosen    jsonb;
  v_visits    int;
  v_extra     int;
  v_paid      int;
  v_unit      int;
  v_member    jsonb;
  v_customer  public.customers;
begin
  select * into v_quote
    from public.program_quotes
   where id = p_quote_id
     for update;

  if not found then
    raise exception 'program_quote % not found', p_quote_id
      using errcode = 'P0002';
  end if;

  if not public.program_shop_is_director(v_quote.shop_id) then
    raise exception 'not director of shop'
      using errcode = '42501';
  end if;

  if p_customer_id is null then
    raise exception 'customer_id required'
      using errcode = '22023';
  end if;

  select * into v_customer
    from public.customers
   where id = p_customer_id
     for update;

  if not found then
    raise exception 'customer % not found', p_customer_id
      using errcode = 'P0002';
  end if;

  if v_quote.chosen_package_id is not null
     and (v_quote.snapshot -> 'right' ->> 'id') = v_quote.chosen_package_id::text then
    v_chosen := v_quote.snapshot -> 'right';
  else
    v_chosen := v_quote.snapshot -> 'left';
  end if;

  v_visits := greatest(coalesce((v_chosen ->> 'visit_count')::int, 1), 1);
  v_paid   := greatest(v_quote.payable_krw, 0);

  select coalesce(sum(pr.extra_visits), 0)
    into v_extra
    from public.program_quote_promos qp
    join public.program_promotions pr on pr.id = qp.promotion_id
   where qp.quote_id = p_quote_id;

  v_visits := v_visits + coalesce(v_extra, 0);
  v_unit := case when v_visits > 0 then (v_paid / v_visits) else 0 end;

  v_member := jsonb_build_object(
    'id', gen_random_uuid()::text,
    'service_name', coalesce(v_chosen ->> 'name', 'Program'),
    'total_visits', v_visits,
    'used_visits', 0,
    'paid_amount', v_paid,
    'per_session_value', v_unit
  );

  update public.customers
     set memberships = coalesce(memberships, '[]'::jsonb) || jsonb_build_array(v_member)
   where id = p_customer_id;

  update public.program_quotes
     set customer_id = p_customer_id,
         status = 'accepted',
         accepted_at = now()
   where id = p_quote_id
  returning to_jsonb(program_quotes.*) into v_chosen;

  return v_chosen;
end $$;

grant execute on function public.accept_program_quote(uuid, uuid) to authenticated;
grant execute on function public.program_shop_is_director(uuid) to authenticated;

comment on function public.accept_program_quote(uuid, uuid) is
  'PRD v7.1 — 견적 스냅샷을 고객 memberships jsonb 로 닫는다. 패키지 정가는 불변.';

notify pgrst, 'reload schema';
