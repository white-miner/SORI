-- 차트 Before/After 사진용 Public Storage 버킷
-- Dashboard에서도 chart_photos 버킷을 Public으로 생성 가능합니다.

insert into storage.buckets (id, name, public)
values ('chart_photos', 'chart_photos', true)
on conflict (id) do update set public = excluded.public;

-- 인증된 원장: 업로드/갱신/삭제 허용 (경로 자유 — 앱에서 shop/customer 세그먼트 사용)
drop policy if exists "chart_photos_authenticated_insert" on storage.objects;
create policy "chart_photos_authenticated_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'chart_photos');

drop policy if exists "chart_photos_authenticated_update" on storage.objects;
create policy "chart_photos_authenticated_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'chart_photos')
  with check (bucket_id = 'chart_photos');

drop policy if exists "chart_photos_authenticated_delete" on storage.objects;
create policy "chart_photos_authenticated_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'chart_photos');

-- Public 읽기 (B/A 뷰어·고객 앱)
drop policy if exists "chart_photos_public_select" on storage.objects;
create policy "chart_photos_public_select"
  on storage.objects for select
  to public
  using (bucket_id = 'chart_photos');
