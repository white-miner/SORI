-- 048: 마이페이지 Hero 간판 이미지 (아바타 profile_image_url 과 분리)

alter table public.shops
  add column if not exists cover_image_url text;

comment on column public.shops.cover_image_url is
  '마이페이지 Hero 간판 이미지 public URL (storage shop_profiles)';
