-- 049: B2B Community posts (인테리어 쇼룸 / 기기 리뷰 / 중고) + 수동 사업자 인증
-- shop_posts(B2C) 와 병행. Affiliate 클릭/정산은 Phase 3.

-- ─── partners & verification ───────────────────────────────────────────────
create table if not exists public.b2b_partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  partner_type text not null default 'interior_vendor'
    check (partner_type in (
      'interior_vendor', 'device_brand', 'distributor', 'freelancer', 'other'
    )),
  business_no text,
  verification_status text not null default 'none'
    check (verification_status in (
      'none', 'business_verified', 'sori_partner'
    )),
  contact_phone text,
  contact_url text,
  profile_image_url text,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.b2b_partners is
  'B2B 제휴/인테리어/기기 업체 마스터 — Admin 수동 검증.';

create table if not exists public.shop_verifications (
  shop_id uuid primary key references public.shops (id) on delete cascade,
  business_reg_no text,
  status text not null default 'none'
    check (status in ('none', 'pending', 'business_verified', 'rejected')),
  verified_at timestamptz,
  verified_by text,
  notes text not null default '',
  updated_at timestamptz not null default now()
);

comment on table public.shop_verifications is
  '샵 사업자 인증 — Admin 수동 상태 변경 (외부 API 없음).';

-- ─── community posts ───────────────────────────────────────────────────
create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  author_user_id uuid references public.profiles (id) on delete set null,
  post_type text not null default 'interior'
    check (post_type in (
      'interior', 'device_review', 'marketplace', 'case_share', 'seminar'
    )),
  title text not null default '',
  body text not null default '',
  style_tags text[] not null default '{}',
  region_code text,
  visibility text not null default 'public'
    check (visibility in ('public', 'directors_only', 'region_only')),
  status text not null default 'published'
    check (status in ('draft', 'published', 'hidden', 'removed')),
  like_count int not null default 0,
  comment_count int not null default 0,
  save_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_community_posts_type_created
  on public.community_posts (post_type, created_at desc)
  where status = 'published';

create index if not exists idx_community_posts_shop
  on public.community_posts (shop_id, created_at desc);

comment on table public.community_posts is
  'B2B Community 광장 포스트 (인테리어/기기리뷰/중고). shop_posts 와 병행.';

create table if not exists public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts (id) on delete cascade,
  image_url text not null,
  sort_order int not null default 0,
  width int,
  height int,
  blurhash text,
  created_at timestamptz not null default now()
);

create index if not exists idx_post_media_post
  on public.post_media (post_id, sort_order asc);

comment on table public.post_media is
  'Community 포스트 다중 이미지.';

-- 핫스팟 / 태그 (Phase 1: external_url 링크아웃만, affiliate 추적은 Phase 3)
create table if not exists public.post_tags (
  id uuid primary key default gen_random_uuid(),
  media_id uuid not null references public.post_media (id) on delete cascade,
  tag_kind text not null default 'product'
    check (tag_kind in (
      'product', 'vendor', 'construction_zone', 'external_link'
    )),
  label text not null default '',
  norm_x double precision not null default 0.5
    check (norm_x >= 0 and norm_x <= 1),
  norm_y double precision not null default 0.5
    check (norm_y >= 0 and norm_y <= 1),
  norm_w double precision,
  norm_h double precision,
  partner_id uuid references public.b2b_partners (id) on delete set null,
  external_url text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_post_tags_media
  on public.post_tags (media_id);

comment on table public.post_tags is
  '인테리어 핫스팟 태그. Phase 1은 external_url 링크아웃만.';

-- ─── device review + marketplace (Phase 1: 연락/채팅) ──────────────────
create table if not exists public.device_reviews (
  post_id uuid primary key
    references public.community_posts (id) on delete cascade,
  device_name text not null default '',
  brand text not null default '',
  model text not null default '',
  device_category text not null default '',
  usage_months int not null default 0,
  sessions_per_week int not null default 0,
  rating numeric(2,1) check (rating is null or (rating >= 1 and rating <= 5)),
  pros text[] not null default '{}',
  cons text[] not null default '{}',
  would_recommend boolean,
  created_at timestamptz not null default now()
);

comment on table public.device_reviews is
  '기기 실사용 리뷰 구조화 필드 (community_posts 1:1).';

create table if not exists public.market_listings (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null unique
    references public.community_posts (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  device_name text not null default '',
  brand text not null default '',
  model text not null default '',
  price int not null default 0,
  currency text not null default 'KRW',
  condition text not null default 'good'
    check (condition in ('new', 'like_new', 'good', 'fair')),
  listing_status text not null default 'active'
    check (listing_status in (
      'draft', 'active', 'reserved', 'sold', 'hidden', 'removed'
    )),
  contact_phone text,
  contact_note text not null default '',
  region text,
  sold_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_market_listings_status
  on public.market_listings (listing_status, created_at desc);

comment on table public.market_listings is
  '중고 거래 — Phase 1 연락처/채팅 연결 (에스크로 없음).';

create table if not exists public.listing_inquiries (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null
    references public.market_listings (id) on delete cascade,
  buyer_shop_id uuid references public.shops (id) on delete set null,
  buyer_user_id uuid references public.profiles (id) on delete set null,
  message text not null,
  status text not null default 'open'
    check (status in ('open', 'closed')),
  created_at timestamptz not null default now()
);

create index if not exists idx_listing_inquiries_listing
  on public.listing_inquiries (listing_id, created_at desc);

comment on table public.listing_inquiries is
  '중고 문의 메시지 (앱 내 가벼운 채팅 시드).';

-- ─── RLS (MVP open, 기존 shops 정책 패턴) ────────────────────────────────
alter table public.b2b_partners enable row level security;
alter table public.shop_verifications enable row level security;
alter table public.community_posts enable row level security;
alter table public.post_media enable row level security;
alter table public.post_tags enable row level security;
alter table public.device_reviews enable row level security;
alter table public.market_listings enable row level security;
alter table public.listing_inquiries enable row level security;

drop policy if exists "mvp_b2b_partners_select" on public.b2b_partners;
drop policy if exists "mvp_b2b_partners_write" on public.b2b_partners;
create policy "mvp_b2b_partners_select"
  on public.b2b_partners for select using (true);
create policy "mvp_b2b_partners_write"
  on public.b2b_partners for all using (true) with check (true);

drop policy if exists "mvp_shop_verifications_select" on public.shop_verifications;
drop policy if exists "mvp_shop_verifications_write" on public.shop_verifications;
create policy "mvp_shop_verifications_select"
  on public.shop_verifications for select using (true);
create policy "mvp_shop_verifications_write"
  on public.shop_verifications for all using (true) with check (true);

drop policy if exists "mvp_community_posts_select" on public.community_posts;
drop policy if exists "mvp_community_posts_insert" on public.community_posts;
drop policy if exists "mvp_community_posts_update" on public.community_posts;
drop policy if exists "mvp_community_posts_delete" on public.community_posts;
create policy "mvp_community_posts_select"
  on public.community_posts for select using (true);
create policy "mvp_community_posts_insert"
  on public.community_posts for insert with check (true);
create policy "mvp_community_posts_update"
  on public.community_posts for update using (true);
create policy "mvp_community_posts_delete"
  on public.community_posts for delete using (true);

drop policy if exists "mvp_post_media_all" on public.post_media;
create policy "mvp_post_media_all"
  on public.post_media for all using (true) with check (true);

drop policy if exists "mvp_post_tags_all" on public.post_tags;
create policy "mvp_post_tags_all"
  on public.post_tags for all using (true) with check (true);

drop policy if exists "mvp_device_reviews_all" on public.device_reviews;
create policy "mvp_device_reviews_all"
  on public.device_reviews for all using (true) with check (true);

drop policy if exists "mvp_market_listings_all" on public.market_listings;
create policy "mvp_market_listings_all"
  on public.market_listings for all using (true) with check (true);

drop policy if exists "mvp_listing_inquiries_all" on public.listing_inquiries;
create policy "mvp_listing_inquiries_all"
  on public.listing_inquiries for all using (true) with check (true);
