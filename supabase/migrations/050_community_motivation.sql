-- 050: Community motivation — activity score, gold_plus visibility, tier hooks

-- ─── shop community activity (feeds My Page tier progress) ─────────────
alter table public.shops
  add column if not exists community_activity_score int not null default 0;

comment on column public.shops.community_activity_score is
  'Community/shop_posts 작성 누적. 티어 프로그레스 shared/likes 가산.';

-- ─── visibility: gold+ lock (Give & Take) ─────────────────────────────
alter table public.community_posts
  drop constraint if exists community_posts_visibility_check;

alter table public.community_posts
  add constraint community_posts_visibility_check
  check (visibility in (
    'public', 'directors_only', 'region_only', 'gold_plus'
  ));

comment on column public.community_posts.visibility is
  'public | directors_only | region_only | gold_plus(골드 이상)';

-- ─── bump activity on community publish ────────────────────────────────
create or replace function public.bump_shop_community_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'community_posts' then
    if new.status = 'published' and new.shop_id is not null then
      update public.shops
      set community_activity_score = coalesce(community_activity_score, 0) + 1,
          updated_at = now()
      where id = new.shop_id;
    end if;
  elsif tg_table_name = 'shop_posts' then
    if new.shop_id is not null then
      update public.shops
      set community_activity_score = coalesce(community_activity_score, 0) + 1,
          updated_at = now()
      where id = new.shop_id;
    end if;
  elsif tg_table_name = 'device_reviews' then
    -- device_reviews are 1:1 with community_posts; extra +1 for structured review effort
    update public.shops s
    set community_activity_score = coalesce(s.community_activity_score, 0) + 1,
        updated_at = now()
    from public.community_posts p
    where p.id = new.post_id and s.id = p.shop_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_bump_activity_community_posts on public.community_posts;
create trigger trg_bump_activity_community_posts
  after insert on public.community_posts
  for each row execute function public.bump_shop_community_activity();

drop trigger if exists trg_bump_activity_shop_posts on public.shop_posts;
create trigger trg_bump_activity_shop_posts
  after insert on public.shop_posts
  for each row execute function public.bump_shop_community_activity();

drop trigger if exists trg_bump_activity_device_reviews on public.device_reviews;
create trigger trg_bump_activity_device_reviews
  after insert on public.device_reviews
  for each row execute function public.bump_shop_community_activity();
