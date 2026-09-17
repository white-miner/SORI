-- 전자 동의서 컬럼 (앱 Insert/Update와 맞춤). 이미 생성했다면 무시됩니다.
alter table public.customer_charts
  add column if not exists consent_mandatory boolean not null default false,
  add column if not exists consent_photo boolean not null default false,
  add column if not exists consent_marketing boolean not null default false,
  add column if not exists consent_offline_only boolean not null default false,
  add column if not exists signature_url text;

comment on column public.customer_charts.consent_mandatory is
  '[필수] 부작용·시술 주의사항 안내 동의';
comment on column public.customer_charts.consent_photo is
  '[선택] 임상 사진/영상 촬영 동의';
comment on column public.customer_charts.consent_marketing is
  '온라인 마케팅 활용 동의 (사진 동의 하위)';
comment on column public.customer_charts.consent_offline_only is
  '오프라인 상담 전용 (사진 동의 하위)';
comment on column public.customer_charts.signature_url is
  '전자 서명 이미지 URL (Storage). 미서명 시 null';

-- Storage 버킷이 없다면 Dashboard에서 chart-signatures 를 Public으로 생성하세요.
-- (SQL로 버킷을 만들 권한이 있는 환경에서만 아래를 실행)
-- insert into storage.buckets (id, name, public)
-- values ('chart-signatures', 'chart-signatures', true)
-- on conflict (id) do nothing;
