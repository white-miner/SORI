-- P1 Expand: photo_sets + chart_photo_records
-- URL 컬럼(before_image_url / after_image_url / photo_meta)은 건드리지 않는다.
-- 읽기는 구형 URL 컬럼 유지. 이 테이블은 쓰기 이중화만.

create table if not exists public.photo_sets (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  customer_id uuid not null,
  label text not null,
  pose_template jsonb,
  created_at timestamptz default now()
);

create table if not exists public.chart_photo_records (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.customer_charts(id) on delete cascade,
  shop_id uuid,
  photo_set_id uuid references public.photo_sets(id),
  phase text not null check (phase in ('before', 'progress', 'after')),
  url text not null,
  pose_keypoints jsonb,
  ref_photo_id uuid references public.chart_photo_records(id),
  sort_order int default 0,
  created_at timestamptz default now()
);

create index if not exists chart_photo_records_chart_phase_sort_idx
  on public.chart_photo_records (chart_id, phase, sort_order);

-- 멱등: 같은 차트·phase·URL 은 한 행만
create unique index if not exists chart_photo_record_dedupe
  on public.chart_photo_records (chart_id, phase, url);

alter table public.photo_sets enable row level security;
alter table public.chart_photo_records enable row level security;

-- RLS: customer_charts 의 mvp_charts_* 와 동일 형태 (TO 생략 = PUBLIC)
-- update / delete 정책은 만들지 않는다.
drop policy if exists "photo_sets_authenticated_select" on public.photo_sets;
drop policy if exists "photo_sets_authenticated_insert" on public.photo_sets;
drop policy if exists "mvp_photo_sets_select" on public.photo_sets;
drop policy if exists "mvp_photo_sets_insert" on public.photo_sets;
create policy "mvp_photo_sets_select" on public.photo_sets for select using (true);
create policy "mvp_photo_sets_insert" on public.photo_sets for insert with check (true);

drop policy if exists "chart_photo_records_authenticated_select" on public.chart_photo_records;
drop policy if exists "chart_photo_records_authenticated_insert" on public.chart_photo_records;
drop policy if exists "mvp_chart_photo_records_select" on public.chart_photo_records;
drop policy if exists "mvp_chart_photo_records_insert" on public.chart_photo_records;
create policy "mvp_chart_photo_records_select"
  on public.chart_photo_records for select using (true);
create policy "mvp_chart_photo_records_insert"
  on public.chart_photo_records for insert with check (true);

notify pgrst, 'reload schema';
