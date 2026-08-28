-- 070: 중복 고객 병합 — 감사 로그 + merge_shop_customers RPC

create table if not exists public.customer_merge_events (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  primary_customer_id uuid not null references public.customers (id) on delete restrict,
  merged_customer_ids uuid[] not null default '{}',
  merged_by uuid references auth.users (id) on delete set null,
  merge_options jsonb not null default '{}'::jsonb,
  snapshot_before jsonb not null default '{}'::jsonb,
  result_summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists customer_merge_events_shop_idx
  on public.customer_merge_events (shop_id, created_at desc);

create index if not exists customer_merge_events_primary_idx
  on public.customer_merge_events (primary_customer_id);

comment on table public.customer_merge_events is
  '중복 고객 병합 감사 로그 (되돌리기 미지원, 스냅샷 참고용)';

alter table public.customer_merge_events enable row level security;

drop policy if exists "mvp_customer_merge_events_select" on public.customer_merge_events;
create policy "mvp_customer_merge_events_select"
  on public.customer_merge_events for select using (true);

-- jsonb memberships[] → combine_by_name (동일 service_name 합산)
create or replace function public._merge_memberships_jsonb(
  p_arrays jsonb[]
)
returns jsonb
language plpgsql
immutable
as $$
declare
  merged jsonb := '[]'::jsonb;
  elem jsonb;
  arr jsonb;
  sname text;
  found_idx int;
  existing jsonb;
  new_total int;
  new_used int;
  new_exp date;
  cur_exp date;
  i int;
begin
  foreach arr in array p_arrays
  loop
    if arr is null or jsonb_typeof(arr) <> 'array' then
      continue;
    end if;
    for elem in select * from jsonb_array_elements(arr)
    loop
      sname := coalesce(nullif(trim(elem->>'service_name'), ''), '회원권');
      found_idx := null;
      for i in 0 .. (jsonb_array_length(merged) - 1)
      loop
        if coalesce(nullif(trim(merged->i->>'service_name'), ''), '회원권') = sname then
          found_idx := i;
          exit;
        end if;
      end loop;

      if found_idx is null then
        merged := merged || jsonb_build_array(elem);
      else
        existing := merged->found_idx;
        new_total := greatest(coalesce((existing->>'total_visits')::int, 0), 0)
          + greatest(coalesce((elem->>'total_visits')::int, 0), 0);
        new_used := greatest(coalesce((existing->>'used_visits')::int, 0), 0)
          + greatest(coalesce((elem->>'used_visits')::int, 0), 0);
        begin
          cur_exp := nullif(existing->>'expires_at', '')::date;
        exception when others then
          cur_exp := null;
        end;
        begin
          new_exp := nullif(elem->>'expires_at', '')::date;
        exception when others then
          new_exp := null;
        end;
        merged := jsonb_set(
          merged,
          array[found_idx::text],
          jsonb_build_object(
            'id', coalesce(nullif(existing->>'id', ''), nullif(elem->>'id', ''), gen_random_uuid()::text),
            'service_name', sname,
            'total_visits', new_total,
            'used_visits', least(new_used, new_total),
            'paid_amount',
              greatest(coalesce((existing->>'paid_amount')::int, 0), 0)
              + greatest(coalesce((elem->>'paid_amount')::int, 0), 0),
            'per_session_value',
              greatest(coalesce((existing->>'per_session_value')::int, 0), 0),
              coalesce((elem->>'per_session_value')::int, 0)
          )
          || case
            when greatest(cur_exp, new_exp) is not null then
              jsonb_build_object('expires_at', greatest(cur_exp, new_exp)::text)
            else '{}'::jsonb
          end,
          true
        );
      end if;
    end loop;
  end loop;
  return merged;
end;
$$;

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
  if p_primary_id is null then
    raise exception 'Primary 고객 ID가 필요합니다.';
  end if;
  if p_source_ids is null or coalesce(cardinality(p_source_ids), 0) = 0 then
    raise exception '병합할 Secondary 고객을 1명 이상 선택해 주세요.';
  end if;
  if cardinality(p_source_ids) > 10 then
    raise exception '한 번에 최대 10명까지 병합할 수 있습니다.';
  end if;

  select c.* into v_primary
  from public.customers c
  inner join public.shops s on s.id = c.shop_id
  where c.id = p_primary_id and s.owner_user_id = v_uid;
  if not found then
    raise exception 'Primary 고객을 찾을 수 없거나 권한이 없습니다.';
  end if;
  v_shop_id := v_primary.shop_id;
  v_primary_user := v_primary.user_id;

  select coalesce(array_agg(distinct sid), array[]::uuid[])
  into v_sources
  from unnest(p_source_ids) as sid
  where sid is not null and sid <> p_primary_id
    and exists (
      select 1 from public.customers c2
      inner join public.shops s2 on s2.id = c2.shop_id
      where c2.id = sid and c2.shop_id = v_shop_id and s2.owner_user_id = v_uid
    );

  if coalesce(cardinality(v_sources), 0) = 0 then
    raise exception '병합 가능한 Secondary 고객이 없습니다.';
  end if;

  -- Snapshot before
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'phone', c.phone,
    'chart_count', (select count(*) from public.customer_charts ch where ch.customer_id = c.id),
    'memberships', c.memberships
  )), '[]'::jsonb)
  into v_snap
  from public.customers c
  where c.id = p_primary_id or c.id = any (v_sources);

  v_membership_arrays := array_append(v_membership_arrays, coalesce(v_primary.memberships, '[]'::jsonb));

  -- Move child rows + collect source data
  foreach v_source_id in array v_sources
  loop
    select * into v_src from public.customers where id = v_source_id;

    v_membership_arrays := array_append(
      v_membership_arrays,
      coalesce(v_src.memberships, '[]'::jsonb)
    );

    -- Charts → primary (visit_number renumbered later)
    update public.customer_charts
    set customer_id = p_primary_id, updated_at = now()
    where customer_id = v_source_id;

    -- Reviews
    update public.customer_reviews
    set customer_id = p_primary_id, updated_at = now()
    where customer_id = v_source_id;
    get diagnostics v_row_count = row_count;
    v_reviews_moved := v_reviews_moved + v_row_count;

    -- Care diary (concat on date conflict) — optional table
    begin
      update public.care_diary_notes n
      set body = n.body || E'\n---\n' || s.body,
          updated_at = now()
      from public.care_diary_notes s
      where s.customer_id = v_source_id
        and n.customer_id = p_primary_id
        and n.note_date = s.note_date;
      delete from public.care_diary_notes
      where customer_id = v_source_id
        and note_date in (
          select note_date from public.care_diary_notes where customer_id = p_primary_id
        );
      update public.care_diary_notes
      set customer_id = p_primary_id, updated_at = now()
      where customer_id = v_source_id;
    exception when undefined_table then null;
    end;

    -- Followers (ignore unique conflicts)
    begin
      update public.shop_followers
      set customer_id = p_primary_id
      where customer_id = v_source_id
        and not exists (
          select 1 from public.shop_followers f2
          where f2.shop_id = shop_followers.shop_id
            and f2.customer_id = p_primary_id
        );
      delete from public.shop_followers where customer_id = v_source_id;
    exception when undefined_table then null;
    end;

    -- Review ops events
    begin
      update public.review_request_events
      set customer_id = p_primary_id, updated_at = now()
      where customer_id = v_source_id;
    exception when undefined_table then null;
    end;

    -- Echo grants
    begin
      update public.customer_echo_grants
      set customer_id = p_primary_id, updated_at = now()
      where customer_id = v_source_id;
    exception when undefined_table then null;
    end;

    -- Boost placements payer
    begin
      update public.boost_placements
      set paid_by_customer_id = p_primary_id
      where paid_by_customer_id = v_source_id;
    exception when undefined_table then null;
    end;

    -- Point transactions ledger
    begin
      update public.point_transactions
      set customer_id = p_primary_id
      where customer_id = v_source_id;
    exception when undefined_table then null;
    end;

    -- B2C wallet merge (sum balances)
    begin
      select * into v_sw
      from public.wallets
      where owner_type = 'customer' and customer_id = v_source_id;
      if found then
        select * into v_pw
        from public.wallets
        where owner_type = 'customer' and customer_id = p_primary_id;
        if not found then
          update public.wallets
          set customer_id = p_primary_id, updated_at = now()
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

    -- user_id: keep primary; source cleared before delete
    if v_src.user_id is not null and v_primary_user is null then
      v_primary_user := v_src.user_id;
    end if;

    -- Profile field backfill stored in v_primary vars via final update
  end loop;

  -- Renumber visit_number chronologically
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
    where customer_id = p_primary_id
  )
  update public.customer_charts c
  set visit_number = o.new_vn, updated_at = now()
  from ordered o
  where c.id = o.id;

  select count(*) into v_charts_moved
  from public.customer_charts where customer_id = p_primary_id;

  -- Merge memberships jsonb
  v_merged_memberships := public._merge_memberships_jsonb(v_membership_arrays);

  -- Latest visit date
  select max(coalesce(ch.visit_checked_at, ch.created_at))
  into v_latest_visit
  from public.customer_charts ch
  where ch.customer_id = p_primary_id;

  -- Update primary customer profile
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
      where cc.id = any (v_sources) and nullif(cc.gender, '') is not null limit 1
    )),
    birth_date = coalesce(c.birth_date, (
      select cc.birth_date from public.customers cc
      where cc.id = any (v_sources) and cc.birth_date is not null limit 1
    )),
    address = coalesce(nullif(c.address, ''), (
      select cc.address from public.customers cc
      where cc.id = any (v_sources) and nullif(cc.address, '') is not null limit 1
    )),
    occupation = coalesce(nullif(c.occupation, ''), (
      select cc.occupation from public.customers cc
      where cc.id = any (v_sources) and nullif(cc.occupation, '') is not null limit 1
    )),
    memo = case
      when nullif(c.memo, '') is null then (
        select string_agg(nullif(cc.memo, ''), E'\n' order by cc.created_at)
        from public.customers cc where cc.id = any (v_sources)
      )
      else c.memo || coalesce(
        E'\n' || (select string_agg(nullif(cc.memo, ''), E'\n' order by cc.created_at)
                  from public.customers cc where cc.id = any (v_sources) and nullif(cc.memo, '') is not null),
        ''
      )
    end,
    last_treatment_date = coalesce(v_latest_visit::date, c.last_treatment_date),
    updated_at = now()
  where c.id = p_primary_id;

  -- Sync membership tickets from jsonb
  perform public.sync_membership_tickets_for_customer(p_primary_id);

  -- Delete source customers
  delete from public.customers where id = any (v_sources);

  v_result := jsonb_build_object(
    'primary_id', p_primary_id,
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
    v_shop_id, p_primary_id, v_sources,
    v_uid, coalesce(p_options, '{}'::jsonb), v_snap, v_result
  );

  return v_result;
end;
$$;

comment on function public.merge_shop_customers(uuid, uuid[], jsonb) is
  '원장 소유 고객 중복 병합. Primary 유지, Secondary 삭제. memberships combine_by_name, wallet 합산.';

grant execute on function public.merge_shop_customers(uuid, uuid[], jsonb)
  to authenticated, anon;
