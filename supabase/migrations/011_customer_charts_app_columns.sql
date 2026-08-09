-- 앱 Insert/Update가 쓰는 customer_charts 컬럼을 한 번에 보장합니다.
-- Supabase SQL Editor에 그대로 실행해도 안전합니다 (IF NOT EXISTS).

alter table public.customer_charts
  add column if not exists custom_chart_no text,
  add column if not exists care_name text default '',
  add column if not exists treatment_summary text,
  add column if not exists director_insight text,
  add column if not exists before_image_url text,
  add column if not exists after_image_url text,
  add column if not exists allergy_notes text default '',
  add column if not exists skin_sensitivity text default '',
  add column if not exists side_effect_history text default '',
  add column if not exists customer_requests text default '',
  add column if not exists concern_chips jsonb not null default '[]'::jsonb,
  add column if not exists first_visit_fear_chips jsonb not null default '[]'::jsonb,
  add column if not exists revisit_feedback_chips jsonb not null default '[]'::jsonb,
  add column if not exists visit_checked boolean not null default false,
  add column if not exists visit_checked_at timestamptz,
  add column if not exists feedback_token text,
  add column if not exists feedback_line_opened_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

-- 빈 값 저장을 허용하도록 nullable text 컬럼 기본값 정리 (이미 있으면 환경 호환)
alter table public.customer_charts
  alter column allergy_notes set default '',
  alter column skin_sensitivity set default '',
  alter column side_effect_history set default '',
  alter column customer_requests set default '',
  alter column care_name set default '';

comment on column public.customer_charts.allergy_notes is
  '메디컬 체크 알레르기 (칩 다중선택 병합 문자열)';
comment on column public.customer_charts.skin_sensitivity is
  '메디컬 체크 피부 민감도 (칩 다중선택 병합 문자열)';
comment on column public.customer_charts.side_effect_history is
  '메디컬 체크 부작용 이력 (칩 다중선택 병합 문자열)';
comment on column public.customer_charts.director_insight is
  '원장/AI 인사이트 텍스트';
comment on column public.customer_charts.treatment_summary is
  '시술 요약 텍스트';
