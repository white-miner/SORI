-- 122: CHART visit flow Expand.
-- ADD nullable only. No drop, rename, or backfill.
-- Does not change ensureTodayShootChart, visit_checked, or URL columns.

alter table public.customers
  add column if not exists referral_source text,
  add column if not exists medical_condition text,
  add column if not exists pregnancy_status text,
  add column if not exists recent_procedure text,
  add column if not exists active_product text,
  add column if not exists skin_trait text,
  add column if not exists safety_note text;

comment on column public.customers.referral_source is
  'How the customer found the shop. Current profile only.';
comment on column public.customers.medical_condition is
  'Current conditions. Not a visit snapshot.';
comment on column public.customers.pregnancy_status is
  'Current pregnancy or nursing status.';
comment on column public.customers.recent_procedure is
  'Current recent-procedure note. Not last_treatment_date.';
comment on column public.customers.active_product is
  'Current functional product. Not home_care_habits.';
comment on column public.customers.skin_trait is
  'Current skin trait such as sensitivity.';
comment on column public.customers.safety_note is
  'Extra current safety note. Not customers.memo.';

alter table public.customer_charts
  add column if not exists chart_flow_status text,
  add column if not exists discomfort_score smallint,
  add column if not exists score_hydration smallint,
  add column if not exists score_oil smallint,
  add column if not exists score_sensitivity smallint,
  add column if not exists score_redness smallint,
  add column if not exists score_keratin smallint,
  add column if not exists score_pores smallint,
  add column if not exists score_pigmentation smallint,
  add column if not exists score_elasticity smallint,
  add column if not exists score_acne smallint,
  add column if not exists visit_intake jsonb,
  add column if not exists safety_snapshot jsonb,
  add column if not exists consult_record jsonb,
  add column if not exists care_goals jsonb,
  add column if not exists treatment_steps jsonb,
  add column if not exists care_reactions jsonb,
  add column if not exists score_changes jsonb,
  add column if not exists aftercare jsonb,
  add column if not exists home_care_plan jsonb,
  add column if not exists next_care_note text,
  add column if not exists next_care_timing text;

comment on column public.customer_charts.chart_flow_status is
  'draft or completed. NULL means a legacy visit, treated as already completed.';
comment on column public.customer_charts.safety_snapshot is
  'Safety copied at this visit. Do not replace with the customer current profile.';
comment on column public.customer_charts.visit_intake is
  'Concerns, duration, desired change. Not concern_chips or care_tags.';
comment on column public.customer_charts.treatment_steps is
  'Ordered care steps for this visit. Not care_report_json timer lines.';

do $$
declare
  col text;
begin
  foreach col in array array[
    'discomfort_score',
    'score_hydration',
    'score_oil',
    'score_sensitivity',
    'score_redness',
    'score_keratin',
    'score_pores',
    'score_pigmentation',
    'score_elasticity',
    'score_acne'
  ]
  loop
    begin
      execute format(
        'alter table public.customer_charts add constraint customer_charts_%I_range check (%I is null or (%I >= 1 and %I <= 5))',
        col, col, col, col
      );
    exception
      when duplicate_object then null;
    end;
  end loop;

  begin
    alter table public.customer_charts
      add constraint customer_charts_flow_status_check
      check (
        chart_flow_status is null
        or chart_flow_status in ('draft', 'completed')
      );
  exception
    when duplicate_object then null;
  end;
end $$;

alter table public.chart_photo_records
  add column if not exists angle text,
  add column if not exists memo text;

do $$
begin
  alter table public.chart_photo_records
    add constraint chart_photo_records_angle_check
    check (angle is null or angle in ('front', 'left', 'right'));
exception
  when duplicate_object then null;
end $$;

comment on column public.chart_photo_records.angle is
  'front, left, or right. phase stays before/progress/after.';

drop policy if exists "mvp_chart_photo_records_update" on public.chart_photo_records;
create policy "mvp_chart_photo_records_update"
  on public.chart_photo_records for update
  using (true)
  with check (true);

-- chart_records view expands SELECT * at create time, so recreate it
-- when it is a view. A base table gets the same nullable columns.
do $$
declare
  relkind "char";
begin
  select c.relkind into relkind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'chart_records';

  if relkind = 'v' then
    execute 'create or replace view public.chart_records as select * from public.customer_charts';
    execute 'grant select, insert, update, delete on public.chart_records to anon, authenticated, service_role';
  elsif relkind = 'r' then
    execute $sql$
      alter table public.chart_records
        add column if not exists chart_flow_status text,
        add column if not exists discomfort_score smallint,
        add column if not exists score_hydration smallint,
        add column if not exists score_oil smallint,
        add column if not exists score_sensitivity smallint,
        add column if not exists score_redness smallint,
        add column if not exists score_keratin smallint,
        add column if not exists score_pores smallint,
        add column if not exists score_pigmentation smallint,
        add column if not exists score_elasticity smallint,
        add column if not exists score_acne smallint,
        add column if not exists visit_intake jsonb,
        add column if not exists safety_snapshot jsonb,
        add column if not exists consult_record jsonb,
        add column if not exists care_goals jsonb,
        add column if not exists treatment_steps jsonb,
        add column if not exists care_reactions jsonb,
        add column if not exists score_changes jsonb,
        add column if not exists aftercare jsonb,
        add column if not exists home_care_plan jsonb,
        add column if not exists next_care_note text,
        add column if not exists next_care_timing text
    $sql$;
  end if;
end $$;

notify pgrst, 'reload schema';
