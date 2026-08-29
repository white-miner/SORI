-- 094_seminar_extended_fields_and_rpc.sql
-- PO: duration, provided materials, additional images + upsert/get detail RPCs.
-- linked_chart_id = existing target_case_id (no duplicate column).

alter table public.seminar_classes
  add column if not exists duration_minutes int not null default 120
    check (duration_minutes >= 15 and duration_minutes <= 720),
  add column if not exists provided_materials text[] not null default '{}'::text[],
  add column if not exists additional_images text[] not null default '{}'::text[];

comment on column public.seminar_classes.target_case_id is
  'PO linked_chart_id — source B/A chart that triggered this seminar';
comment on column public.seminar_classes.duration_minutes is
  'Total class duration in minutes (e.g. 120 = 2 hours)';
comment on column public.seminar_classes.provided_materials is
  'Materials/benefits provided to attendees (PPT, pigments, diploma, etc.)';
comment on column public.seminar_classes.additional_images is
  'Extra seminar promo images beyond linked B/A chart';

-- Refresh compat view
create or replace view public.seminars as
select
  id,
  director_shop_id,
  target_case_id,
  title,
  event_date,
  location,
  price,
  max_capacity,
  current_enrollment,
  status,
  description,
  class_format,
  duration_minutes,
  provided_materials,
  additional_images,
  created_at,
  updated_at
from public.seminar_classes;

comment on view public.seminars is
  '호환 뷰 — 물리 테이블은 seminar_classes';

grant select on public.seminars to anon, authenticated, public;

-- Upsert seminar (create when id null/empty, else update)
create or replace function public.upsert_seminar_class(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_shop uuid;
  v_row public.seminar_classes%rowtype;
  v_target uuid;
  v_materials text[];
  v_images text[];
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;

  begin
    v_id := nullif(trim(coalesce(p_payload->>'id', '')), '')::uuid;
  exception when others then
    v_id := null;
  end;

  begin
    v_shop := nullif(trim(coalesce(p_payload->>'director_shop_id', '')), '')::uuid;
  exception when others then
    v_shop := null;
  end;

  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;

  if v_shop is null then
    raise exception 'director shop required';
  end if;

  if not exists (
    select 1 from public.shops s
    where s.id = v_shop and s.owner_user_id = v_uid
  ) then
    raise exception 'forbidden';
  end if;

  begin
    v_target := nullif(trim(coalesce(p_payload->>'linked_chart_id', p_payload->>'target_case_id', '')), '')::uuid;
  exception when others then
    v_target := null;
  end;

  select coalesce(array_agg(distinct trim(x)), '{}'::text[])
  into v_materials
  from jsonb_array_elements_text(coalesce(p_payload->'provided_materials', '[]'::jsonb)) as t(x)
  where trim(x) <> '';

  select coalesce(array_agg(distinct trim(x)), '{}'::text[])
  into v_images
  from jsonb_array_elements_text(coalesce(p_payload->'additional_images', '[]'::jsonb)) as t(x)
  where trim(x) <> '' and trim(x) like 'http%';

  if v_id is null then
    insert into public.seminar_classes (
      director_shop_id,
      target_case_id,
      title,
      event_date,
      location,
      price,
      max_capacity,
      status,
      description,
      class_format,
      duration_minutes,
      provided_materials,
      additional_images,
      updated_at
    ) values (
      v_shop,
      v_target,
      left(trim(coalesce(p_payload->>'title', '')), 200),
      nullif(trim(coalesce(p_payload->>'event_date', '')), '')::timestamptz,
      left(trim(coalesce(p_payload->>'location', '')), 300),
      greatest(0, coalesce((p_payload->>'price')::int, 0)),
      greatest(1, least(coalesce((p_payload->>'max_capacity')::int, 20), 500)),
      coalesce(nullif(trim(p_payload->>'status'), ''), 'open'),
      left(trim(coalesce(p_payload->>'description', '')), 8000),
      coalesce(nullif(trim(p_payload->>'class_format'), ''), 'oneday'),
      greatest(15, least(coalesce((p_payload->>'duration_minutes')::int, 120), 720)),
      v_materials,
      v_images,
      now()
    )
    returning * into v_row;
  else
    update public.seminar_classes sc
    set
      title = left(trim(coalesce(p_payload->>'title', sc.title)), 200),
      event_date = coalesce(
        nullif(trim(coalesce(p_payload->>'event_date', '')), '')::timestamptz,
        sc.event_date
      ),
      location = left(trim(coalesce(p_payload->>'location', sc.location)), 300),
      price = greatest(0, coalesce((p_payload->>'price')::int, sc.price)),
      max_capacity = greatest(1, least(coalesce((p_payload->>'max_capacity')::int, sc.max_capacity), 500)),
      status = coalesce(nullif(trim(p_payload->>'status'), ''), sc.status),
      description = left(trim(coalesce(p_payload->>'description', sc.description)), 8000),
      class_format = coalesce(nullif(trim(p_payload->>'class_format'), ''), sc.class_format),
      target_case_id = case
        when p_payload ? 'linked_chart_id' or p_payload ? 'target_case_id'
          then v_target
        else sc.target_case_id
      end,
      duration_minutes = greatest(
        15,
        least(coalesce((p_payload->>'duration_minutes')::int, sc.duration_minutes), 720)
      ),
      provided_materials = case
        when p_payload ? 'provided_materials' then v_materials
        else sc.provided_materials
      end,
      additional_images = case
        when p_payload ? 'additional_images' then v_images
        else sc.additional_images
      end,
      updated_at = now()
    where sc.id = v_id
      and sc.director_shop_id = v_shop
    returning * into v_row;

    if v_row.id is null then
      raise exception 'seminar not found or forbidden';
    end if;
  end if;

  return jsonb_build_object(
    'seminar', to_jsonb(v_row),
    'linked_chart_id', v_row.target_case_id
  );
end;
$$;

comment on function public.upsert_seminar_class(jsonb) is
  'Create/update seminar_classes — PO linked_chart_id maps to target_case_id';

grant execute on function public.upsert_seminar_class(jsonb) to authenticated;

-- Detail fetch with shop + linked chart
create or replace function public.get_seminar_detail(p_class_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid := p_class_id;
  v_row public.seminar_classes%rowtype;
  v_shop jsonb;
  v_chart jsonb;
begin
  if v_id is null then
    return null;
  end if;

  select * into v_row
  from public.seminar_classes sc
  where sc.id = v_id;

  if v_row.id is null then
    return null;
  end if;

  select to_jsonb(s.*) into v_shop
  from public.shops s
  where s.id = v_row.director_shop_id;

  if v_row.target_case_id is not null then
    select to_jsonb(c.*) into v_chart
    from public.customer_charts c
    where c.id = v_row.target_case_id;
  end if;

  return jsonb_build_object(
    'seminar', to_jsonb(v_row),
    'linked_chart_id', v_row.target_case_id,
    'shop', v_shop,
    'target_chart', v_chart
  );
end;
$$;

comment on function public.get_seminar_detail(uuid) is
  'Seminar landing detail — seminar + shop + linked B/A chart';

grant execute on function public.get_seminar_detail(uuid) to anon, authenticated, public;
