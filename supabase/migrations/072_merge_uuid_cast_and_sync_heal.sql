-- 072: membership_tickets.id uuid/text dual + merge RPC cast hardening

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) sync_membership_tickets_for_customer — id column type aware (024=uuid, 016=text)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.sync_membership_tickets_for_customer(
  p_customer_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  item jsonb;
  tid_text text;
  tid_uuid uuid;
  tname text;
  total int;
  used int;
  exp date;
  paid int;
  per_val int;
  v_id_is_uuid boolean;
begin
  if p_customer_id is null then
    return;
  end if;

  select (udt_name = 'uuid')
  into v_id_is_uuid
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'membership_tickets'
    and column_name = 'id';

  v_id_is_uuid := coalesce(v_id_is_uuid, false);

  select * into c from public.customers where id = p_customer_id;
  if not found then
    return;
  end if;

  delete from public.membership_tickets where customer_id = p_customer_id;

  if c.memberships is null or jsonb_typeof(c.memberships) <> 'array' then
    return;
  end if;

  for item in select * from jsonb_array_elements(c.memberships)
  loop
    tname := coalesce(nullif(trim(item->>'service_name'), ''), '회원권');
    total := greatest(coalesce((item->>'total_visits')::int, 0), 0);
    used := greatest(coalesce((item->>'used_visits')::int, 0), 0);
    paid := greatest(coalesce((item->>'paid_amount')::int, 0), 0);
    per_val := greatest(coalesce((item->>'per_session_value')::int, 0), 0);
    if per_val <= 0 and paid > 0 and total > 0 then
      per_val := round(paid::numeric / total::numeric)::int;
    end if;
    if total <= 0 then
      continue;
    end if;
    begin
      exp := nullif(item->>'expires_at', '')::date;
    exception when others then
      exp := null;
    end;

    if v_id_is_uuid then
      begin
        tid_uuid := coalesce(nullif(trim(item->>'id'), '')::uuid, gen_random_uuid());
      exception when others then
        tid_uuid := gen_random_uuid();
      end;

      insert into public.membership_tickets (
        id, shop_id, customer_id, customer_phone_digits,
        ticket_name, total_visits, used_visits, expires_at, is_active,
        paid_amount, per_session_value, updated_at
      ) values (
        tid_uuid,
        c.shop_id,
        c.id,
        regexp_replace(coalesce(c.phone, ''), '[^0-9]', '', 'g'),
        tname,
        total,
        least(used, total),
        exp,
        (total - used) > 0,
        paid,
        per_val,
        now()
      )
      on conflict (id) do update set
        shop_id = excluded.shop_id,
        customer_id = excluded.customer_id,
        customer_phone_digits = excluded.customer_phone_digits,
        ticket_name = excluded.ticket_name,
        total_visits = excluded.total_visits,
        used_visits = excluded.used_visits,
        expires_at = excluded.expires_at,
        is_active = excluded.is_active,
        paid_amount = excluded.paid_amount,
        per_session_value = excluded.per_session_value,
        updated_at = now();
    else
      tid_text := coalesce(nullif(trim(item->>'id'), ''), gen_random_uuid()::text);

      insert into public.membership_tickets (
        id, shop_id, customer_id, customer_phone_digits,
        ticket_name, total_visits, used_visits, expires_at, is_active,
        paid_amount, per_session_value, updated_at
      ) values (
        tid_text,
        c.shop_id,
        c.id,
        regexp_replace(coalesce(c.phone, ''), '[^0-9]', '', 'g'),
        tname,
        total,
        least(used, total),
        exp,
        (total - used) > 0,
        paid,
        per_val,
        now()
      )
      on conflict (id) do update set
        shop_id = excluded.shop_id,
        customer_id = excluded.customer_id,
        customer_phone_digits = excluded.customer_phone_digits,
        ticket_name = excluded.ticket_name,
        total_visits = excluded.total_visits,
        used_visits = excluded.used_visits,
        expires_at = excluded.expires_at,
        is_active = excluded.is_active,
        paid_amount = excluded.paid_amount,
        per_session_value = excluded.per_session_value,
        updated_at = now();
    end if;
  end loop;
end;
$$;

grant execute on function public.sync_membership_tickets_for_customer(uuid)
  to anon, authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) merge_shop_customers — explicit uuid casts + PostgREST text[] bridge
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.merge_shop_customers(
  p_primary_id uuid,
  p_source_ids uuid[],
  p_options jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_primary_id uuid := p_primary_id::uuid;
  v_source_ids uuid[] := coalesce(p_source_ids, array[]::uuid[]);
  v_primary public.customers%rowtype;
  v_shop_id uuid;
  v_sources uuid[];
  v_source_id uuid;
  v_snap jsonb := '[]'::jsonb;
  v_merged_memberships jsonb;
  v_membership_arrays jsonb[] := array[]::jsonb[];
  v_charts_moved int := 0;
  v_reviews_moved int := 0;
  v_wallets_merged int := 0;
  v_latest_visit timestamptz;
  v_primary_user uuid;
  v_src record;
  v_pw public.wallets%rowtype;
  v_sw public.wallets%rowtype;
  v_result jsonb;
  v_row_count int;
begin
  if v_uid is null then
    raise exception '로그인이 필요합니다.';
  end if;
  if v_primary_id is null then
    raise exception 'Primary 고객 ID가 필요합니다.';
  end if;
  if coalesce(cardinality(v_source_ids), 0) = 0 then
    raise exception '병합할 Secondary 고객을 1명 이상 선택해 주세요.';
  end if;
  if cardinality(v_source_ids) > 10 then
    raise exception '한 번에 최대 10명까지 병합할 수 있습니다.';
  end if;

  select c.* into v_primary
  from public.customers c
  inner join public.shops s on s.id = c.shop_id
  where c.id = v_primary_id and s.owner_user_id = v_uid;
  if not found then
    raise exception 'Primary 고객을 찾을 수 없거나 권한이 없습니다.';
  end if;
  v_shop_id := v_primary.shop_id;
  v_primary_user := v_primary.user_id;

  select coalesce(array_agg(distinct sid::uuid), array[]::uuid[])
  into v_sources
  from unnest(v_source_ids) as sid
  where sid is not null and sid::uuid <> v_primary_id
    and exists (
      select 1 from public.customers c2
      inner join public.shops s2 on s2.id = c2.shop_id
      where c2.id = sid::uuid and c2.shop_id = v_shop_id and s2.owner_user_id = v_uid
    );

  if coalesce(cardinality(v_sources), 0) = 0 then
    raise exception '병합 가능한 Secondary 고객이 없습니다.';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'phone', c.phone,
    'chart_count', (select count(*) from public.customer_charts ch where ch.customer_id = c.id),
    'memberships', c.memberships
  )), '[]'::jsonb)
  into v_snap
  from public.customers c
  where c.id = v_primary_id or c.id = any (v_sources::uuid[]);

  v_membership_arrays := array_append(v_membership_arrays, coalesce(v_primary.memberships, '[]'::jsonb));

  foreach v_source_id in array v_sources
  loop
    select * into v_src from public.customers where id = v_source_id::uuid;

    v_membership_arrays := array_append(
      v_membership_arrays,
      coalesce(v_src.memberships, '[]'::jsonb)
    );

    update public.customer_charts
    set customer_id = v_primary_id, updated_at = now()
    where customer_id = v_source_id::uuid;

    update public.customer_reviews
    set customer_id = v_primary_id, updated_at = now()
    where customer_id = v_source_id::uuid;
    get diagnostics v_row_count = row_count;
    v_reviews_moved := v_reviews_moved + v_row_count;

    begin
      update public.care_diary_notes n
      set body = n.body || E'\n---\n' || s.body,
          updated_at = now()
      from public.care_diary_notes s
      where s.customer_id = v_source_id::uuid
        and n.customer_id = v_primary_id
        and n.note_date = s.note_date;
      delete from public.care_diary_notes
      where customer_id = v_source_id::uuid
        and note_date in (
          select note_date from public.care_diary_notes where customer_id = v_primary_id
        );
      update public.care_diary_notes
      set customer_id = v_primary_id, updated_at = now()
      where customer_id = v_source_id::uuid;
    exception when undefined_table then null;
    end;

    begin
      update public.shop_followers
      set customer_id = v_primary_id
      where customer_id = v_source_id::uuid
        and not exists (
          select 1 from public.shop_followers f2
          where f2.shop_id = shop_followers.shop_id
            and f2.customer_id = v_primary_id
        );
      delete from public.shop_followers where customer_id = v_source_id::uuid;
    exception when undefined_table then null;
    end;

    begin
      update public.review_request_events
      set customer_id = v_primary_id, updated_at = now()
      where customer_id = v_source_id::uuid;
    exception when undefined_table then null;
    end;

    begin
      update public.customer_echo_grants
      set customer_id = v_primary_id, updated_at = now()
      where customer_id = v_source_id::uuid;
    exception when undefined_table then null;
    end;

    begin
      update public.boost_placements
      set paid_by_customer_id = v_primary_id
      where paid_by_customer_id = v_source_id::uuid;
    exception when undefined_table then null;
    end;

    begin
      update public.point_transactions
      set customer_id = v_primary_id
      where customer_id = v_source_id::uuid;
    exception when undefined_table then null;
    end;

    begin
      select * into v_sw
      from public.wallets
      where owner_type = 'customer' and customer_id = v_source_id::uuid;
      if found then
        select * into v_pw
        from public.wallets
        where owner_type = 'customer' and customer_id = v_primary_id;
        if not found then
          update public.wallets
          set customer_id = v_primary_id, updated_at = now()
          where id = v_sw.id;
        else
          update public.wallets
          set
            point_free_balance = coalesce(v_pw.point_free_balance, 0) + coalesce(v_sw.point_free_balance, 0),
            point_paid_balance = coalesce(v_pw.point_paid_balance, 0) + coalesce(v_sw.point_paid_balance, 0),
            settlement_balance = coalesce(v_pw.settlement_balance, 0) + coalesce(v_sw.settlement_balance, 0),
            settlement_pending = coalesce(v_pw.settlement_pending, 0) + coalesce(v_sw.settlement_pending, 0),
            updated_at = now()
          where id = v_pw.id;
          delete from public.wallets where id = v_sw.id;
        end if;
        v_wallets_merged := v_wallets_merged + 1;
      end if;
    exception when undefined_table then null;
    end;

    if v_src.user_id is not null and v_primary_user is null then
      v_primary_user := v_src.user_id;
    end if;
  end loop;

  with ordered as (
    select
      id,
      row_number() over (
        order by
          coalesce(visit_checked_at, created_at, updated_at),
          visit_number,
          created_at
      )::int as new_vn
    from public.customer_charts
    where customer_id = v_primary_id
  )
  update public.customer_charts c
  set visit_number = o.new_vn, updated_at = now()
  from ordered o
  where c.id = o.id;

  select count(*) into v_charts_moved
  from public.customer_charts where customer_id = v_primary_id;

  v_merged_memberships := public._merge_memberships_jsonb(v_membership_arrays);

  select max(coalesce(ch.visit_checked_at, ch.created_at))
  into v_latest_visit
  from public.customer_charts ch
  where ch.customer_id = v_primary_id;

  update public.customers c
  set
    memberships = v_merged_memberships,
    membership_service_name = coalesce(
      nullif(v_merged_memberships->0->>'service_name', ''),
      c.membership_service_name
    ),
    membership_total_visits = coalesce((v_merged_memberships->0->>'total_visits')::int, 0),
    membership_used_visits = coalesce((v_merged_memberships->0->>'used_visits')::int, 0),
    user_id = coalesce(v_primary.user_id, v_primary_user),
    gender = coalesce(nullif(c.gender, ''), (
      select cc.gender from public.customers cc
      where cc.id = any (v_sources::uuid[]) and nullif(cc.gender, '') is not null limit 1
    )),
    birth_date = coalesce(c.birth_date, (
      select cc.birth_date from public.customers cc
      where cc.id = any (v_sources::uuid[]) and cc.birth_date is not null limit 1
    )),
    address = coalesce(nullif(c.address, ''), (
      select cc.address from public.customers cc
      where cc.id = any (v_sources::uuid[]) and nullif(cc.address, '') is not null limit 1
    )),
    occupation = coalesce(nullif(c.occupation, ''), (
      select cc.occupation from public.customers cc
      where cc.id = any (v_sources::uuid[]) and nullif(cc.occupation, '') is not null limit 1
    )),
    memo = case
      when nullif(c.memo, '') is null then (
        select string_agg(nullif(cc.memo, ''), E'\n' order by cc.created_at)
        from public.customers cc where cc.id = any (v_sources::uuid[])
      )
      else c.memo || coalesce(
        E'\n' || (select string_agg(nullif(cc.memo, ''), E'\n' order by cc.created_at)
                  from public.customers cc where cc.id = any (v_sources::uuid[]) and nullif(cc.memo, '') is not null),
        ''
      )
    end,
    last_treatment_date = coalesce(v_latest_visit::date, c.last_treatment_date),
    updated_at = now()
  where c.id = v_primary_id;

  perform public.sync_membership_tickets_for_customer(v_primary_id);

  delete from public.customers where id = any (v_sources::uuid[]);

  v_result := jsonb_build_object(
    'primary_id', v_primary_id,
    'merged_ids', to_jsonb(v_sources),
    'charts_total', v_charts_moved,
    'reviews_moved', v_reviews_moved,
    'wallets_merged', v_wallets_merged,
    'membership_strategy', coalesce(p_options->>'membershipStrategy', 'combine_by_name')
  );

  insert into public.customer_merge_events (
    shop_id, primary_customer_id, merged_customer_ids,
    merged_by, merge_options, snapshot_before, result_summary
  ) values (
    v_shop_id, v_primary_id, v_sources,
    v_uid, coalesce(p_options, '{}'::jsonb), v_snap, v_result
  );

  return v_result;
end;
$$;

-- PostgREST may pass text[] from JSON — explicit bridge overload.
create or replace function public.merge_shop_customers(
  p_primary_id text,
  p_source_ids text[],
  p_options jsonb default '{}'::jsonb
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.merge_shop_customers(
    p_primary_id::uuid,
    coalesce(
      array(
        select s::uuid from unnest(coalesce(p_source_ids, array[]::text[])) as s
        where nullif(trim(s), '') is not null
      ),
      array[]::uuid[]
    ),
    coalesce(p_options, '{}'::jsonb)
  );
$$;

grant execute on function public.merge_shop_customers(uuid, uuid[], jsonb)
  to authenticated, anon;
grant execute on function public.merge_shop_customers(text, text[], jsonb)
  to authenticated, anon;
