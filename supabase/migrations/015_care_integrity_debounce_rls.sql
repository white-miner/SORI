-- 케어 데이터 무결성: 처방 태그 정규화, 뷰 분리, 고객 차트 수정 가드

-- 1) 가벼운 prescription_tags 컬럼 (ID 배열만). 기존 home_care_prescriptions 와 동기.
alter table public.customer_charts
  add column if not exists prescription_tags jsonb not null default '[]'::jsonb;

update public.customer_charts
set prescription_tags = home_care_prescriptions
where coalesce(jsonb_array_length(prescription_tags), 0) = 0
  and coalesce(jsonb_array_length(home_care_prescriptions), 0) > 0;

comment on column public.customer_charts.prescription_tags is
  '홈케어 처방 태그 ID 배열 (예: tag_water, tag_sun). 본문 텍스트 금지';

-- 2) 논리 분리 뷰 (chart_records / customer_diaries)
create or replace view public.chart_records as
select
  id,
  shop_id,
  customer_id,
  visit_number,
  care_name,
  treatment_summary,
  director_insight,
  prescription_tags,
  home_care_prescriptions,
  guardian_phone,
  info_view_consent,
  home_care_mission_checks,
  visit_checked,
  visit_checked_at,
  created_at,
  updated_at
from public.customer_charts;

create or replace view public.customer_diaries as
select
  id,
  shop_id,
  customer_id,
  note_date,
  body,
  created_at,
  updated_at
from public.care_diary_notes;

comment on view public.chart_records is '원장 차트 기록 논리 뷰 (customer_charts)';
comment on view public.customer_diaries is '고객 다이어리 논리 뷰 (care_diary_notes)';

-- 3) 전화번호 숫자만 남기는 헬퍼
create or replace function public.normalize_phone_digits(raw text)
returns text
language sql
immutable
as $$
  select coalesce(regexp_replace(coalesce(raw, ''), '[^0-9]', '', 'g'), '');
$$;

-- 차트 저장 시 보호자 번호 정규화
create or replace function public.normalize_chart_guardian_phone()
returns trigger
language plpgsql
as $$
begin
  if new.guardian_phone is not null then
    new.guardian_phone := public.normalize_phone_digits(new.guardian_phone);
    if new.guardian_phone = '' then
      new.guardian_phone := null;
    end if;
  end if;
  -- prescription_tags / home_care_prescriptions 상호 동기
  if new.prescription_tags is null then
    new.prescription_tags := '[]'::jsonb;
  end if;
  if new.home_care_prescriptions is null then
    new.home_care_prescriptions := new.prescription_tags;
  elsif jsonb_typeof(new.prescription_tags) = 'array'
        and jsonb_array_length(new.prescription_tags) = 0
        and jsonb_typeof(new.home_care_prescriptions) = 'array'
        and jsonb_array_length(new.home_care_prescriptions) > 0 then
    new.prescription_tags := new.home_care_prescriptions;
  else
    new.home_care_prescriptions := new.prescription_tags;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_normalize_chart_guardian_phone on public.customer_charts;
create trigger trg_normalize_chart_guardian_phone
  before insert or update on public.customer_charts
  for each row execute function public.normalize_chart_guardian_phone();

-- 고객 마스터 전화번호 정규화
create or replace function public.normalize_customer_phone()
returns trigger
language plpgsql
as $$
begin
  new.phone := public.normalize_phone_digits(new.phone);
  return new;
end;
$$;

drop trigger if exists trg_normalize_customer_phone on public.customers;
create trigger trg_normalize_customer_phone
  before insert or update on public.customers
  for each row execute function public.normalize_customer_phone();

-- 4) 고객은 미션 체크만 변경 가능 (원장 필드 오염 차단)
create or replace function public.enforce_chart_update_scope()
returns trigger
language plpgsql
as $$
declare
  is_owner boolean := false;
  is_linked_customer boolean := false;
begin
  -- anon / 서비스 키 경로(레거시 MVP): auth.uid() 없으면 통과
  if auth.uid() is null then
    return new;
  end if;

  select exists (
    select 1 from public.shops s
    where s.id = old.shop_id and s.owner_user_id = auth.uid()
  ) into is_owner;

  if is_owner then
    return new;
  end if;

  select exists (
    select 1 from public.customers c
    where c.id = old.customer_id and c.user_id = auth.uid()
  ) into is_linked_customer;

  if is_linked_customer then
    if new.home_care_mission_checks is distinct from old.home_care_mission_checks
       and new.care_name is not distinct from old.care_name
       and new.treatment_summary is not distinct from old.treatment_summary
       and new.director_insight is not distinct from old.director_insight
       and new.prescription_tags is not distinct from old.prescription_tags
       and new.home_care_prescriptions is not distinct from old.home_care_prescriptions
       and new.guardian_phone is not distinct from old.guardian_phone
       and new.info_view_consent is not distinct from old.info_view_consent
       and new.concern_chips is not distinct from old.concern_chips
       and new.before_image_url is not distinct from old.before_image_url
       and new.after_image_url is not distinct from old.after_image_url
       and new.allergy_notes is not distinct from old.allergy_notes
       and new.skin_sensitivity is not distinct from old.skin_sensitivity
       and new.side_effect_history is not distinct from old.side_effect_history
       and new.customer_requests is not distinct from old.customer_requests
       and new.consent_mandatory is not distinct from old.consent_mandatory
       and new.consent_photo is not distinct from old.consent_photo
       and new.consent_marketing is not distinct from old.consent_marketing
       and new.consent_offline_only is not distinct from old.consent_offline_only
       and new.signature_url is not distinct from old.signature_url
       and new.case_shared is not distinct from old.case_shared
       and new.visit_checked is not distinct from old.visit_checked
       and new.visit_number is not distinct from old.visit_number
       and new.customer_id is not distinct from old.customer_id
       and new.shop_id is not distinct from old.shop_id
    then
      new.updated_at := now();
      return new;
    end if;
    raise exception 'customers may only update home_care_mission_checks'
      using errcode = '42501';
  end if;

  -- 그 외 인증 사용자는 차트 수정 불가
  raise exception 'chart update forbidden for this role'
    using errcode = '42501';
end;
$$;

drop trigger if exists trg_enforce_chart_update_scope on public.customer_charts;
create trigger trg_enforce_chart_update_scope
  before update on public.customer_charts
  for each row execute function public.enforce_chart_update_scope();

-- 5) 고객 전용 미션 패치 RPC (멱등·좁은 쓰기면)
create or replace function public.patch_home_care_mission_checks(
  p_chart_id uuid,
  p_checks jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  cid uuid;
begin
  select customer_id into cid from public.customer_charts where id = p_chart_id;
  if cid is null then
    raise exception 'chart not found';
  end if;

  -- 소유 원장 또는 해당 고객(또는 anon MVP)만
  if auth.uid() is not null then
    if not exists (
      select 1 from public.shops s
      join public.customer_charts ch on ch.shop_id = s.id
      where ch.id = p_chart_id and s.owner_user_id = auth.uid()
    ) and not exists (
      select 1 from public.customers c
      where c.id = cid and c.user_id = auth.uid()
    ) then
      raise exception 'forbidden' using errcode = '42501';
    end if;
  end if;

  update public.customer_charts
  set
    home_care_mission_checks = coalesce(p_checks, '[false,false,false]'::jsonb),
    updated_at = now()
  where id = p_chart_id;
end;
$$;

grant execute on function public.patch_home_care_mission_checks(uuid, jsonb) to anon, authenticated;
