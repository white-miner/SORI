-- 045: shop_posts 세미나 크로스포스트 필드

alter table public.shop_posts
  add column if not exists post_kind text not null default 'note';

alter table public.shop_posts
  add column if not exists seminar_class_id uuid
    references public.seminar_classes (id) on delete set null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'shop_posts_post_kind_check'
  ) then
    alter table public.shop_posts
      add constraint shop_posts_post_kind_check
      check (post_kind in ('note', 'seminar', 'notice'));
  end if;
exception when others then
  raise notice 'shop_posts_post_kind_check skipped: %', sqlerrm;
end $$;

create index if not exists idx_shop_posts_seminar
  on public.shop_posts (seminar_class_id)
  where seminar_class_id is not null;

comment on column public.shop_posts.post_kind is
  'note | seminar | notice — Home 쓰레드 렌더 분기';
comment on column public.shop_posts.seminar_class_id is
  '세미나 개설 크로스포스트 연결';
