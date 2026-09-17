-- 회차 기반 B/A 사진 메타데이터 (chart_records / customer_charts SSOT)
-- 사진은 before_image_url / after_image_url 에 저장되며, visit_number + chart id 로 인덱싱한다.

alter table public.customer_charts
  add column if not exists photo_meta jsonb not null default '{}'::jsonb;

comment on column public.customer_charts.photo_meta is
  '회차 사진 메타: {before:{visit_number,chart_id,kind}, after:{visit_number,chart_id,kind}}';

comment on column public.customer_charts.before_image_url is
  'Before 사진 URL — visit_number / chart id 와 함께 B/A 비교 뷰어에서 인덱싱';

comment on column public.customer_charts.after_image_url is
  'After 사진 URL — visit_number / chart id 와 함께 B/A 비교 뷰어에서 인덱싱';

comment on column public.customer_charts.visit_number is
  '시술 회차 (1회차, 2회차…) — 관리 경과 비교의 기본 인덱스 키';

-- chart_records 뷰가 select * 미러인 경우 photo_meta 자동 포함.
-- 017 이후 뷰가 있으면어졌다면 재생성.
do $$
begin
  if exists (
    select 1 from information_schema.views
    where table_schema = 'public' and table_name = 'chart_records'
  ) then
    execute 'drop view if exists public.chart_records cascade';
    execute 'create view public.chart_records as select * from public.customer_charts';
    execute 'grant select, insert, update, delete on public.chart_records to anon, authenticated';
  end if;
end $$;
