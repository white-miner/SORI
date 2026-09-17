-- 일부 환경에서 customer_charts에 이미지 컬럼이 빠져 저장이 실패할 수 있어 보강합니다.
-- (사진 미첨부 시 앱은 before_image_url / after_image_url 에 null 을 기록합니다.)
alter table public.customer_charts
  add column if not exists before_image_url text,
  add column if not exists after_image_url text;

comment on column public.customer_charts.before_image_url is
  '방문 Before 사진 URL. 미첨부 시 null.';
comment on column public.customer_charts.after_image_url is
  '방문 After 사진 URL. 미첨부 시 null.';
