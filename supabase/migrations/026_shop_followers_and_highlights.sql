-- 026: 팬덤 커뮤니티 — 단골 팔로워 · 스토리 하이라이트
-- 기존 shops / customers / charts 데이터를 변경하지 않는 독립 테이블

create table if not exists public.shop_followers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (shop_id, customer_id)
);

create index if not exists idx_shop_followers_shop
  on public.shop_followers (shop_id, created_at desc);
create index if not exists idx_shop_followers_customer
  on public.shop_followers (customer_id, created_at desc);

comment on table public.shop_followers is
  '고객→샵 단골 팬(팔로우) 관계. 기존 CRM 테이블과 독립.';

create table if not exists public.shop_highlights (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  title text not null,
  cover_image_url text,
  created_at timestamptz not null default now()
);

create index if not exists idx_shop_highlights_shop
  on public.shop_highlights (shop_id, created_at desc);

comment on table public.shop_highlights is
  '샵 스토리 하이라이트 링 (Instagram 스타일). 기존 갤러리와 독립.';

alter table public.shop_followers enable row level security;
alter table public.shop_highlights enable row level security;

drop policy if exists "mvp_shop_followers_select" on public.shop_followers;
drop policy if exists "mvp_shop_followers_insert" on public.shop_followers;
drop policy if exists "mvp_shop_followers_delete" on public.shop_followers;
create policy "mvp_shop_followers_select"
  on public.shop_followers for select using (true);
create policy "mvp_shop_followers_insert"
  on public.shop_followers for insert with check (true);
create policy "mvp_shop_followers_delete"
  on public.shop_followers for delete using (true);

drop policy if exists "mvp_shop_highlights_select" on public.shop_highlights;
drop policy if exists "mvp_shop_highlights_insert" on public.shop_highlights;
drop policy if exists "mvp_shop_highlights_update" on public.shop_highlights;
drop policy if exists "mvp_shop_highlights_delete" on public.shop_highlights;
create policy "mvp_shop_highlights_select"
  on public.shop_highlights for select using (true);
create policy "mvp_shop_highlights_insert"
  on public.shop_highlights for insert with check (true);
create policy "mvp_shop_highlights_update"
  on public.shop_highlights for update using (true);
create policy "mvp_shop_highlights_delete"
  on public.shop_highlights for delete using (true);
