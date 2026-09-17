-- PGRST204 복구: is_case_shared 컬럼 + chart_records 업서트 가능 뷰

-- 1) 앱이 보내는 공유 플래그 컬럼명 통일
alter table public.customer_charts
  add column if not exists is_case_shared boolean not null default false;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'customer_charts'
      and column_name = 'case_shared'
  ) then
    execute $u$
      update public.customer_charts
      set is_case_shared = coalesce(case_shared, false)
      where is_case_shared is distinct from coalesce(case_shared, false)
    $u$;
  end if;
end $$;

comment on column public.customer_charts.is_case_shared is
  '공유된 관리 케이스 피드 노출 여부 (동의서 서명 완료 차트만 앱에서 ON 가능)';

-- 2) chart_records = customer_charts 전체 미러 뷰 (단일 테이블 → 자동 updatable)
drop view if exists public.chart_records cascade;
create view public.chart_records as
  select * from public.customer_charts;

comment on view public.chart_records is
  '원장 차트 기록 업서트용 뷰 (customer_charts 미러)';

grant select, insert, update, delete on public.chart_records to anon, authenticated;

-- 3) 고객 업데이트 가드: is_case_shared 기준으로 재정의
create or replace function public.enforce_chart_update_scope()
returns trigger
language plpgsql
as $$
declare
  is_owner boolean := false;
  is_linked_customer boolean := false;
begin
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
       and new.is_case_shared is not distinct from old.is_case_shared
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

  raise exception 'chart update forbidden for this role'
    using errcode = '42501';
end;
$$;
