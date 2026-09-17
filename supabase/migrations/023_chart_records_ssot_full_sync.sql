-- =============================================================================
-- 023: chart_records SSOT 전수 동기화 (PGRST204 일괄 종결)
-- =============================================================================
-- 앱 CustomerChart.toDbWriteMap() 이 보내는 모든 키를 customer_charts(물리)에
-- 보장한 뒤, chart_records 를 항상 `select *` 업서트 가능 미러 뷰로 재생성한다.
--
-- 프론트엔드 payload keys (SSOT):
--   id, shop_id, customer_id, visit_number, custom_chart_no,
--   visit_checked, visit_checked_at,
--   before_image_url, after_image_url, photo_meta,
--   care_name, treatment_summary, director_insight,
--   allergy_notes, skin_sensitivity, side_effect_history, customer_requests,
--   concern_chips, first_visit_fear_chips, revisit_feedback_chips,
--   feedback_token, feedback_line_opened_at,
--   consent_mandatory, consent_photo, consent_marketing, consent_offline_only,
--   signature_url, consent_pdf_url, is_case_shared,
--   prescription_tags, home_care_prescriptions,
--   guardian_phone, info_view_consent, home_care_mission_checks,
--   updated_at
--   (+ 서버 기본: created_at)
-- =============================================================================

-- 1) 물리 테이블 SSOT = customer_charts (FK·트리거 유지)
alter table public.customer_charts
  add column if not exists custom_chart_no text,
  add column if not exists care_name text default '',
  add column if not exists treatment_summary text default '',
  add column if not exists director_insight text default '',
  add column if not exists before_image_url text,
  add column if not exists after_image_url text,
  add column if not exists photo_meta jsonb not null default '{}'::jsonb,
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
  add column if not exists consent_mandatory boolean not null default false,
  add column if not exists consent_photo boolean not null default false,
  add column if not exists consent_marketing boolean not null default false,
  add column if not exists consent_offline_only boolean not null default false,
  add column if not exists signature_url text,
  add column if not exists consent_pdf_url text,
  add column if not exists is_case_shared boolean not null default false,
  add column if not exists case_shared boolean not null default false,
  add column if not exists prescription_tags jsonb not null default '[]'::jsonb,
  add column if not exists home_care_prescriptions jsonb not null default '[]'::jsonb,
  add column if not exists guardian_phone text,
  add column if not exists info_view_consent boolean not null default false,
  add column if not exists home_care_mission_checks jsonb not null default '[false,false,false]'::jsonb,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- 레거시 case_shared → is_case_shared 미러
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'customer_charts'
      and column_name = 'case_shared'
  ) then
    update public.customer_charts
    set is_case_shared = coalesce(is_case_shared, false)
                       or coalesce(case_shared, false);
  end if;
end $$;

-- 텍스트 기본값 정리
alter table public.customer_charts
  alter column care_name set default '',
  alter column treatment_summary set default '',
  alter column director_insight set default '',
  alter column allergy_notes set default '',
  alter column skin_sensitivity set default '',
  alter column side_effect_history set default '',
  alter column customer_requests set default '';

comment on column public.customer_charts.care_name is
  '진행 서비스/케어명 (회원권 차감 매칭 키)';
comment on column public.customer_charts.consent_pdf_url is
  '전자 동의서 PDF public URL (consent_pdfs 버킷)';
comment on column public.customer_charts.photo_meta is
  'B/A 사진 메타 {before, after}';
comment on column public.customer_charts.is_case_shared is
  '관리 케이스 공개 공유 플래그 (앱 전송 키)';

-- 2) chart_records 앱 대면 SSOT 재구성
--    - VIEW 이면 drop 후 select * 미러 재생성
--    - BASE TABLE 이면 동일 컬럼을 보강한 뒤, 앱은 계속 chart_records 사용
--      (이중 저장 방지: 테이블이면 customer_charts 와 별개일 수 있어 컬럼만 맞춤)
do $$
declare
  relkind "char";
begin
  select c.relkind into relkind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'chart_records';

  if relkind = 'r' then
    -- chart_records 가 물리 테이블인 환경: 동일 컬럼 전수 추가
    execute $sql$
      alter table public.chart_records
        add column if not exists custom_chart_no text,
        add column if not exists care_name text default '',
        add column if not exists treatment_summary text default '',
        add column if not exists director_insight text default '',
        add column if not exists before_image_url text,
        add column if not exists after_image_url text,
        add column if not exists photo_meta jsonb not null default '{}'::jsonb,
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
        add column if not exists consent_mandatory boolean not null default false,
        add column if not exists consent_photo boolean not null default false,
        add column if not exists consent_marketing boolean not null default false,
        add column if not exists consent_offline_only boolean not null default false,
        add column if not exists signature_url text,
        add column if not exists consent_pdf_url text,
        add column if not exists is_case_shared boolean not null default false,
        add column if not exists case_shared boolean not null default false,
        add column if not exists prescription_tags jsonb not null default '[]'::jsonb,
        add column if not exists home_care_prescriptions jsonb not null default '[]'::jsonb,
        add column if not exists guardian_phone text,
        add column if not exists info_view_consent boolean not null default false,
        add column if not exists home_care_mission_checks jsonb not null default '[false,false,false]'::jsonb,
        add column if not exists created_at timestamptz not null default now(),
        add column if not exists updated_at timestamptz not null default now()
    $sql$;
    raise notice 'chart_records is BASE TABLE — columns synced in place';
  else
    -- VIEW / 없음 → customer_charts 전체 미러로 통일 (권장 SSOT)
    execute 'drop view if exists public.chart_records cascade';
    execute 'create view public.chart_records as select * from public.customer_charts';
    execute 'comment on view public.chart_records is ''앱 차트 SSOT — customer_charts 전체 미러(업서트 가능)''';
    execute 'grant select, insert, update, delete on public.chart_records to anon, authenticated, service_role';
    raise notice 'chart_records view recreated as select * from customer_charts';
  end if;
end $$;

-- 3) PostgREST 스키마 캐시 강제 갱신 (PGRST204 즉시 해소)
notify pgrst, 'reload schema';
