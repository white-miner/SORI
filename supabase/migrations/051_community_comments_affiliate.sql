-- 051: Community comments SSOT + chart case_share bridge + Affiliate ledger

-- ─── chart → community bridge ──────────────────────────────────────────
alter table public.community_posts
  add column if not exists source_chart_id uuid
    references public.customer_charts (id) on delete set null;

create index if not exists idx_community_posts_source_chart
  on public.community_posts (source_chart_id)
  where source_chart_id is not null;

comment on column public.community_posts.source_chart_id is
  '원클릭 퍼블리시 출처 차트 (개인정보 마스킹된 case_share).';

-- ─── community comments (계층형) ───────────────────────────────────────
create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null
    references public.community_posts (id) on delete cascade,
  author_user_id uuid references public.profiles (id) on delete set null,
  author_shop_id uuid references public.shops (id) on delete set null,
  parent_id uuid references public.community_comments (id) on delete cascade,
  content text not null,
  status text not null default 'published'
    check (status in ('published', 'hidden', 'removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_community_comments_post
  on public.community_comments (post_id, created_at asc);

create index if not exists idx_community_comments_parent
  on public.community_comments (parent_id)
  where parent_id is not null;

comment on table public.community_comments is
  'Community 댓글 SSOT — 계층형(parent_id). 로컬 메모리 댓글 대체.';

alter table public.community_comments enable row level security;
drop policy if exists "mvp_community_comments_all" on public.community_comments;
create policy "mvp_community_comments_all"
  on public.community_comments for all using (true) with check (true);

-- keep comment_count roughly in sync
create or replace function public.bump_community_post_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status = 'published' then
    update public.community_posts
    set comment_count = coalesce(comment_count, 0) + 1,
        updated_at = now()
    where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update public.community_posts
    set comment_count = greatest(coalesce(comment_count, 0) - 1, 0),
        updated_at = now()
    where id = old.post_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_bump_community_comment_count on public.community_comments;
create trigger trg_bump_community_comment_count
  after insert or delete on public.community_comments
  for each row execute function public.bump_community_post_comment_count();

-- ─── Affiliate Phase 3 ─────────────────────────────────────────────────
create table if not exists public.affiliate_links (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  partner_id uuid references public.b2b_partners (id) on delete set null,
  post_id uuid references public.community_posts (id) on delete set null,
  post_tag_id uuid references public.post_tags (id) on delete set null,
  destination_url text not null,
  label text not null default '',
  commission_per_click int not null default 500,
  status text not null default 'active'
    check (status in ('active', 'paused', 'removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_affiliate_links_shop
  on public.affiliate_links (shop_id, status);

create unique index if not exists uq_affiliate_links_shop_url
  on public.affiliate_links (shop_id, destination_url);

comment on table public.affiliate_links is
  '원장 제휴 딥링크 — 핫스팟/리뷰 외부 URL 트래킹 대상.';

create table if not exists public.affiliate_clicks (
  id uuid primary key default gen_random_uuid(),
  link_id uuid not null
    references public.affiliate_links (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  clicked_by_user_id uuid references public.profiles (id) on delete set null,
  clicked_by_shop_id uuid references public.shops (id) on delete set null,
  referrer text not null default 'community',
  created_at timestamptz not null default now()
);

create index if not exists idx_affiliate_clicks_shop_created
  on public.affiliate_clicks (shop_id, created_at desc);

create index if not exists idx_affiliate_clicks_link
  on public.affiliate_clicks (link_id, created_at desc);

comment on table public.affiliate_clicks is
  '제휴 링크 클릭 이벤트 로그.';

create table if not exists public.affiliate_commissions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  link_id uuid not null
    references public.affiliate_links (id) on delete cascade,
  click_id uuid
    references public.affiliate_clicks (id) on delete set null,
  amount int not null default 0,
  currency text not null default 'KRW',
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'paid', 'void')),
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_affiliate_commissions_shop
  on public.affiliate_commissions (shop_id, status, created_at desc);

comment on table public.affiliate_commissions is
  '클릭 기반 예상/확정 수수료 원장.';

alter table public.affiliate_links enable row level security;
alter table public.affiliate_clicks enable row level security;
alter table public.affiliate_commissions enable row level security;

drop policy if exists "mvp_affiliate_links_all" on public.affiliate_links;
create policy "mvp_affiliate_links_all"
  on public.affiliate_links for all using (true) with check (true);

drop policy if exists "mvp_affiliate_clicks_all" on public.affiliate_clicks;
create policy "mvp_affiliate_clicks_all"
  on public.affiliate_clicks for all using (true) with check (true);

drop policy if exists "mvp_affiliate_commissions_all" on public.affiliate_commissions;
create policy "mvp_affiliate_commissions_all"
  on public.affiliate_commissions for all using (true) with check (true);
