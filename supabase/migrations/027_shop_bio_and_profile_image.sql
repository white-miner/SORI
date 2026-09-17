-- 027: 샵 프로필 Bio · 프로필 이미지 + Storage 버킷
-- 기존 shops 행을 삭제하지 않고 컬럼만 추가합니다.

alter table public.shops
  add column if not exists bio text not null default '',
  add column if not exists profile_image_url text;

comment on column public.shops.bio is
  '샵 소개말(Bio) — 원장 마이페이지·팬덤 프로필에 노출';
comment on column public.shops.profile_image_url is
  '샵 프로필 아바타 public URL (storage shop_profiles)';

-- Public 버킷: 샵 프로필 사진
insert into storage.buckets (id, name, public)
values ('shop_profiles', 'shop_profiles', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "shop_profiles_authenticated_insert" on storage.objects;
create policy "shop_profiles_authenticated_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'shop_profiles');

drop policy if exists "shop_profiles_authenticated_update" on storage.objects;
create policy "shop_profiles_authenticated_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'shop_profiles')
  with check (bucket_id = 'shop_profiles');

drop policy if exists "shop_profiles_authenticated_delete" on storage.objects;
create policy "shop_profiles_authenticated_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'shop_profiles');

-- MVP anon 업로드도 허용 (웹 익명 키 환경 호환)
drop policy if exists "shop_profiles_anon_insert" on storage.objects;
create policy "shop_profiles_anon_insert"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'shop_profiles');

drop policy if exists "shop_profiles_anon_update" on storage.objects;
create policy "shop_profiles_anon_update"
  on storage.objects for update
  to anon
  using (bucket_id = 'shop_profiles')
  with check (bucket_id = 'shop_profiles');

drop policy if exists "shop_profiles_public_select" on storage.objects;
create policy "shop_profiles_public_select"
  on storage.objects for select
  to public
  using (bucket_id = 'shop_profiles');
