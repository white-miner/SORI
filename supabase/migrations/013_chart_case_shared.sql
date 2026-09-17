-- 관리 케이스 공개 공유 플래그 (동의 서명 완료 차트만 true 허용 — 앱에서 강제)
alter table public.customer_charts
  add column if not exists case_shared boolean not null default false;

comment on column public.customer_charts.case_shared is
  '공유된 관리 케이스 피드 노출 여부 (동의서 서명 완료 차트만 앱에서 ON 가능)';
