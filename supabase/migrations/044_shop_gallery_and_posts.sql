-- 044: 샵 갤러리(최대 20) + 샵 소식 쓰레드(shop_posts)

create table if not exists public.shop_gallery_items (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  image_url text not null,
  title text not null default '',
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_shop_gallery_items_shop
  on public.shop_gallery_items (shop_id, sort_order asc, created_at desc);

comment on table public.shop_gallery_items is
  '샵 홈 갤러리 미디어 (최대 20장/샵).';

create or replace function public.enforce_shop_gallery_limit()
returns trigger
language plpgsql
as $$
declare
  v_count int;
begin
  select count(*) into v_count
  from public.shop_gallery_items
  where shop_id = new.shop_id;
  if v_count >= 20 then
    raise exception '샵 갤러리는 최대 20장까지 등록할 수 있습니다.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_shop_gallery_limit on public.shop_gallery_items;
create trigger trg_shop_gallery_limit
  before insert on public.shop_gallery_items
  for each row execute function public.enforce_shop_gallery_limit();

alter table public.shop_gallery_items enable row level security;

drop policy if exists "mvp_shop_gallery_select" on public.shop_gallery_items;
drop policy if exists "mvp_shop_gallery_insert" on public.shop_gallery_items;
drop policy if exists "mvp_shop_gallery_update" on public.shop_gallery_items;
drop policy if exists "mvp_shop_gallery_delete" on public.shop_gallery_items;
create policy "mvp_shop_gallery_select"
  on public.shop_gallery_items for select using (true);
create policy "mvp_shop_gallery_insert"
  on public.shop_gallery_items for insert with check (true);
create policy "mvp_shop_gallery_update"
  on public.shop_gallery_items for update using (true);
create policy "mvp_shop_gallery_delete"
  on public.shop_gallery_items for delete using (true);

-- 샵 전용 마이크로 블로그
create table if not exists public.shop_posts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  author_user_id uuid references public.profiles (id) on delete set null,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  image_urls text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_shop_posts_shop
  on public.shop_posts (shop_id, created_at desc);

comment on table public.shop_posts is
  '샵 Home 최근 소식 쓰레드 (텍스트 + 선택 이미지).';

alter table public.shop_posts enable row level security;

drop policy if exists "mvp_shop_posts_select" on public.shop_posts;
drop policy if exists "mvp_shop_posts_insert" on public.shop_posts;
drop policy if exists "mvp_shop_posts_update" on public.shop_posts;
drop policy if exists "mvp_shop_posts_delete" on public.shop_posts;
create policy "mvp_shop_posts_select"
  on public.shop_posts for select using (true);
create policy "mvp_shop_posts_insert"
  on public.shop_posts for insert with check (true);
create policy "mvp_shop_posts_update"
  on public.shop_posts for update using (true);
create policy "mvp_shop_posts_delete"
  on public.shop_posts for delete using (true);
