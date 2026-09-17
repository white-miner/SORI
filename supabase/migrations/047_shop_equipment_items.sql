-- 047: shops.equipment_items (기기/제품 카드 + 선택 이미지)

alter table public.shops
  add column if not exists equipment_items jsonb not null default '[]'::jsonb;

comment on column public.shops.equipment_items is
  '사용 기기/제품 카드 [{id, name, image_url}] — image_url 없으면 타이포 폴백';
