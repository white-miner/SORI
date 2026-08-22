-- 046: shops.business_hours JSON (요일 + 오픈/마감)

alter table public.shops
  add column if not exists business_hours jsonb not null default '{}'::jsonb;

comment on column public.shops.business_hours is
  '영업시간 JSON: { open_days: [1..7], open_time: "HH:mm", close_time: "HH:mm" } — 1=월 … 7=일';
