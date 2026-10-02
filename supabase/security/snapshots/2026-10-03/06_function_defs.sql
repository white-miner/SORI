-- SORI security snapshot: pg_get_functiondef() for all 169 functions in schema public
-- project: tieojdbzmqcmlwyqltrk / captured at 2026-10-02 22:30:45.429761+00 (UTC) = 2026-10-03 KST
-- server: PostgreSQL 17.6 on aarch64-unknown-linux-gnu, compiled by gcc (GCC) 15.2.0, 64-bit
-- Generated read-only from catalog queries (pg_policies, pg_class.relacl, pg_proc, pg_views, storage.buckets).
-- See README.md in this folder before running anything.

-- Each block is the exact text of pg_get_functiondef(oid) followed by ';'.
-- md5 of each block (without the trailing ';') is listed in functions_md5.tsv for drift checks.
-- All functions are owned by postgres. Privileges are in 05_function_grants.sql (CREATE OR REPLACE keeps existing ACLs).

-- ---- public._merge_memberships_jsonb(jsonb[])  secdef=false  md5=f8dcc73bfd9e49c64221c650ec7fc9dc
CREATE OR REPLACE FUNCTION public._merge_memberships_jsonb(p_arrays jsonb[])
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
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
$function$
;

-- ---- public.accept_program_quote_v2(uuid,uuid,text,integer,text)  secdef=true  md5=c2b3bd08a12ffc991ac5acd95ee4cbf5
CREATE OR REPLACE FUNCTION public.accept_program_quote_v2(p_quote_id uuid, p_customer_id uuid, p_payment_status text DEFAULT 'unpaid'::text, p_paid_krw integer DEFAULT 0, p_method text DEFAULT 'cash'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_quote    public.program_quotes;
  v_chosen   jsonb;
  v_visits   int;
  v_extra    int;
  v_paid_due int;
  v_unit     int;
  v_mid      uuid;
  v_promo    record;
  v_coupons  jsonb;
  v_row      jsonb;
begin
  select * into v_quote
    from public.program_quotes
   where id = p_quote_id
     for update;

  if not found then
    raise exception 'program_quote % not found', p_quote_id using errcode = 'P0002';
  end if;

  if not public.program_shop_is_director(v_quote.shop_id) then
    raise exception 'not director of shop' using errcode = '42501';
  end if;

  if p_customer_id is null then
    raise exception 'customer_id required' using errcode = '22023';
  end if;

  perform 1 from public.customers where id = p_customer_id for update;
  if not found then
    raise exception 'customer % not found', p_customer_id using errcode = 'P0002';
  end if;

  if v_quote.chosen_package_id is not null
     and (v_quote.snapshot -> 'right' ->> 'id') = v_quote.chosen_package_id::text then
    v_chosen := v_quote.snapshot -> 'right';
  else
    v_chosen := v_quote.snapshot -> 'left';
  end if;

  v_visits   := greatest(coalesce((v_chosen ->> 'visit_count')::int, 1), 1);
  v_paid_due := greatest(v_quote.payable_krw, 0);

  -- 횟수 추가 혜택만 회원권에 더한다. next_visit_credit 은 쿠폰으로 분기한다.
  select coalesce(sum(pr.extra_visits * coalesce(qp.qty, 1)), 0)
    into v_extra
    from public.program_quote_promos qp
    join public.program_promotions pr on pr.id = qp.promotion_id
   where qp.quote_id = p_quote_id
     and pr.kind <> 'next_visit_credit';

  v_visits := v_visits + coalesce(v_extra, 0);
  v_unit := case when v_visits > 0 then (v_paid_due / v_visits) else 0 end;

  insert into public.program_memberships (
    shop_id, customer_id, source_quote_id, service_name,
    total_visits, paid_krw, per_session_krw
  ) values (
    v_quote.shop_id, p_customer_id, p_quote_id,
    coalesce(v_chosen ->> 'name', 'Program'),
    v_visits, v_paid_due, v_unit
  ) returning id into v_mid;

  -- 읽기 미러 유지 — 기존 화면 무중단
  update public.customers
     set memberships = coalesce(memberships, '[]'::jsonb) || jsonb_build_array(
           jsonb_build_object(
             'id', v_mid::text,
             'service_name', coalesce(v_chosen ->> 'name', 'Program'),
             'total_visits', v_visits,
             'used_visits', 0,
             'paid_amount', v_paid_due,
             'per_session_value', v_unit
           ))
   where id = p_customer_id;

  -- S7 — 미래가치는 회원권 횟수가 아니라 쿠폰 행으로 떨어진다.
  for v_promo in
    select pr.id, pr.title, pr.percent_off, pr.discount_krw,
           pr.extra_visits, pr.gift_qty, pr.valid_until,
           coalesce(qp.qty, 1) as qty
      from public.program_quote_promos qp
      join public.program_promotions pr on pr.id = qp.promotion_id
     where qp.quote_id = p_quote_id
       and pr.kind = 'next_visit_credit'
  loop
    insert into public.program_customer_coupons (
      shop_id, customer_id, issued_quote_id, promotion_id, title,
      percent_off, discount_krw, extra_visits, gift_qty, expires_at
    )
    select v_quote.shop_id, p_customer_id, p_quote_id, v_promo.id, v_promo.title,
           v_promo.percent_off, v_promo.discount_krw, v_promo.extra_visits,
           v_promo.gift_qty, v_promo.valid_until
      from generate_series(1, v_promo.qty);
  end loop;

  -- S6 — 사용 이력. 최근 사용순 정렬의 근거가 된다.
  update public.program_promotions pr
     set use_count = pr.use_count + 1,
         last_used_at = now()
    from public.program_quote_promos qp
   where qp.quote_id = p_quote_id
     and pr.id = qp.promotion_id;

  -- C11 — 수기 결제. PG 는 이번에도 범위 밖이다.
  if p_paid_krw > 0 then
    insert into public.program_quote_payments (quote_id, amount_krw, method)
    values (p_quote_id, p_paid_krw, p_method);
  end if;

  update public.program_quotes
     set customer_id = p_customer_id,
         status = 'accepted',
         accepted_at = now(),
         sold_by = coalesce(sold_by, auth.uid()),
         payment_status = case
           when p_paid_krw >= v_paid_due and p_paid_krw > 0 then 'paid'
           when p_paid_krw > 0 then 'partial'
           else p_payment_status end
   where id = p_quote_id
  returning to_jsonb(program_quotes.*) into v_row;

  select coalesce(jsonb_agg(to_jsonb(c.*)), '[]'::jsonb)
    into v_coupons
    from public.program_customer_coupons c
   where c.issued_quote_id = p_quote_id;

  return jsonb_build_object(
    'quote', v_row,
    'membership_id', v_mid::text,
    'coupons', v_coupons
  );
end $function$
;

-- ---- public.accept_program_quote(uuid,uuid)  secdef=true  md5=eaa0b4ef335459b2cc9ad06ee75dfe13
CREATE OR REPLACE FUNCTION public.accept_program_quote(p_quote_id uuid, p_customer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_quote     public.program_quotes;
  v_chosen    jsonb;
  v_visits    int;
  v_extra     int;
  v_paid      int;
  v_unit      int;
  v_member    jsonb;
  v_customer  public.customers;
begin
  select * into v_quote
    from public.program_quotes
   where id = p_quote_id
     for update;

  if not found then
    raise exception 'program_quote % not found', p_quote_id
      using errcode = 'P0002';
  end if;

  if not public.program_shop_is_director(v_quote.shop_id) then
    raise exception 'not director of shop'
      using errcode = '42501';
  end if;

  if p_customer_id is null then
    raise exception 'customer_id required'
      using errcode = '22023';
  end if;

  select * into v_customer
    from public.customers
   where id = p_customer_id
     for update;

  if not found then
    raise exception 'customer % not found', p_customer_id
      using errcode = 'P0002';
  end if;

  if v_quote.chosen_package_id is not null
     and (v_quote.snapshot -> 'right' ->> 'id') = v_quote.chosen_package_id::text then
    v_chosen := v_quote.snapshot -> 'right';
  else
    v_chosen := v_quote.snapshot -> 'left';
  end if;

  v_visits := greatest(coalesce((v_chosen ->> 'visit_count')::int, 1), 1);
  v_paid   := greatest(v_quote.payable_krw, 0);

  select coalesce(sum(pr.extra_visits * coalesce(qp.qty, 1)), 0)
    into v_extra
    from public.program_quote_promos qp
    join public.program_promotions pr on pr.id = qp.promotion_id
   where qp.quote_id = p_quote_id;

  v_visits := v_visits + coalesce(v_extra, 0);
  v_unit := case when v_visits > 0 then (v_paid / v_visits) else 0 end;

  v_member := jsonb_build_object(
    'id', gen_random_uuid()::text,
    'service_name', coalesce(v_chosen ->> 'name', 'Program'),
    'total_visits', v_visits,
    'used_visits', 0,
    'paid_amount', v_paid,
    'per_session_value', v_unit
  );

  update public.customers
     set memberships = coalesce(memberships, '[]'::jsonb) || jsonb_build_array(v_member)
   where id = p_customer_id;

  update public.program_quotes
     set customer_id = p_customer_id,
         status = 'accepted',
         accepted_at = now()
   where id = p_quote_id
  returning to_jsonb(program_quotes.*) into v_chosen;

  return v_chosen;
end $function$
;

-- ---- public.ai_tool_period_key(timestamp with time zone)  secdef=false  md5=a3432a324bda79ea6c74c3f62f2123b4
CREATE OR REPLACE FUNCTION public.ai_tool_period_key(p_at timestamp with time zone DEFAULT now())
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select to_char(p_at at time zone 'Asia/Seoul', 'YYYY-MM');
$function$
;

-- ---- public.assert_chart_community_publishable(uuid)  secdef=true  md5=dc16af42bbcd231f503c9739850f6c9d
CREATE OR REPLACE FUNCTION public.assert_chart_community_publishable(p_chart_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_sig text;
  v_pdf text;
  v_marketing boolean;
  v_offline boolean;
begin
  if p_chart_id is null then
    raise exception 'chart_id required';
  end if;

  select
    coalesce(nullif(trim(signature_url), ''), ''),
    coalesce(nullif(trim(consent_pdf_url), ''), ''),
    coalesce(consent_marketing, false),
    coalesce(consent_offline_only, false)
  into v_sig, v_pdf, v_marketing, v_offline
  from public.customer_charts
  where id = p_chart_id;

  if not found then
    raise exception 'chart not found';
  end if;

  if v_sig = '' and v_pdf = '' then
    raise exception 'consent signature required';
  end if;

  if v_offline and not v_marketing then
    raise exception 'SNS marketing consent required';
  end if;

  if not v_marketing then
    raise exception 'SNS marketing consent required';
  end if;
end;
$function$
;

-- ---- public.bind_ba_session_to_chart(uuid,uuid,uuid)  secdef=true  md5=b061e85b563d3baac19aae83afedb7d5
CREATE OR REPLACE FUNCTION public.bind_ba_session_to_chart(p_session_id uuid, p_customer_id uuid, p_chart_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_session public.ba_capture_sessions;
  v_result  jsonb;
begin
  select * into v_session
    from public.ba_capture_sessions
   where id = p_session_id
     for update;

  if not found then
    raise exception 'ba_capture_session % not found', p_session_id
      using errcode = 'P0002';
  end if;

  if not exists (select 1 from public.customer_charts where id = p_chart_id) then
    raise exception 'customer_chart % not found', p_chart_id
      using errcode = 'P0002';
  end if;

  -- 1) 차트에 B/A URL 반영 (세션에 있는 값만 덮어씀)
  update public.customer_charts
     set before_image_url = coalesce(
           nullif(v_session.before_image_url, ''), before_image_url),
         after_image_url  = coalesce(
           nullif(v_session.after_image_url, ''), after_image_url),
         photo_meta = coalesce(photo_meta, '{}'::jsonb) || jsonb_build_object(
           'ba_session_id', p_session_id::text,
           'ba_bound_at', to_char(now() at time zone 'utc',
                                  'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         )
   where id = p_chart_id;

  -- 2) 세션 상태 전이 → is_complete 자동 true → 캐러셀 쿼리에서 이탈
  update public.ba_capture_sessions
     set customer_id = p_customer_id,
         chart_id    = p_chart_id,
         status      = 'linked',
         linked_at   = now()
   where id = p_session_id
  returning to_jsonb(ba_capture_sessions.*) into v_result;

  return v_result;
end $function$
;

-- ---- public.boost_feed_segment(text,uuid)  secdef=true  md5=6c246ce8be1c27508ddd9055d3955de6
CREATE OR REPLACE FUNCTION public.boost_feed_segment(p_target_type text, p_target_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_type text := lower(trim(coalesce(p_target_type, '')));
  v_post text;
begin
  if v_type = 'chart' then
    return 'case';
  end if;
  if v_type = 'community_post' and p_target_id is not null then
    select lower(trim(post_type)) into v_post
    from public.community_posts
    where id = p_target_id;
    if v_post in ('interior', 'device_review') then
      return v_post;
    end if;
    if v_post = 'case_share' then
      return 'case';
    end if;
  end if;
  return 'case';
end;
$function$
;

-- ---- public.bump_community_post_comment_count()  secdef=true  md5=37e619715c12d04af04eddd0f036617e
CREATE OR REPLACE FUNCTION public.bump_community_post_comment_count()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'INSERT' and new.status = 'published' then
    update public.community_posts
    set comment_count = coalesce(comment_count, 0) + 1,
        updated_at = now()
    where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update public.community_posts
    set comment_count = greatest(coalesce(comment_count, 0) - 1, 0),
        updated_at = now()
    where id = old.post_id;
  end if;
  return coalesce(new, old);
end;
$function$
;

-- ---- public.bump_shop_community_activity()  secdef=true  md5=88e44135c983b28592f4529b8f3e1980
CREATE OR REPLACE FUNCTION public.bump_shop_community_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_table_name = 'community_posts' then
    if new.status = 'published' and new.shop_id is not null then
      update public.shops
      set community_activity_score = coalesce(community_activity_score, 0) + 1,
          updated_at = now()
      where id = new.shop_id;
    end if;
  elsif tg_table_name = 'shop_posts' then
    if new.shop_id is not null then
      update public.shops
      set community_activity_score = coalesce(community_activity_score, 0) + 1,
          updated_at = now()
      where id = new.shop_id;
    end if;
  elsif tg_table_name = 'device_reviews' then
    -- device_reviews are 1:1 with community_posts; extra +1 for structured review effort
    update public.shops s
    set community_activity_score = coalesce(s.community_activity_score, 0) + 1,
        updated_at = now()
    from public.community_posts p
    where p.id = new.post_id and s.id = p.shop_id;
  end if;
  return new;
end;
$function$
;

-- ---- public.can_view_community_post_full(text,uuid,uuid,uuid)  secdef=true  md5=c1c699f93d15b60d080c5bcf13dd039a
CREATE OR REPLACE FUNCTION public.can_view_community_post_full(p_visibility text, p_shop_id uuid, p_author_user_id uuid, p_post_id uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(p_visibility, 'public') is distinct from 'gold_plus' then
    return true;
  end if;
  if auth.uid() is not null and p_author_user_id is not null
     and p_author_user_id = auth.uid() then
    return true;
  end if;
  if public.viewer_owns_shop(p_shop_id) then
    return true;
  end if;
  if p_post_id is not null and public.viewer_has_post_unlock(p_post_id) then
    return true;
  end if;
  return public.viewer_shop_tier_rank() >= 4;
end;
$function$
;

-- ---- public.can_view_community_post_full(text,uuid,uuid)  secdef=true  md5=7c221e1e5d6321a01fa62aed38e966dd
CREATE OR REPLACE FUNCTION public.can_view_community_post_full(p_visibility text, p_shop_id uuid, p_author_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(p_visibility, 'public') is distinct from 'gold_plus' then
    return true;
  end if;
  if auth.uid() is not null and p_author_user_id is not null
     and p_author_user_id = auth.uid() then
    return true;
  end if;
  if public.viewer_owns_shop(p_shop_id) then
    return true;
  end if;
  return public.viewer_shop_tier_rank() >= 4; -- gold+
end;
$function$
;

-- ---- public.can_view_whisper_post(uuid)  secdef=true  md5=2c2239b61ff3b56592be7f799ed26fd1
CREATE OR REPLACE FUNCTION public.can_view_whisper_post(p_post_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (
      select
        p.is_whisper = true
        and p.status = 'published'
        and auth.uid() is not null
        and (
          p.author_user_id = auth.uid()
          or exists (
            select 1
            from public.community_whisper_recipients r
            where r.post_id = p.id and r.user_id = auth.uid()
          )
          or (
            p.visibility = 'public'
            and coalesce(p.audience_spec -> 'atoms', '[]'::jsonb) ? 'everyone'
          )
        )
      from public.community_posts p
      where p.id = p_post_id
    ),
    false
  );
$function$
;

-- ---- public.complete_ai_tool_job(uuid,jsonb,text,text)  secdef=true  md5=c087ac102e7aaac62359fbad92a09181
CREATE OR REPLACE FUNCTION public.complete_ai_tool_job(p_job_id uuid, p_result jsonb, p_status text DEFAULT 'done'::text, p_error_message text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job public.ai_tool_jobs%rowtype;
  v_st text := lower(trim(coalesce(p_status, 'done')));
begin
  if p_job_id is null then
    raise exception 'job_id required';
  end if;
  if v_st not in ('done', 'failed') then
    raise exception 'invalid status %', v_st;
  end if;

  update public.ai_tool_jobs
  set
    status = v_st,
    result = case when v_st = 'done' then p_result else result end,
    error_message = nullif(trim(p_error_message), ''),
    completed_at = now()
  where id = p_job_id
  returning * into v_job;

  if not found then
    raise exception 'job not found';
  end if;

  return jsonb_build_object('ok', true, 'job', to_jsonb(v_job));
end;
$function$
;

-- ---- public.complete_market_escrow(uuid)  secdef=true  md5=1827f45b53d8753829e600cc5ce4314c
CREATE OR REPLACE FUNCTION public.complete_market_escrow(p_listing_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  update public.market_escrow_holds
  set status = 'completed', completed_at = now()
  where listing_id = p_listing_id and status = 'held'
  returning id into v_id;

  if v_id is null then
    raise exception 'no held escrow';
  end if;

  update public.market_listings
  set listing_status = 'sold',
      sold_at = now(),
      updated_at = now()
  where id = p_listing_id;

  return jsonb_build_object('ok', true, 'escrow_id', v_id, 'status', 'completed');
end;
$function$
;

-- ---- public.complete_settlement_withdraw(uuid)  secdef=true  md5=e7b61048acb8d8497304fe6068787166
CREATE OR REPLACE FUNCTION public.complete_settlement_withdraw(p_tx_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tx public.settlement_transactions%rowtype;
  v_wallet public.wallets%rowtype;
  v_amt int;
begin
  select * into v_tx from public.settlement_transactions
  where id = p_tx_id for update;
  if not found then
    raise exception 'settlement tx not found';
  end if;
  if v_tx.kind is distinct from 'withdraw_request' or v_tx.status is distinct from 'pending' then
    raise exception 'tx not a pending withdraw';
  end if;

  v_amt := abs(v_tx.amount);

  select * into v_wallet from public.wallets where shop_id = v_tx.shop_id for update;

  update public.wallets
  set settlement_pending = greatest(settlement_pending - v_amt, 0),
      settlement_paid_lifetime = settlement_paid_lifetime + v_amt,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  update public.settlement_transactions
  set status = 'paid',
      kind = 'withdraw_paid',
      updated_at = now(),
      balance_after = v_wallet.settlement_balance
  where id = p_tx_id
  returning * into v_tx;

  return to_jsonb(v_tx);
end;
$function$
;

-- ---- public.compute_platform_fee_pct(text)  secdef=false  md5=eb7ddfb097b8e11431aa2aa9c595726f
CREATE OR REPLACE FUNCTION public.compute_platform_fee_pct(p_tier_badge text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case lower(trim(replace(coalesce(p_tier_badge, 'none'), ' ', '_')))
    when 'grand_director' then 0.080
    when 'grand_master' then 0.100
    when 'master' then 0.110
    when 'mentor' then 0.120
    when 'diamond' then 0.135
    when 'platinum' then 0.140
    when 'gold' then 0.145
    when 'silver' then 0.150
    when 'bronze' then 0.150
    when 'iron' then 0.150
    else 0.150
  end;
$function$
;

-- ---- public.compute_shop_tier_badge(integer)  secdef=false  md5=ac4d649c76e63ba1d895fc064dc3e142
CREATE OR REPLACE FUNCTION public.compute_shop_tier_badge(p_shared_count integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  -- 레거시 시그니처 유지. 실제 승급은 update_shop_tier_badge 사용.
  select case
    when coalesce(p_shared_count, 0) >= 100 then 'diamond'
    when coalesce(p_shared_count, 0) >= 70 then 'platinum'
    when coalesce(p_shared_count, 0) >= 45 then 'gold'
    when coalesce(p_shared_count, 0) >= 25 then 'silver'
    when coalesce(p_shared_count, 0) >= 10 then 'bronze'
    when coalesce(p_shared_count, 0) >= 3 then 'iron'
    else 'none'
  end;
$function$
;

-- ---- public.convert_review_request_events(uuid,uuid,uuid)  secdef=true  md5=77e25bb6d25662fd6e8bf61f79b1edbe
CREATE OR REPLACE FUNCTION public.convert_review_request_events(p_customer_id uuid, p_review_id uuid, p_shop_id uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_count int := 0;
begin
  if v_uid is null or p_customer_id is null or p_review_id is null then
    return 0;
  end if;

  if v_shop is null then
    select shop_id into v_shop from public.customer_reviews where id = p_review_id;
  end if;
  if v_shop is null then
    return 0;
  end if;

  update public.review_request_events r
  set
    status = 'converted',
    converted_review_id = p_review_id,
    updated_at = now()
  where r.shop_id = v_shop
    and r.customer_id = p_customer_id
    and r.status in ('sent', 'opened')
    and r.converted_review_id is null;

  get diagnostics v_count = row_count;
  return coalesce(v_count, 0);
end;
$function$
;

-- ---- public.count_unread_whispers()  secdef=true  md5=cdb06673a20c530316a3ccb5667be1ea
CREATE OR REPLACE FUNCTION public.count_unread_whispers()
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_n int;
begin
  if v_uid is null then
    return 0;
  end if;
  select count(*)::int into v_n
  from public.whisper_recipients r
  join public.whispers w on w.id = r.whisper_id
  where r.user_id = v_uid and r.read_at is null and w.status = 'sent';
  return coalesce(v_n, 0);
end;
$function$
;

-- ---- public.create_market_listing_inquiry(uuid,text)  secdef=true  md5=8363d1d79dfb6063c2b3b0ab36fcae07
CREATE OR REPLACE FUNCTION public.create_market_listing_inquiry(p_listing_id uuid, p_message text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_listing public.market_listings%rowtype;
  v_msg text := trim(coalesce(p_message, ''));
  v_inquiry_id uuid;
  v_buyer_shop uuid;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_listing_id is null then
    raise exception 'listing_id required';
  end if;

  select * into v_listing
  from public.market_listings
  where id = p_listing_id;

  if not found then
    raise exception 'listing not found';
  end if;
  if v_listing.listing_status not in ('active', 'reserved') then
    raise exception 'listing not available';
  end if;
  if v_msg = '' then
    v_msg := '구매 문의드립니다.';
  end if;

  select p.shop_id into v_buyer_shop
  from public.profiles p
  where p.id = v_uid;

  insert into public.listing_inquiries (
    listing_id, buyer_shop_id, buyer_user_id, message
  ) values (
    p_listing_id, v_buyer_shop, v_uid, v_msg
  )
  returning id into v_inquiry_id;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_listing.shop_id,
    'market_inquiry',
    '중고 거래 문의',
    left(v_msg, 120),
    jsonb_build_object(
      'listing_id', p_listing_id,
      'inquiry_id', v_inquiry_id,
      'device_name', v_listing.device_name
    )
  );

  return jsonb_build_object(
    'ok', true,
    'inquiry_id', v_inquiry_id,
    'listing_id', p_listing_id
  );
end;
$function$
;

-- ---- public.create_mentoring_request(uuid,text)  secdef=true  md5=5d30769e62e4559d5d5131bc53e1d003
CREATE OR REPLACE FUNCTION public.create_mentoring_request(p_chart_id uuid, p_question_body text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_chart public.customer_charts%rowtype;
  v_requestor_shop uuid;
  v_req public.mentoring_requests%rowtype;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if char_length(trim(coalesce(p_question_body, ''))) < 20 then
    raise exception 'question too short';
  end if;

  select * into v_chart from public.customer_charts where id = p_chart_id;
  if not found then raise exception 'chart not found'; end if;

  select s.id into v_requestor_shop
  from public.shops s
  join public.profiles p on p.id = s.owner_user_id
  where p.id = v_uid
  limit 1;

  if v_requestor_shop is null then raise exception 'requestor shop not found'; end if;
  if v_requestor_shop = v_chart.shop_id then
    raise exception 'cannot request mentoring on own case';
  end if;

  insert into public.mentoring_requests (
    chart_id, requestor_shop_id, requestor_user_id, question_body
  ) values (
    p_chart_id, v_requestor_shop, v_uid, trim(p_question_body)
  )
  returning * into v_req;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_chart.shop_id,
    'mentoring_request_received',
    'Mentoring request received',
    left(trim(p_question_body), 120),
    jsonb_build_object(
      'request_id', v_req.id,
      'chart_id', p_chart_id,
      'requestor_shop_id', v_requestor_shop
    )
  );

  return jsonb_build_object('ok', true, 'request_id', v_req.id);
end;
$function$
;

-- ---- public.credit_free_echo_capped(uuid,integer,text,text,uuid,text)  secdef=true  md5=c907b594172e1a80bdaab01a27839d6c
CREATE OR REPLACE FUNCTION public.credit_free_echo_capped(p_shop_id uuid, p_amount integer, p_kind text, p_ref_type text DEFAULT ''::text, p_ref_id uuid DEFAULT NULL::uuid, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_want int := greatest(coalesce(p_amount, 0), 0);
  v_kind text := lower(trim(coalesce(p_kind, '')));
  v_month_key text := public.echo_period_key('month');
  v_week_key text := public.echo_period_key('week');
  v_day_key text := public.echo_period_key('day');
  v_month_used int := 0;
  v_kind_used int := 0;
  v_month_cap int := 70;
  v_kind_cap int := 0;
  v_period_type text := 'week';
  v_period_key text;
  v_grant int;
  v_tx public.point_transactions%rowtype;
begin
  if p_shop_id is null or v_want <= 0 then
    return jsonb_build_object('ok', false, 'granted', 0, 'reason', 'noop');
  end if;

  v_kind_cap := case v_kind
    when 'earn_case_share' then 15      -- 5E × 3/week
    when 'earn_review' then 10         -- 5E × 2/week (device) / interior shares budget
    when 'earn_comment' then 5         -- 1E × 5/day
    when 'earn_best_comment' then 15   -- 3E × 5/week
    else 10
  end;

  v_period_type := case when v_kind = 'earn_comment' then 'day' else 'week' end;
  v_period_key := case when v_kind = 'earn_comment' then v_day_key else v_week_key end;

  select coalesce(sum(amount), 0) into v_month_used
  from public.echo_earn_quota
  where shop_id = p_shop_id
    and period_type = 'month'
    and period_key = v_month_key;

  select coalesce(amount, 0) into v_kind_used
  from public.echo_earn_quota
  where shop_id = p_shop_id
    and period_type = v_period_type
    and period_key = v_period_key
    and kind = v_kind;

  v_grant := least(
    v_want,
    greatest(v_month_cap - v_month_used, 0),
    greatest(v_kind_cap - v_kind_used, 0)
  );

  if v_grant <= 0 then
    return jsonb_build_object(
      'ok', true,
      'granted', 0,
      'capped', true,
      'month_used', v_month_used,
      'kind_used', v_kind_used,
      'reason', 'faucet_cap'
    );
  end if;

  v_tx := public.credit_points(
    p_shop_id, v_grant, 'free', v_kind,
    coalesce(p_ref_type, ''), p_ref_id, null, coalesce(p_note, '')
  );

  insert into public.echo_earn_quota as q (
    shop_id, period_type, period_key, kind, amount, updated_at
  ) values
    (p_shop_id, 'month', v_month_key, '_total', v_grant, now()),
    (p_shop_id, v_period_type, v_period_key, v_kind, v_grant, now())
  on conflict (shop_id, period_type, period_key, kind) do update
    set amount = q.amount + excluded.amount,
        updated_at = now();

  return jsonb_build_object(
    'ok', true,
    'granted', v_grant,
    'requested', v_want,
    'capped', v_grant < v_want,
    'month_used', v_month_used + v_grant,
    'tx_id', v_tx.id
  );
end;
$function$
;

-- ---- public.credit_free_echo_customer(uuid,integer,text,text,uuid,text)  secdef=true  md5=2edf36713ef0f2cd6d47af27646365a7
CREATE OR REPLACE FUNCTION public.credit_free_echo_customer(p_customer_id uuid, p_amount integer, p_kind text, p_ref_type text DEFAULT ''::text, p_ref_id uuid DEFAULT NULL::uuid, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_want int := greatest(coalesce(p_amount, 0), 0);
  v_kind text := lower(trim(coalesce(p_kind, '')));
  v_month_key text := public.echo_period_key('month');
  v_week_key text := public.echo_period_key('week');
  v_month_used int := 0;
  v_kind_used int := 0;
  v_month_cap int := 25; -- B2C hard cap
  v_kind_cap int := 0;
  v_grant int;
  v_wallet public.wallets%rowtype;
  v_tx public.point_transactions%rowtype;
begin
  if p_customer_id is null or v_want <= 0 then
    return jsonb_build_object('ok', false, 'granted', 0, 'reason', 'noop');
  end if;

  -- kind caps (monthly-ish via week for sparse missions)
  v_kind_cap := case v_kind
    when 'earn_review' then 10   -- 5E × 2/mo tracked as week budget
    when 'earn_visit' then 12    -- 3E × 4/mo
    when 'earn_qa' then 6        -- 2E × 3/week
    else 5
  end;

  select coalesce(sum(amount), 0) into v_month_used
  from public.echo_earn_quota_customer
  where customer_id = p_customer_id
    and period_type = 'month'
    and period_key = v_month_key
    and kind = '_total';

  select coalesce(amount, 0) into v_kind_used
  from public.echo_earn_quota_customer
  where customer_id = p_customer_id
    and period_type = 'week'
    and period_key = v_week_key
    and kind = v_kind;

  v_grant := least(
    v_want,
    greatest(v_month_cap - v_month_used, 0),
    greatest(v_kind_cap - v_kind_used, 0)
  );

  if v_grant <= 0 then
    return jsonb_build_object(
      'ok', true, 'granted', 0, 'capped', true,
      'month_used', v_month_used, 'reason', 'faucet_cap'
    );
  end if;

  v_wallet := public.ensure_customer_wallet(p_customer_id);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  update public.wallets
  set point_free_balance = point_free_balance + v_grant,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  insert into public.point_transactions (
    wallet_id, shop_id, customer_id, amount, bucket, kind,
    ref_type, ref_id, note,
    balance_point_free_after, balance_point_paid_after
  ) values (
    v_wallet.id, v_wallet.shop_id, p_customer_id, v_grant, 'free', v_kind,
    coalesce(p_ref_type, ''), p_ref_id, coalesce(p_note, ''),
    v_wallet.point_free_balance, v_wallet.point_paid_balance
  )
  returning * into v_tx;

  insert into public.echo_earn_quota_customer as q (
    customer_id, period_type, period_key, kind, amount, updated_at
  ) values
    (p_customer_id, 'month', v_month_key, '_total', v_grant, now()),
    (p_customer_id, 'week', v_week_key, v_kind, v_grant, now())
  on conflict (customer_id, period_type, period_key, kind) do update
    set amount = q.amount + excluded.amount,
        updated_at = now();

  return jsonb_build_object(
    'ok', true,
    'granted', v_grant,
    'requested', v_want,
    'capped', v_grant < v_want,
    'month_used', v_month_used + v_grant,
    'point_free_balance', v_wallet.point_free_balance,
    'settlement_balance', v_wallet.settlement_balance
  );
end;
$function$
;

-- ---- public.credit_points(uuid,integer,text,text,text,uuid,uuid,text)  secdef=true  md5=f0b6c9b6c70476a0f42f1f150e528cb8
CREATE OR REPLACE FUNCTION public.credit_points(p_shop_id uuid, p_amount integer, p_bucket text, p_kind text, p_ref_type text DEFAULT ''::text, p_ref_id uuid DEFAULT NULL::uuid, p_counterparty_shop_id uuid DEFAULT NULL::uuid, p_note text DEFAULT ''::text)
 RETURNS point_transactions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_wallet public.wallets%rowtype;
  v_tx public.point_transactions%rowtype;
  v_bucket text := lower(trim(coalesce(p_bucket, 'free')));
  v_kind text := lower(trim(coalesce(p_kind, '')));
begin
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'credit amount must be > 0';
  end if;
  if v_bucket not in ('free', 'paid') then
    raise exception 'invalid point bucket';
  end if;
  -- Hard lock: never credit settlement via point RPC
  if v_kind in ('withdraw', 'withdraw_request', 'withdraw_paid', 'market_sale',
                'affiliate_payout', 'seminar_settle', 'payout') then
    raise exception 'kind % forbidden on point ledger', v_kind;
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);

  update public.wallets
  set point_free_balance = case when v_bucket = 'free'
        then point_free_balance + p_amount else point_free_balance end,
      point_paid_balance = case when v_bucket = 'paid'
        then point_paid_balance + p_amount else point_paid_balance end,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  insert into public.point_transactions (
    wallet_id, shop_id, amount, bucket, kind,
    ref_type, ref_id, counterparty_shop_id, note,
    balance_point_free_after, balance_point_paid_after
  ) values (
    v_wallet.id, p_shop_id, p_amount, v_bucket, p_kind,
    coalesce(p_ref_type, ''), p_ref_id, p_counterparty_shop_id,
    coalesce(p_note, ''),
    v_wallet.point_free_balance, v_wallet.point_paid_balance
  )
  returning * into v_tx;

  return v_tx;
end;
$function$
;

-- ---- public.credit_settlement(uuid,integer,text,text,uuid,text)  secdef=true  md5=36bf70a39d59d78b51ee4dd3aece267c
CREATE OR REPLACE FUNCTION public.credit_settlement(p_shop_id uuid, p_amount integer, p_kind text, p_ref_type text DEFAULT ''::text, p_ref_id uuid DEFAULT NULL::uuid, p_note text DEFAULT ''::text)
 RETURNS settlement_transactions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_wallet public.wallets%rowtype;
  v_tx public.settlement_transactions%rowtype;
  v_kind text := lower(trim(coalesce(p_kind, '')));
begin
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'settlement credit must be > 0';
  end if;
  if v_kind not in (
    'market_sale', 'affiliate_payout', 'seminar_settle',
    'withdraw_reject', 'adjust'
  ) then
    raise exception 'kind % not allowed on settlement credit', v_kind;
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  update public.wallets
  set settlement_balance = settlement_balance + p_amount,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  -- Keep legacy column roughly in sync for seminar UI
  update public.shops
  set sori_cash_balance = v_wallet.settlement_balance,
      updated_at = now()
  where id = p_shop_id;

  insert into public.settlement_transactions (
    wallet_id, shop_id, amount, kind, status,
    ref_type, ref_id, note, balance_after
  ) values (
    v_wallet.id, p_shop_id, p_amount, v_kind, 'posted',
    coalesce(p_ref_type, ''), p_ref_id, coalesce(p_note, ''),
    v_wallet.settlement_balance
  )
  returning * into v_tx;

  return v_tx;
end;
$function$
;

-- ---- public.debit_echo_wallet(uuid,integer,text,text,uuid,text,uuid)  secdef=true  md5=a5796173ac992f13cc87c5637b031724
CREATE OR REPLACE FUNCTION public.debit_echo_wallet(p_wallet_id uuid, p_amount integer, p_kind text, p_ref_type text DEFAULT ''::text, p_ref_id uuid DEFAULT NULL::uuid, p_note text DEFAULT ''::text, p_ledger_shop_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_wallet public.wallets%rowtype;
  v_need int := coalesce(p_amount, 0);
  v_from_free int := 0;
  v_from_paid int := 0;
  v_total int;
  v_tx_id uuid;
  v_kind text := lower(trim(coalesce(p_kind, '')));
  v_settlement_before int;
  v_shop uuid;
begin
  if v_need <= 0 then
    raise exception 'debit amount must be > 0';
  end if;
  if v_kind like 'withdraw%' or v_kind in ('market_sale', 'affiliate_payout', 'seminar_settle') then
    raise exception 'kind % forbidden on echo ledger', v_kind;
  end if;

  select * into v_wallet from public.wallets where id = p_wallet_id for update;
  if not found then
    raise exception 'wallet not found';
  end if;

  v_settlement_before := v_wallet.settlement_balance;
  v_total := v_wallet.point_free_balance + v_wallet.point_paid_balance;
  if v_total < v_need then
    raise exception 'insufficient points: have %, need %', v_total, v_need
      using errcode = 'P0001';
  end if;

  v_from_free := least(v_wallet.point_free_balance, v_need);
  v_from_paid := v_need - v_from_free;

  update public.wallets
  set point_free_balance = point_free_balance - v_from_free,
      point_paid_balance = point_paid_balance - v_from_paid,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  if v_wallet.settlement_balance is distinct from v_settlement_before then
    raise exception 'settlement_balance must not change on echo debit';
  end if;

  v_shop := coalesce(p_ledger_shop_id, v_wallet.shop_id);

  if v_from_free > 0 then
    insert into public.point_transactions (
      wallet_id, shop_id, customer_id, amount, bucket, kind,
      ref_type, ref_id, note,
      balance_point_free_after, balance_point_paid_after
    ) values (
      v_wallet.id, v_shop, v_wallet.customer_id, -v_from_free, 'free', v_kind,
      coalesce(p_ref_type, ''), p_ref_id, coalesce(p_note, ''),
      v_wallet.point_free_balance, v_wallet.point_paid_balance
    )
    returning id into v_tx_id;
  end if;

  if v_from_paid > 0 then
    insert into public.point_transactions (
      wallet_id, shop_id, customer_id, amount, bucket, kind,
      ref_type, ref_id, note,
      balance_point_free_after, balance_point_paid_after
    ) values (
      v_wallet.id, v_shop, v_wallet.customer_id, -v_from_paid, 'paid', v_kind,
      coalesce(p_ref_type, ''), p_ref_id, coalesce(p_note, ''),
      v_wallet.point_free_balance, v_wallet.point_paid_balance
    )
    returning id into v_tx_id;
  end if;

  return jsonb_build_object(
    'wallet_id', v_wallet.id,
    'spent', v_need,
    'from_free', v_from_free,
    'from_paid', v_from_paid,
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'settlement_balance', v_wallet.settlement_balance,
    'tx_id', v_tx_id
  );
end;
$function$
;

-- ---- public.debit_points(uuid,integer,text,text,uuid,uuid,text)  secdef=true  md5=0ab8f9c237f19cb3f8bd947c1e6eac33
CREATE OR REPLACE FUNCTION public.debit_points(p_shop_id uuid, p_amount integer, p_kind text, p_ref_type text DEFAULT ''::text, p_ref_id uuid DEFAULT NULL::uuid, p_counterparty_shop_id uuid DEFAULT NULL::uuid, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_wallet public.wallets%rowtype;
  v_need int := coalesce(p_amount, 0);
  v_from_free int := 0;
  v_from_paid int := 0;
  v_total int;
  v_ids uuid[] := '{}';
  v_tx_id uuid;
  v_kind text := lower(trim(coalesce(p_kind, '')));
begin
  if v_need <= 0 then
    raise exception 'debit amount must be > 0';
  end if;
  if v_kind like 'withdraw%' or v_kind in ('market_sale', 'affiliate_payout', 'seminar_settle') then
    raise exception 'kind % forbidden on point ledger — use settlement RPC', v_kind;
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  v_total := v_wallet.point_free_balance + v_wallet.point_paid_balance;
  if v_total < v_need then
    raise exception 'insufficient points: have %, need %', v_total, v_need
      using errcode = 'P0001';
  end if;

  v_from_free := least(v_wallet.point_free_balance, v_need);
  v_from_paid := v_need - v_from_free;

  update public.wallets
  set point_free_balance = point_free_balance - v_from_free,
      point_paid_balance = point_paid_balance - v_from_paid,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  if v_from_free > 0 then
    insert into public.point_transactions (
      wallet_id, shop_id, amount, bucket, kind,
      ref_type, ref_id, counterparty_shop_id, note,
      balance_point_free_after, balance_point_paid_after
    ) values (
      v_wallet.id, p_shop_id, -v_from_free, 'free', p_kind,
      coalesce(p_ref_type, ''), p_ref_id, p_counterparty_shop_id,
      coalesce(p_note, ''),
      v_wallet.point_free_balance, v_wallet.point_paid_balance
    )
    returning id into v_tx_id;
    v_ids := array_append(v_ids, v_tx_id);
  end if;

  if v_from_paid > 0 then
    insert into public.point_transactions (
      wallet_id, shop_id, amount, bucket, kind,
      ref_type, ref_id, counterparty_shop_id, note,
      balance_point_free_after, balance_point_paid_after
    ) values (
      v_wallet.id, p_shop_id, -v_from_paid, 'paid', p_kind,
      coalesce(p_ref_type, ''), p_ref_id, p_counterparty_shop_id,
      coalesce(p_note, ''),
      v_wallet.point_free_balance, v_wallet.point_paid_balance
    )
    returning id into v_tx_id;
    v_ids := array_append(v_ids, v_tx_id);
  end if;

  return jsonb_build_object(
    'shop_id', p_shop_id,
    'spent', v_need,
    'from_free', v_from_free,
    'from_paid', v_from_paid,
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'tx_ids', to_jsonb(v_ids)
  );
end;
$function$
;

-- ---- public.delete_shop_customers(uuid[])  secdef=true  md5=2ff5aa2566325e55dfb21ca52b9d838d
CREATE OR REPLACE FUNCTION public.delete_shop_customers(p_ids uuid[])
 RETURNS uuid[]
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_owned uuid[];
  v_deleted uuid[];
begin
  if p_ids is null or coalesce(cardinality(p_ids), 0) = 0 then
    return array[]::uuid[];
  end if;

  if cardinality(p_ids) > 50 then
    raise exception '한 번에 최대 50명까지 삭제할 수 있습니다.';
  end if;

  if v_uid is null then
    raise exception '로그인이 필요합니다. (auth.uid is null)';
  end if;

  select coalesce(array_agg(c.id), array[]::uuid[])
  into v_owned
  from public.customers c
  inner join public.shops s on s.id = c.shop_id
  where c.id = any (p_ids)
    and s.owner_user_id = v_uid;

  if coalesce(cardinality(v_owned), 0) = 0 then
    return array[]::uuid[];
  end if;

  begin
    delete from public.membership_tickets
    where customer_id = any (v_owned);
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.care_diary_notes
    where customer_id = any (v_owned);
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.shop_followers
    where customer_id = any (v_owned);
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.customer_reviews
    where customer_id = any (v_owned);
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.customer_charts
    where customer_id = any (v_owned);
  exception
    when undefined_table then null;
  end;

  with removed as (
    delete from public.customers
    where id = any (v_owned)
    returning id
  )
  select coalesce(array_agg(id), array[]::uuid[])
  into v_deleted
  from removed;

  return coalesce(v_deleted, array[]::uuid[]);
end;
$function$
;

-- ---- public.earn_echo_on_customer_qa_post()  secdef=true  md5=7f8f7b02ea24574dea59eb72aeaec930
CREATE OR REPLACE FUNCTION public.earn_echo_on_customer_qa_post()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_customer uuid;
begin
  if new.status = 'published'
     and new.author_user_id is not null
     and char_length(trim(coalesce(new.body, ''))) >= 60 then
    select c.id into v_customer
    from public.customers c
    where c.user_id = new.author_user_id
    order by c.updated_at desc nulls last
    limit 1;
    if v_customer is not null then
      perform public.credit_free_echo_customer(
        v_customer, 2, 'earn_qa',
        'community_post', new.id,
        '피부 고민 Q&A +2 Echo'
      );
    end if;
  end if;
  return new;
end;
$function$
;

-- ---- public.earn_echo_on_customer_review()  secdef=true  md5=7eaf7a92821f087203cc9dac6d4b28d1
CREATE OR REPLACE FUNCTION public.earn_echo_on_customer_review()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_text text;
begin
  if tg_op = 'INSERT'
     or (tg_op = 'UPDATE' and old.status is distinct from new.status) then
    if new.status in ('published', 'accepted') and new.customer_id is not null then
      v_text := coalesce(new.original_text, '');
      if char_length(trim(v_text)) >= 80 then
        perform public.credit_free_echo_customer(
          new.customer_id, 5, 'earn_review',
          'customer_review', new.id,
          '시술 B/A 리뷰 +5 Echo'
        );
      end if;
    end if;
  end if;
  return new;
end;
$function$
;

-- ---- public.earn_echo_on_visit_checked()  secdef=true  md5=1251c4b71c2dd809cca8acf03302c6ad
CREATE OR REPLACE FUNCTION public.earn_echo_on_visit_checked()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.visit_checked = true
     and (tg_op = 'INSERT' or coalesce(old.visit_checked, false) = false)
     and new.customer_id is not null then
    perform public.credit_free_echo_customer(
      new.customer_id, 3, 'earn_visit',
      'customer_chart', new.id,
      '방문 완료 +3 Echo'
    );
  end if;
  return new;
end;
$function$
;

-- ---- public.earn_points_on_community_content()  secdef=true  md5=66c202d64939ed3b590141e5bae65f1f
CREATE OR REPLACE FUNCTION public.earn_points_on_community_content()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_table_name = 'community_posts' then
    if new.status = 'published' and new.shop_id is not null then
      if new.post_type = 'case_share' then
        perform public.credit_free_echo_capped(
          new.shop_id, 5, 'earn_case_share',
          'community_post', new.id, '임상 차트 공유 +5 Echo'
        );
      elsif new.post_type = 'device_review' then
        perform public.credit_free_echo_capped(
          new.shop_id, 5, 'earn_review',
          'community_post', new.id, '기기 리뷰 +5 Echo'
        );
      elsif new.post_type = 'interior' then
        perform public.credit_free_echo_capped(
          new.shop_id, 3, 'earn_review',
          'community_post', new.id, '인테리어/노하우 +3 Echo'
        );
      end if;
    end if;
  elsif tg_table_name = 'community_comments' then
    if new.status = 'published' and new.author_shop_id is not null then
      perform public.credit_free_echo_capped(
        new.author_shop_id, 1, 'earn_comment',
        'community_comment', new.id, '댓글 +1 Echo'
      );
    end if;
  end if;
  return new;
end;
$function$
;

-- ---- public.echo_period_key(text,timestamp with time zone)  secdef=false  md5=38ecb9db58bca8df0cfdfdfa1fe006ac
CREATE OR REPLACE FUNCTION public.echo_period_key(p_type text, p_at timestamp with time zone DEFAULT now())
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select case lower(p_type)
    when 'day' then to_char(p_at at time zone 'Asia/Seoul', 'YYYY-MM-DD')
    when 'week' then to_char(p_at at time zone 'Asia/Seoul', 'IYYY-"W"IW')
    when 'month' then to_char(p_at at time zone 'Asia/Seoul', 'YYYY-MM')
    else to_char(p_at at time zone 'Asia/Seoul', 'YYYY-MM')
  end;
$function$
;

-- ---- public.enforce_shop_gallery_limit()  secdef=false  md5=d573fb28055edea9aec16c6b10671817
CREATE OR REPLACE FUNCTION public.enforce_shop_gallery_limit()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_count int;
begin
  select count(*) into v_count
  from public.shop_gallery_items
  where shop_id = new.shop_id;
  if v_count >= 20 then
    raise exception '샵 갤러리는 최대 20장까지 등록할 수 있습니다.';
  end if;
  return new;
end;
$function$
;

-- ---- public.enroll_seminar_class(uuid,uuid)  secdef=true  md5=81d1453aadf45306b2128653fc8a75f8
CREATE OR REPLACE FUNCTION public.enroll_seminar_class(p_class_id uuid, p_enrollor_shop_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_class public.seminar_classes%rowtype;
  v_enrollment_id uuid;
begin
  select * into v_class
  from public.seminar_classes
  where id = p_class_id
  for update;

  if not found then
    raise exception 'class not found';
  end if;

  if v_class.status not in ('open', 'held') then
    raise exception 'class not enrollable';
  end if;

  if v_class.current_enrollment >= v_class.max_capacity then
    raise exception 'class full';
  end if;

  insert into public.seminar_enrollments (
    class_id,
    enrollor_shop_id,
    amount,
    status
  )
  values (
    p_class_id,
    p_enrollor_shop_id,
    v_class.price,
    'held'
  )
  returning id into v_enrollment_id;

  update public.seminar_classes
  set
    current_enrollment = current_enrollment + 1,
    status = case
      when current_enrollment + 1 >= max_capacity then 'held'
      else status
    end,
    updated_at = now()
  where id = p_class_id;

  return v_enrollment_id;
end;
$function$
;

-- ---- public.ensure_customer_wallet(uuid)  secdef=true  md5=a36387f7d5b9a2fb1ce22680b646ae38
CREATE OR REPLACE FUNCTION public.ensure_customer_wallet(p_customer_id uuid)
 RETURNS wallets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.wallets%rowtype;
  v_user uuid;
  v_shop uuid;
begin
  if p_customer_id is null then
    raise exception 'customer_id required';
  end if;

  select * into v_row
  from public.wallets
  where owner_type = 'customer' and customer_id = p_customer_id;
  if found then
    return v_row;
  end if;

  select user_id, shop_id into v_user, v_shop
  from public.customers where id = p_customer_id;
  if not found then
    raise exception 'customer not found';
  end if;

  insert into public.wallets (
    shop_id, owner_user_id, owner_type, customer_id
  )
  select v_shop, v_user, 'customer', p_customer_id
  where not exists (
    select 1 from public.wallets
    where owner_type = 'customer' and customer_id = p_customer_id
  );

  select * into v_row
  from public.wallets
  where owner_type = 'customer' and customer_id = p_customer_id;

  return v_row;
end;
$function$
;

-- ---- public.ensure_shop_wallet(uuid)  secdef=true  md5=f6a58ce62084b6efd9041d93720cadb2
CREATE OR REPLACE FUNCTION public.ensure_shop_wallet(p_shop_id uuid)
 RETURNS wallets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.wallets%rowtype;
  v_owner uuid;
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  select * into v_row
  from public.wallets
  where owner_type = 'shop' and shop_id = p_shop_id;
  if found then
    return v_row;
  end if;

  select owner_user_id into v_owner from public.shops where id = p_shop_id;

  insert into public.wallets (shop_id, owner_user_id, owner_type)
  select p_shop_id, v_owner, 'shop'
  where not exists (
    select 1 from public.wallets
    where owner_type = 'shop' and shop_id = p_shop_id
  );

  select * into v_row
  from public.wallets
  where owner_type = 'shop' and shop_id = p_shop_id;

  return v_row;
end;
$function$
;

-- ---- public.expire_mentoring_enhancement_grace()  secdef=true  md5=9c9ce22836ec143dc0fc7640b3295190
CREATE OR REPLACE FUNCTION public.expire_mentoring_enhancement_grace()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_count int := 0;
begin
  update public.mentoring_posts mp
  set
    status = 'purchase_disabled',
    updated_at = now()
  where mp.status = 'enhancement_required'
    and mp.enhancement_deadline_at is not null
    and now() > mp.enhancement_deadline_at
    and coalesce(mp.last_body_updated_at, mp.published_at, mp.created_at)
        <= mp.enhancement_started_at;

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$
;

-- ---- public.expire_stale_boost_placements()  secdef=true  md5=d07968b3eedb2558fc6ceaebface52e3
CREATE OR REPLACE FUNCTION public.expire_stale_boost_placements()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_n int;
begin
  update public.boost_placements
  set status = 'expired', updated_at = now()
  where status = 'active' and ends_at <= now();
  get diagnostics v_n = row_count;
  return coalesce(v_n, 0);
end;
$function$
;

-- ---- public.expire_stale_premium_overlays()  secdef=true  md5=189070121ba7ac872f35e531dee2e207
CREATE OR REPLACE FUNCTION public.expire_stale_premium_overlays()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_n int;
begin
  update public.boost_premium_overlays
  set status = 'expired'
  where status = 'active' and ends_at <= now();
  get diagnostics v_n = row_count;
  return v_n;
end;
$function$
;

-- ---- public.fan_boost_apply_fill(uuid,jsonb,uuid)  secdef=true  md5=a914e33f7d3c90e5efc6b3edafc9b1cf
CREATE OR REPLACE FUNCTION public.fan_boost_apply_fill(p_chart_id uuid, p_fill jsonb, p_fan_gift_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_chart public.customer_charts%rowtype;
  v_post public.community_posts%rowtype;
  v_body text := trim(coalesce(p_fill->>'body', ''));
  v_clinical text := trim(coalesce(p_fill->>'clinical_report', ''));
  v_title text := trim(coalesce(p_fill->>'title', ''));
  v_combined text;
  v_post_id uuid;
begin
  if p_chart_id is null or v_body = '' then
    return jsonb_build_object('ok', false, 'reason', 'empty_fill');
  end if;

  select * into v_chart from public.customer_charts where id = p_chart_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'chart_not_found');
  end if;

  v_combined := v_body;
  if v_clinical <> '' then
    v_combined := v_body || E'\n\n' || v_clinical;
  end if;

  update public.customer_charts
  set
    treatment_summary = v_body,
    director_insight = case
      when v_clinical <> '' then v_clinical
      else director_insight
    end,
    updated_at = now()
  where id = p_chart_id;

  select p.*
  into v_post
  from public.community_posts p
  where p.source_chart_id = p_chart_id
    and p.status = 'published'
  order by p.created_at desc
  limit 1;

  if found then
    update public.community_posts
    set
      title = case when v_title <> '' then v_title else title end,
      body = v_combined,
      ai_generated_body = v_combined,
      ai_generated_at = now(),
      ai_model = coalesce(p_fill->>'source', 'fan_boost_fill_sync'),
      body_source = 'fan_boost_fill',
      ai_filled_by_fan_gift_id = coalesce(p_fan_gift_id, ai_filled_by_fan_gift_id),
      updated_at = now()
    where id = v_post.id
    returning id into v_post_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'chart_id', p_chart_id,
    'community_post_id', v_post_id,
    'body_length', length(v_combined)
  );
end;
$function$
;

-- ---- public.fan_boost_build_fill_copy(customer_charts,customers)  secdef=false  md5=eb65c3c1d5c4bc648a20af5eaa267bd3
CREATE OR REPLACE FUNCTION public.fan_boost_build_fill_copy(p_chart customer_charts, p_customer customers DEFAULT NULL::customers)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
  v_care text := coalesce(nullif(trim(p_chart.care_name), ''), '케어');
  v_concern text;
  v_chips text[];
  v_who text := '';
  v_age int;
  v_device text := nullif(trim(coalesce(p_chart.device_info, '')), '');
  v_insight text := coalesce(
    nullif(trim(p_chart.director_insight), ''),
    nullif(trim(p_chart.treatment_summary), ''),
    ''
  );
  v_body text;
  v_clinical text;
  v_title text;
begin
  v_chips := coalesce(p_chart.concern_chips, '{}'::text[]);
  v_concern := coalesce(
    nullif(v_chips[1], ''),
    '피부 컨디션'
  );

  if p_customer is not null and p_customer.birth_date is not null then
    v_age := extract(year from age(current_date, p_customer.birth_date::date))::int;
    if v_age between 0 and 120 then
      if v_age < 20 then
        v_who := '10대';
      elsif v_age < 30 then
        v_who := '20대';
      elsif v_age < 40 then
        v_who := '30대';
      elsif v_age < 50 then
        v_who := '40대';
      else
        v_who := '50대 이상';
      end if;
    end if;
    if coalesce(p_customer.gender, '') ilike any (array['female', 'f', '여', '여성']) then
      v_who := trim(v_who || ' 여성');
    elsif coalesce(p_customer.gender, '') ilike any (array['male', 'm', '남', '남성']) then
      v_who := trim(v_who || ' 남성');
    end if;
  end if;
  if v_who = '' then
    v_who := '고객';
  end if;

  v_body := format(
    '%s 분의 %s 고민에 맞춰 %s를 진행했습니다.%s %s',
    v_who,
    v_concern,
    v_care,
    case when v_device is not null then ' ' || v_device || '를 활용해' else '' end,
    case
      when v_insight <> '' then left(v_insight, 200)
      else '시술 전후 변화를 기록해 두었습니다. 개인 식별 정보는 포함되지 않습니다.'
    end
  );

  v_clinical := format(
    '【임상 참고 · 의료 진단 아님】 시술 %s, 주요 고민 %s.%s 원장 메모: %s',
    v_care,
    coalesce(nullif(array_to_string(v_chips, ', '), ''), '피부 컨디션'),
    case when v_device is not null then ' 사용 기기: ' || v_device || '.' else '' end,
    case when v_insight <> '' then left(v_insight, 200) else '추가 관찰 기록 없음.' end
  );

  v_title := left(v_care || ' · 임상 케이스', 28);

  return jsonb_build_object(
    'title', v_title,
    'body', v_body,
    'clinical_report', v_clinical,
    'hashtags', jsonb_build_array('#SORI', '#비포애프터', '#에스테틱'),
    'source', 'fan_boost_fill_sync'
  );
end;
$function$
;

-- ---- public.feed_seed_rank(text,text)  secdef=false  md5=126ce995dd0aa27567571383d9d287a7
CREATE OR REPLACE FUNCTION public.feed_seed_rank(p_seed text, p_id text)
 RETURNS double precision
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select abs(('x' || substr(md5(coalesce(p_seed, '') || ':' || coalesce(p_id, '')), 1, 8))::bit(32)::int
    / 2147483647.0::double precision);
$function$
;

-- ---- public.feed_viewer_seed(text,text,timestamp with time zone)  secdef=false  md5=fb103a68f12de1ced42d5b9c4ff28b72
CREATE OR REPLACE FUNCTION public.feed_viewer_seed(p_viewer_id text DEFAULT ''::text, p_segment text DEFAULT 'case'::text, p_at timestamp with time zone DEFAULT now())
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  select concat_ws(
    '|',
    nullif(trim(coalesce(p_viewer_id, '')), ''),
    lower(trim(coalesce(p_segment, 'case'))),
    (floor(extract(epoch from coalesce(p_at, now())) / 3600))::text
  );
$function$
;

-- ---- public.get_ai_tool_quota(uuid)  secdef=true  md5=9294bbd3ce9be5fd428df63d3d9fc987
CREATE OR REPLACE FUNCTION public.get_ai_tool_quota(p_shop_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_key text := public.ai_tool_period_key();
  v_used int := 0;
  v_limit int := 5;
begin
  if p_shop_id is null then
    return jsonb_build_object('free_used', 0, 'free_limit', 5, 'free_remaining', 5);
  end if;

  select coalesce(q.free_used, 0), coalesce(q.free_limit, 5)
  into v_used, v_limit
  from public.ai_tool_quota q
  where q.shop_id = p_shop_id and q.period_key = v_key;

  return jsonb_build_object(
    'period_key', v_key,
    'free_used', v_used,
    'free_limit', v_limit,
    'free_remaining', greatest(v_limit - v_used, 0)
  );
end;
$function$
;

-- ---- public.get_case_timeline_group(uuid)  secdef=false  md5=d6f902b53fac1cb052125f28364d2207
CREATE OR REPLACE FUNCTION public.get_case_timeline_group(p_chart_id uuid)
 RETURNS TABLE(chart_id uuid, visit_number integer, care_name text, before_image_url text, after_image_url text, care_tags jsonb, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_customer_id uuid;
  v_shop_id uuid;
  v_tags jsonb;
  v_tag_arr text[];
begin
  select c.customer_id, c.shop_id,
         coalesce(
           nullif(c.care_tags, '[]'::jsonb),
           nullif(c.concern_chips, '[]'::jsonb),
           '[]'::jsonb
         )
  into v_customer_id, v_shop_id, v_tags
  from public.customer_charts c
  where c.id = p_chart_id;

  if v_customer_id is null then
    return;
  end if;

  select coalesce(array_agg(t), '{}'::text[])
  into v_tag_arr
  from jsonb_array_elements_text(v_tags) as t;

  return query
  select
    c.id,
    c.visit_number,
    c.care_name,
    c.before_image_url,
    c.after_image_url,
    coalesce(
      nullif(c.care_tags, '[]'::jsonb),
      nullif(c.concern_chips, '[]'::jsonb),
      '[]'::jsonb
    ),
    c.created_at
  from public.customer_charts c
  where c.customer_id = v_customer_id
    and c.shop_id = v_shop_id
    and c.is_case_shared = true
    and (
      c.id = p_chart_id
      or cardinality(v_tag_arr) = 0
      or coalesce(c.care_tags, c.concern_chips, '[]'::jsonb)
         ?| v_tag_arr
    )
  order by c.visit_number asc, c.created_at asc;
end;
$function$
;

-- ---- public.get_chart_bookmark_counts(uuid[])  secdef=true  md5=053ebe139177efaba069e023d36ed068
CREATE OR REPLACE FUNCTION public.get_chart_bookmark_counts(p_chart_ids uuid[])
 RETURNS TABLE(chart_id uuid, bookmark_count integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    b.chart_id,
    count(*)::int as bookmark_count
  from public.case_bookmarks b
  where b.chart_id = any (coalesce(p_chart_ids, '{}'::uuid[]))
  group by b.chart_id;
$function$
;

-- ---- public.get_community_feed(text,integer,integer,text)  secdef=true  md5=4e1c58bb2e6d3c2b2c7c95ac32be825a
CREATE OR REPLACE FUNCTION public.get_community_feed(p_segment text DEFAULT 'interior'::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_viewer_seed text DEFAULT ''::text)
 RETURNS TABLE(target_id uuid, is_boost boolean, feed_position integer, score numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select * from public.get_interleaved_feed_ids(
    lower(trim(coalesce(p_segment, 'interior'))),
    '{}',
    p_limit,
    p_offset,
    p_viewer_seed,
    5
  );
$function$
;

-- ---- public.get_customer_wallet(uuid)  secdef=true  md5=922396d3a7e0721bf09edcf7f194c8c7
CREATE OR REPLACE FUNCTION public.get_customer_wallet(p_customer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_w public.wallets%rowtype;
begin
  v_w := public.ensure_customer_wallet(p_customer_id);
  select * into v_w from public.wallets where id = v_w.id;
  return jsonb_build_object(
    'id', v_w.id,
    'owner_type', v_w.owner_type,
    'customer_id', v_w.customer_id,
    'shop_id', v_w.shop_id,
    'point_free_balance', v_w.point_free_balance,
    'point_paid_balance', v_w.point_paid_balance,
    'point_total', v_w.point_free_balance + v_w.point_paid_balance,
    'settlement_balance', v_w.settlement_balance,
    'updated_at', v_w.updated_at
  );
end;
$function$
;

-- ---- public.get_home_feed(integer,integer,text)  secdef=true  md5=a84a910d422d77e8583629d6ffde833f
CREATE OR REPLACE FUNCTION public.get_home_feed(p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_viewer_seed text DEFAULT ''::text)
 RETURNS TABLE(target_id uuid, is_boost boolean, feed_position integer, score numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select * from public.get_interleaved_feed_ids(
    'case', '{}', p_limit, p_offset, p_viewer_seed, 5
  );
$function$
;

-- ---- public.get_interleaved_feed_ids(text,uuid[],integer,integer,text,integer)  secdef=true  md5=34cf0d077e93500f34f1036030e3cc72
CREATE OR REPLACE FUNCTION public.get_interleaved_feed_ids(p_segment text DEFAULT 'case'::text, p_organic_ids uuid[] DEFAULT '{}'::uuid[], p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_viewer_seed text DEFAULT ''::text, p_boost_every integer DEFAULT 5)
 RETURNS TABLE(target_id uuid, is_boost boolean, feed_position integer, score numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_seg text := lower(trim(coalesce(p_segment, 'case')));
  v_limit int := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_every int := greatest(2, least(coalesce(p_boost_every, 5), 20));
  v_seed text := coalesce(
    nullif(trim(p_viewer_seed), ''),
    public.feed_viewer_seed('', v_seg)
  );
  v_slots int;
  v_need int;
  v_organic uuid[];
  v_boost uuid[];
  v_boost_scores numeric[];
  v_out_ids uuid[] := '{}';
  v_out_boost boolean[] := '{}';
  v_out_score numeric[] := '{}';
  v_oi int := 1;
  v_bi int := 1;
  v_i int := 0;
  v_id uuid;
  v_is_b boolean;
  v_sc numeric;
  v_start int;
  v_end int;
  v_pos int;
begin
  v_need := v_offset + v_limit;
  v_slots := greatest(1, (v_need / v_every) + 2);

  -- Organic: caller list, or case segment from shared view / charts
  if p_organic_ids is not null and cardinality(p_organic_ids) > 0 then
    v_organic := p_organic_ids;
  elsif v_seg = 'case' then
    begin
      select coalesce(array_agg(c.chart_id order by c.created_at desc), '{}')
      into v_organic
      from (
        select chart_id, created_at
        from public.community_shared_cases
        order by created_at desc
        limit 500
      ) c;
    exception when undefined_table then
      select coalesce(array_agg(x.id order by x.created_at desc), '{}')
      into v_organic
      from (
        select id, created_at
        from public.customer_charts
        where coalesce(is_case_shared, false) = true
        order by created_at desc
        limit 500
      ) x;
    end;
  elsif v_seg in ('interior', 'device_review') then
    select coalesce(array_agg(p.id order by p.created_at desc), '{}')
    into v_organic
    from (
      select id, created_at
      from public.community_posts
      where post_type = v_seg
      order by created_at desc
      limit 500
    ) p;
  else
    v_organic := '{}';
  end if;

  select
    coalesce(array_agg(t.target_id order by t.slot_rank), '{}'),
    coalesce(array_agg(t.score order by t.slot_rank), '{}')
  into v_boost, v_boost_scores
  from public.pick_boost_slot_targets(v_seg, v_slots, v_seed, 40) t;

  -- Build interleaved stream (no boost dump when organic exhausted)
  while coalesce(array_length(v_out_ids, 1), 0) < v_need
    and (
      v_oi <= coalesce(array_length(v_organic, 1), 0)
      or v_bi <= coalesce(array_length(v_boost, 1), 0)
    )
  loop
    v_is_b := false;
    v_sc := 0;
    if (v_i % v_every = 0)
       and v_bi <= coalesce(array_length(v_boost, 1), 0) then
      v_id := v_boost[v_bi];
      v_sc := v_boost_scores[v_bi];
      v_bi := v_bi + 1;
      v_is_b := true;
      if v_id = any (v_out_ids) then
        v_i := v_i + 1;
        continue;
      end if;
      v_out_ids := v_out_ids || v_id;
      v_out_boost := v_out_boost || v_is_b;
      v_out_score := v_out_score || v_sc;
      v_i := v_i + 1;
      continue;
    end if;

    if v_oi <= coalesce(array_length(v_organic, 1), 0) then
      v_id := v_organic[v_oi];
      v_oi := v_oi + 1;
      if v_id = any (v_boost) or v_id = any (v_out_ids) then
        continue;
      end if;
      v_out_ids := v_out_ids || v_id;
      v_out_boost := v_out_boost || false;
      v_out_score := v_out_score || 0::numeric;
      v_i := v_i + 1;
      continue;
    end if;

    -- Organic exhausted: only place remaining boosts on boost indices
    if v_bi <= coalesce(array_length(v_boost, 1), 0) then
      if (v_i % v_every = 0) then
        v_id := v_boost[v_bi];
        v_sc := v_boost_scores[v_bi];
        v_bi := v_bi + 1;
        if not (v_id = any (v_out_ids)) then
          v_out_ids := v_out_ids || v_id;
          v_out_boost := v_out_boost || true;
          v_out_score := v_out_score || v_sc;
        end if;
      end if;
      v_i := v_i + 1;
      continue;
    end if;

    exit;
  end loop;

  v_start := v_offset + 1;
  v_end := least(
    coalesce(array_length(v_out_ids, 1), 0),
    v_offset + v_limit
  );

  if v_end < v_start then
    return;
  end if;

  for v_pos in v_start..v_end loop
    target_id := v_out_ids[v_pos];
    is_boost := v_out_boost[v_pos];
    feed_position := v_pos - 1;
    score := v_out_score[v_pos];
    return next;
  end loop;
end;
$function$
;

-- ---- public.get_mentoring_for_chart(uuid)  secdef=true  md5=71ec920071e5d31c4e60f06d7f146259
CREATE OR REPLACE FUNCTION public.get_mentoring_for_chart(p_chart_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_post public.mentoring_posts%rowtype;
  v_uid uuid := auth.uid();
  v_customer uuid;
  v_purchased boolean := false;
begin
  if p_chart_id is null then
    raise exception 'chart_id required';
  end if;

  select * into v_post
  from public.mentoring_posts mp
  where mp.chart_id = p_chart_id
    and mp.status <> 'archived'
  order by mp.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object('exists', false);
  end if;

  if v_uid is not null then
    select c.id into v_customer
    from public.customers c
    where c.user_id = v_uid
    limit 1;

    if v_customer is not null then
      select exists (
        select 1 from public.mentoring_purchases mp
        where mp.mentoring_post_id = v_post.id
          and mp.buyer_customer_id = v_customer
      ) into v_purchased;
    end if;
  end if;

  return jsonb_build_object(
    'exists', true,
    'id', v_post.id,
    'chart_id', v_post.chart_id,
    'author_shop_id', v_post.author_shop_id,
    'origin', v_post.origin,
    'title', v_post.title,
    'preview_teaser', v_post.preview_teaser,
    'body_locked', case
      when v_purchased
        or v_post.author_user_id = v_uid
        then v_post.body_locked
      else null
    end,
    'price_echo', v_post.price_echo,
    'status', v_post.status,
    'help_count', v_post.help_count,
    'not_help_count', v_post.not_help_count,
    'purchase_count', v_post.purchase_count,
    'purchased', v_purchased,
    'can_purchase', v_post.status = 'active' and not v_purchased,
    'published_at', v_post.published_at
  );
end;
$function$
;

-- ---- public.get_seminar_detail(uuid)  secdef=true  md5=44cf924aa1ad4a3315ed71871a183a84
CREATE OR REPLACE FUNCTION public.get_seminar_detail(p_class_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

-- ---- public.get_shop_assets(uuid)  secdef=true  md5=9c24e4a9a51b7437ecd25d804c0e269d
CREATE OR REPLACE FUNCTION public.get_shop_assets(p_shop_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.shop_assets%rowtype;
  v_t3 jsonb := '[]'::jsonb;
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  select * into v_row
  from public.shop_assets sa
  where sa.shop_id = p_shop_id;

  if not found then
    raise exception 'shop not found';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'customer_id', sub.customer_id,
      'display_name', sub.display_name,
      'avatar_url', sub.avatar_url,
      'echo_total', sub.echo_total,
      'last_interaction_at', sub.last_interaction_at
    )
    order by sub.echo_total desc
  ), '[]'::jsonb)
  into v_t3
  from (
    select
      fg.fan_customer_id as customer_id,
      coalesce(
        nullif(trim(max(fg.fan_display_name)), ''),
        nullif(trim(max(c.name)), ''),
        'Supporter'
      ) as display_name,
      coalesce(nullif(trim(max(p.avatar_url)), ''), '') as avatar_url,
      sum(fg.echo_spent)::int as echo_total,
      max(fg.created_at) as last_interaction_at
    from public.fan_gifts fg
    left join public.customers c on c.id = fg.fan_customer_id
    left join public.profiles p on p.id = c.user_id
    where fg.beneficiary_shop_id = p_shop_id
      and fg.status = 'completed'
    group by fg.fan_customer_id
    order by echo_total desc
    limit 20
  ) sub;

  return jsonb_build_object(
    'tier1', jsonb_build_object(
      'chart_count_total', v_row.chart_count_total,
      'ba_published_count', v_row.ba_published_count,
      'ba_view_total', v_row.ba_view_total,
      'bookmark_total', v_row.bookmark_total
    ),
    'tier2', jsonb_build_object(
      'seminar_hosted_count', v_row.seminar_hosted_count,
      'seminar_request_received_count', v_row.seminar_request_received_count,
      'seminar_request_sent_count', v_row.seminar_request_sent_count,
      'follower_count', v_row.follower_count,
      'supporter_count', v_row.supporter_count,
      'mentoring_revenue_echo_total', v_row.mentoring_revenue_echo_total
    ),
    'tier3_preview', v_t3,
    'refreshed_at', now()
  );
end;
$function$
;

-- ---- public.get_shop_promo_credits(uuid)  secdef=true  md5=02e31dbf0022b1cc578acf8339c52c7a
CREATE OR REPLACE FUNCTION public.get_shop_promo_credits(p_shop_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_rows jsonb;
begin
  if p_shop_id is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'credit_sku', c.credit_sku,
    'balance', c.balance,
    'source', c.source,
    'note', c.note
  ) order by c.credit_sku), '[]'::jsonb)
  into v_rows
  from public.shop_promo_credits c
  where c.shop_id = p_shop_id and c.balance > 0;

  return v_rows;
end;
$function$
;

-- ---- public.get_shop_sponsorship_impact(uuid,integer)  secdef=true  md5=5e329015b84b82de245cc49a6ed01c69
CREATE OR REPLACE FUNCTION public.get_shop_sponsorship_impact(p_shop_id uuid, p_period_days integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_days int := greatest(1, least(coalesce(p_period_days, 30), 90));
  v_since timestamptz := now() - make_interval(days => v_days);
  v_gift_count int := 0;
  v_echo_total int := 0;
  v_bookmarks int := 0;
  v_thank_yous int := 0;
  v_pending int := 0;
  v_reach int := 0;
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  select
    count(*)::int,
    coalesce(sum(fg.echo_spent), 0)::int,
    count(*) filter (
      where exists (
        select 1 from public.community_posts p
        where p.reply_to_fan_gift_id = fg.id
      )
    )::int,
    count(*) filter (
      where not exists (
        select 1 from public.community_posts p
        where p.reply_to_fan_gift_id = fg.id
      )
    )::int
  into v_gift_count, v_echo_total, v_thank_yous, v_pending
  from public.fan_gifts fg
  where fg.beneficiary_shop_id = p_shop_id
    and fg.status = 'completed'
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    )
    and fg.created_at >= v_since;

  select coalesce(count(*)::int, 0)
  into v_bookmarks
  from public.case_bookmarks cb
  join public.customer_charts cc on cc.id = cb.chart_id
  where cc.shop_id = p_shop_id
    and cb.created_at >= v_since
    and exists (
      select 1 from public.fan_gifts fg
      where fg.beneficiary_shop_id = p_shop_id
        and fg.status = 'completed'
        and fg.created_at >= v_since
        and (
          (fg.target_type = 'chart' and fg.target_id = cb.chart_id)
          or exists (
            select 1 from public.community_posts cp
            where cp.id = fg.target_id
              and cp.source_chart_id = cb.chart_id
          )
        )
    );

  select coalesce(sum(
    coalesce((
      select round(
        greatest(
          0,
          extract(epoch from (
            least(coalesce(bp.ends_at, now()), now()) - bp.starts_at
          )) / 3600.0
        ) * 15
      )::int
      from public.boost_placements bp
      where bp.id = fg.boost_placement_id
    ), 0)
    + coalesce((
      select round(
        greatest(
          0,
          extract(epoch from (
            least(coalesce(ov.ends_at, now()), now()) - ov.starts_at
          )) / 3600.0
        ) * 25
      )::int
      from public.boost_premium_overlays ov
      where ov.fan_gift_id = fg.id
      order by ov.created_at desc
      limit 1
    ), 0)
  ), 0)::int
  into v_reach
  from public.fan_gifts fg
  where fg.beneficiary_shop_id = p_shop_id
    and fg.status = 'completed'
    and fg.created_at >= v_since
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    );

  return jsonb_build_object(
    'ok', true,
    'period_days', v_days,
    'gift_count', v_gift_count,
    'echo_total', v_echo_total,
    'bookmarks_received', v_bookmarks,
    'thank_yous_sent', v_thank_yous,
    'pending_thanks', v_pending,
    'estimated_total_reach', v_reach
  );
end;
$function$
;

-- ---- public.get_shop_supporter_header(uuid)  secdef=true  md5=37623e0693251e7cf2d0762c67ca49a9
CREATE OR REPLACE FUNCTION public.get_shop_supporter_header(p_shop_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_followers int := 0;
  v_supporters int := 0;
  v_facepile jsonb;
  v_top jsonb;
  v_special_hero jsonb;
begin
  if p_shop_id is null then
    return jsonb_build_object('follower_count', 0, 'supporter_count', 0, 'facepile', '[]'::jsonb);
  end if;

  perform public.expire_stale_premium_overlays();

  select count(*)::int into v_followers
  from public.shop_followers sf where sf.shop_id = p_shop_id;

  select count(distinct fg.fan_customer_id)::int into v_supporters
  from public.fan_gifts fg
  where fg.beneficiary_shop_id = p_shop_id
    and fg.status = 'completed'
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    );

  select coalesce(jsonb_agg(jsonb_build_object(
    'paid_by_customer_id', s.supporter_customer_id,
    'fan_display_name', s.display_name,
    'avatar_url', s.avatar_url,
    'echo_spent', s.echo_spent,
    'boost_count', s.boost_count,
    'supporter_tier', s.supporter_tier
  ) order by s.echo_spent desc), '[]'::jsonb)
  into v_facepile
  from public.list_shop_supporters(p_shop_id, 'echo_desc', 3) s;

  select to_jsonb(s) into v_top
  from public.list_shop_supporters(p_shop_id, 'echo_desc', 1) s
  limit 1;

  select jsonb_build_object(
    'paid_by_customer_id', o.fan_customer_id,
    'fan_display_name', o.fan_display_name,
    'avatar_url', coalesce(nullif(trim(p.avatar_url), ''), ''),
    'echo_spent', o.echo_spent,
    'supporter_tier', 'platinum',
    'tier', 'platinum',
    'ends_at', o.ends_at
  )
  into v_special_hero
  from public.boost_premium_overlays o
  left join public.customers c on c.id = o.fan_customer_id
  left join public.profiles p on p.id = c.user_id
  where o.beneficiary_shop_id = p_shop_id
    and o.tier = 'platinum'
    and o.status = 'active'
    and o.ends_at > now()
  order by o.ends_at desc
  limit 1;

  return jsonb_build_object(
    'follower_count', v_followers,
    'supporter_count', v_supporters,
    'facepile', v_facepile,
    'top_supporter', coalesce(v_top, 'null'::jsonb),
    'special_hero', coalesce(v_special_hero, 'null'::jsonb)
  );
end;
$function$
;

-- ---- public.get_shop_trust_score(uuid)  secdef=true  md5=8f4871105534aa522129fc2c30539e37
CREATE OR REPLACE FUNCTION public.get_shop_trust_score(p_shop_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_bookmarks int := 0;
  v_echo int := 0;
  v_gifts int := 0;
  v_review_avg numeric := 0;
  v_review_count int := 0;
  v_seminar_count int := 0;
  v_thank_yous int := 0;
  v_pending int := 0;
  v_thank_rate numeric := 0;
  v_raw numeric := 0;
  v_score int := 0;
  v_label text := '성장 중';
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  select count(*)::int
  into v_bookmarks
  from public.case_bookmarks cb
  join public.customer_charts cc on cc.id = cb.chart_id
  where cc.shop_id = p_shop_id;

  select
    coalesce(sum(fg.echo_spent), 0)::int,
    count(*)::int,
    count(*) filter (
      where exists (
        select 1 from public.community_posts p
        where p.reply_to_fan_gift_id = fg.id
      )
    )::int
  into v_echo, v_gifts, v_thank_yous
  from public.fan_gifts fg
  where fg.beneficiary_shop_id = p_shop_id
    and fg.status = 'completed'
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    );

  if v_gifts > 0 then
    v_thank_rate := v_thank_yous::numeric / v_gifts::numeric;
  end if;

  select
    coalesce(avg(r.rating), 0),
    count(*)::int
  into v_review_avg, v_review_count
  from public.customer_reviews r
  where r.shop_id = p_shop_id
    and r.rating is not null
    and r.rating > 0;

  select count(*)::int
  into v_seminar_count
  from public.seminar_classes sc
  where sc.director_shop_id = p_shop_id;

  v_raw :=
    15 * ln(1 + v_bookmarks)
    + 25 * ln(1 + greatest(v_echo, 0) / 50.0)
    + 10 * ln(1 + v_gifts)
    + case
        when v_review_count > 0 then 20 * (v_review_avg / 5.0)
        else 0
      end
    + 10 * ln(1 + v_seminar_count)
    + 20 * v_thank_rate;

  v_score := round(least(100, greatest(0, v_raw)))::int;

  v_label := case
    when v_score >= 75 then '검증된 레퍼런스'
    when v_score >= 45 then '신뢰 쌓이는 중'
    else '성장 중'
  end;

  return jsonb_build_object(
    'ok', true,
    'score', v_score,
    'tier_label', v_label,
    'bookmark_count', v_bookmarks,
    'supporter_echo', v_echo,
    'supporter_gift_count', v_gifts,
    'review_avg', round(v_review_avg, 1),
    'review_count', v_review_count,
    'seminar_count', v_seminar_count,
    'thank_you_rate', round(v_thank_rate, 2)
  );
end;
$function$
;

-- ---- public.get_shop_wallet(uuid)  secdef=true  md5=b9646fb1ada9a28cb33ededdff0e9beb
CREATE OR REPLACE FUNCTION public.get_shop_wallet(p_shop_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_w public.wallets%rowtype;
begin
  v_w := public.ensure_shop_wallet(p_shop_id);
  select * into v_w from public.wallets where shop_id = p_shop_id;
  return jsonb_build_object(
    'id', v_w.id,
    'shop_id', v_w.shop_id,
    'owner_user_id', v_w.owner_user_id,
    'point_free_balance', v_w.point_free_balance,
    'point_paid_balance', v_w.point_paid_balance,
    'point_total', v_w.point_free_balance + v_w.point_paid_balance,
    'settlement_balance', v_w.settlement_balance,
    'settlement_pending', v_w.settlement_pending,
    'settlement_paid_lifetime', v_w.settlement_paid_lifetime,
    -- legacy aliases for older clients (points only)
    'free_balance', v_w.point_free_balance,
    'paid_balance', v_w.point_paid_balance,
    'updated_at', v_w.updated_at
  );
end;
$function$
;

-- ---- public.get_supporter_interaction_statement(uuid,uuid,integer)  secdef=true  md5=74605dcdb221fa744580b846c7c2f190
CREATE OR REPLACE FUNCTION public.get_supporter_interaction_statement(p_shop_id uuid, p_supporter_customer_id uuid, p_limit integer DEFAULT 50)
 RETURNS TABLE(occurred_at timestamp with time zone, kind text, echo_amount integer, target_label text, target_id uuid, metadata jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if p_shop_id is null or p_supporter_customer_id is null then
    raise exception 'shop_id and supporter_customer_id required';
  end if;

  return query
  (
    select
      fg.created_at,
      'supporter_gift'::text,
      fg.echo_spent,
      coalesce(
        nullif(trim(cc.care_name), ''),
        nullif(trim(cc.treatment_summary), ''),
        'Case boost'
      ),
      case when fg.target_type = 'chart' then fg.target_id else cp.source_chart_id end,
      jsonb_build_object(
        'fan_gift_id', fg.id,
        'sku', fg.sku,
        'gift_kind', fg.gift_kind
      )
    from public.fan_gifts fg
    left join public.customer_charts cc
      on fg.target_type = 'chart' and cc.id = fg.target_id
    left join public.community_posts cp
      on fg.target_type = 'community_post' and cp.id = fg.target_id
    where fg.beneficiary_shop_id = p_shop_id
      and fg.fan_customer_id = p_supporter_customer_id
      and fg.status = 'completed'
  )
  union all
  (
    select
      mp.created_at,
      'mentoring_purchase'::text,
      mp.echo_paid,
      coalesce(nullif(trim(mpost.title), ''), 'Premium Mentoring'),
      mpost.chart_id,
      jsonb_build_object('purchase_id', mp.id, 'mentoring_post_id', mpost.id)
    from public.mentoring_purchases mp
    join public.mentoring_posts mpost on mpost.id = mp.mentoring_post_id
    where mpost.author_shop_id = p_shop_id
      and mp.buyer_customer_id = p_supporter_customer_id
  )
  union all
  (
    select
      cb.created_at,
      'case_bookmark'::text,
      0,
      coalesce(nullif(trim(cc.care_name), ''), 'Case bookmark'),
      cb.chart_id,
      jsonb_build_object('folder', cb.folder)
    from public.case_bookmarks cb
    join public.customers c on c.id = p_supporter_customer_id
    join public.customer_charts cc on cc.id = cb.chart_id
    where cc.shop_id = p_shop_id
      and cb.user_id = c.user_id
  )
  order by occurred_at desc
  limit v_limit;
end;
$function$
;

-- ---- public.grant_staff_role(uuid,text,text)  secdef=true  md5=5a159362bda6ed075ea7f1a1cb664144
CREATE OR REPLACE FUNCTION public.grant_staff_role(p_user_id uuid, p_role text, p_notes text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_role text := lower(trim(coalesce(p_role, '')));
  v_super_count int;
begin
  if p_user_id is null then
    raise exception 'user_id required';
  end if;
  if v_role not in ('moderator', 'ops_admin', 'super_admin') then
    raise exception 'invalid role';
  end if;

  select count(*) into v_super_count
  from public.staff_roles where role = 'super_admin';

  if v_super_count > 0 then
    perform public.require_staff(array['super_admin']);
  elsif auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  -- If no super yet, first grant is allowed for authenticated caller (bootstrap).

  insert into public.staff_roles (user_id, role, granted_by, notes)
  values (p_user_id, v_role, auth.uid(), coalesce(p_notes, ''))
  on conflict (user_id, role) do update set
    notes = excluded.notes,
    granted_by = excluded.granted_by;

  perform public.write_admin_audit(
    'grant_staff_role', 'profile', p_user_id::text,
    jsonb_build_object('role', v_role, 'notes', coalesce(p_notes, ''))
  );

  return jsonb_build_object('ok', true, 'user_id', p_user_id, 'role', v_role);
end;
$function$
;

-- ---- public.grant_tier_upgrade_reward(uuid,text,text)  secdef=true  md5=a2a29713624c7ade89478231580ad5d9
CREATE OR REPLACE FUNCTION public.grant_tier_upgrade_reward(p_shop_id uuid, p_from_tier text, p_to_tier text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_to text := lower(trim(replace(coalesce(p_to_tier, ''), ' ', '_')));
  v_from text := lower(trim(replace(coalesce(p_from_tier, ''), ' ', '_')));
  v_echo int := 0;
  v_sku text := '';
  v_rank int;
begin
  if p_shop_id is null or v_to = '' or v_to = 'none' then
    return jsonb_build_object('ok', false, 'reason', 'noop');
  end if;
  if public.tier_badge_rank(v_to) <= public.tier_badge_rank(v_from) then
    return jsonb_build_object('ok', false, 'reason', 'not_upgrade');
  end if;

  if exists (
    select 1 from public.tier_upgrade_rewards_log
    where shop_id = p_shop_id and to_tier = v_to
  ) then
    return jsonb_build_object('ok', true, 'reason', 'already_granted');
  end if;

  v_rank := public.tier_badge_rank(v_to);

  -- Social track: full Echo. Mentor+ (7+): reduced Echo + booster coupon.
  v_echo := case v_to
    when 'iron' then 3
    when 'bronze' then 5
    when 'silver' then 8
    when 'gold' then 12
    when 'platinum' then 18
    when 'diamond' then 25
    when 'mentor' then 15          -- half cashy echo + coupon
    when 'master' then 20
    when 'grand_master' then 25
    when 'grand_director' then 30
    else 0
  end;

  v_sku := case
    when v_rank >= 7 then 'boost_local_1d'   -- Mentor+ lock-in coupon
    when v_to = 'platinum' then 'boost_local_2h'
    when v_to = 'diamond' then 'boost_local_2h'
    when v_to = 'gold' then 'ai_report_weekly'
    when v_to = 'silver' then 'template_private'
    else ''
  end;

  if v_echo > 0 then
    perform public.credit_points(
      p_shop_id, v_echo, 'free', 'tier_grant',
      'tier_upgrade', null, null,
      '티어 승급 축하 ' || v_to || ' +' || v_echo::text || ' Echo'
    );
  end if;

  if v_sku <> '' then
    insert into public.shop_entitlements (
      shop_id, sku, source, status, ref_tier, note, expires_at
    ) values (
      p_shop_id, v_sku, 'tier_upgrade', 'active', v_to,
      '티어 승급 쿠폰',
      now() + interval '90 days'
    );
  end if;

  insert into public.tier_upgrade_rewards_log (
    shop_id, from_tier, to_tier, echo_granted, entitlement_sku
  ) values (
    p_shop_id, v_from, v_to, v_echo, v_sku
  );

  return jsonb_build_object(
    'ok', true,
    'to_tier', v_to,
    'echo_granted', v_echo,
    'entitlement_sku', v_sku
  );
end;
$function$
;

-- ---- public.handle_new_user()  secdef=true  md5=58cbb12abc10da23a03349df5e6317fe
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  display_name text;
  avatar text;
begin
  display_name := coalesce(
    nullif(trim(meta->>'name'), ''),
    nullif(trim(meta->>'full_name'), ''),
    nullif(trim(meta->>'nickname'), ''),
    nullif(trim(meta->>'preferred_username'), ''),
    ''
  );
  avatar := coalesce(
    nullif(trim(meta->>'avatar_url'), ''),
    nullif(trim(meta->>'picture'), ''),
    nullif(trim(meta->>'profile_image'), ''),
    nullif(trim(meta->>'profile_image_url'), ''),
    ''
  );

  insert into public.profiles (id, name, phone, avatar_url, role, active_mode)
  values (
    new.id,
    display_name,
    coalesce(meta->>'phone', ''),
    avatar,
    'guest',
    'customer'
  )
  on conflict (id) do update
    set
      name = case
        when excluded.name <> '' then excluded.name
        else public.profiles.name
      end,
      avatar_url = case
        when excluded.avatar_url <> '' then excluded.avatar_url
        else public.profiles.avatar_url
      end,
      updated_at = now();

  return new;
end;
$function$
;

-- ---- public.has_staff_role(text[])  secdef=true  md5=a7f326eabd1557cbfad709ff007ec082
CREATE OR REPLACE FUNCTION public.has_staff_role(p_roles text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.staff_roles sr
    where sr.user_id = auth.uid()
      and sr.role = any (p_roles)
  );
$function$
;

-- ---- public.hide_community_post(uuid,text)  secdef=true  md5=f8c97cddb12526e1455b659b1cfb8da9
CREATE OR REPLACE FUNCTION public.hide_community_post(p_post_id uuid, p_reason text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  perform public.require_staff(array['moderator', 'ops_admin', 'super_admin']);
  if p_post_id is null then
    raise exception 'post_id required';
  end if;

  update public.community_posts
  set status = 'hidden',
      updated_at = now()
  where id = p_post_id
  returning id into v_id;

  if v_id is null then
    raise exception 'post not found';
  end if;

  perform public.write_admin_audit(
    'hide_community_post', 'community_post', v_id::text,
    jsonb_build_object('reason', coalesce(p_reason, ''))
  );

  return jsonb_build_object('ok', true, 'post_id', v_id, 'status', 'hidden');
end;
$function$
;

-- ---- public.hold_market_escrow(uuid,uuid,integer)  secdef=true  md5=c98962c948d0e7042708a3709b8de978
CREATE OR REPLACE FUNCTION public.hold_market_escrow(p_listing_id uuid, p_inquiry_id uuid DEFAULT NULL::uuid, p_amount integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_listing public.market_listings%rowtype;
  v_amount int;
  v_id uuid;
begin
  if p_listing_id is null then
    raise exception 'listing_id required';
  end if;

  select * into v_listing from public.market_listings where id = p_listing_id;
  if not found then raise exception 'listing not found'; end if;

  v_amount := coalesce(p_amount, v_listing.price);
  if v_amount < 0 then v_amount := 0; end if;

  if exists (
    select 1 from public.market_escrow_holds
    where listing_id = p_listing_id and status = 'held'
  ) then
    raise exception 'escrow already held';
  end if;

  insert into public.market_escrow_holds (
    listing_id, inquiry_id, amount, status
  ) values (
    p_listing_id, p_inquiry_id, v_amount, 'held'
  )
  returning id into v_id;

  update public.market_listings
  set listing_status = 'reserved', updated_at = now()
  where id = p_listing_id;

  return jsonb_build_object('ok', true, 'escrow_id', v_id, 'status', 'held');
end;
$function$
;

-- ---- public.insert_review_request_event(uuid,uuid,text,uuid,integer)  secdef=true  md5=1cc580c6a622897a1d1be53b63f9fe45
CREATE OR REPLACE FUNCTION public.insert_review_request_event(p_customer_id uuid, p_chart_id uuid DEFAULT NULL::uuid, p_channel text DEFAULT 'qr'::text, p_shop_id uuid DEFAULT NULL::uuid, p_remind_hours integer DEFAULT 24)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_channel text := lower(trim(coalesce(p_channel, 'qr')));
  v_hours int := greatest(1, least(coalesce(p_remind_hours, 24), 168));
  v_id uuid;
  v_row public.review_request_events%rowtype;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_customer_id is null then
    raise exception 'customer_id required';
  end if;
  if v_channel not in ('qr', 'link', 'alimtalk', 'manual') then
    v_channel := 'qr';
  end if;

  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;

  if v_shop is null
     or not exists (
       select 1 from public.shops s
       where s.id = v_shop
         and (
           s.owner_user_id = v_uid
           or exists (
             select 1 from public.shop_memberships m
             where m.shop_id = s.id and m.user_id = v_uid
           )
         )
     ) then
    raise exception 'shop access denied';
  end if;

  if not exists (
    select 1 from public.customers c
    where c.id = p_customer_id and c.shop_id = v_shop
  ) then
    raise exception 'customer not in shop';
  end if;

  insert into public.review_request_events (
    shop_id, customer_id, chart_id, channel, status,
    sent_at, remind_at, created_by
  ) values (
    v_shop,
    p_customer_id,
    p_chart_id,
    v_channel,
    'sent',
    now(),
    now() + make_interval(hours => v_hours),
    v_uid
  )
  returning * into v_row;

  return to_jsonb(v_row);
end;
$function$
;

-- ---- public.list_active_boost_placements(integer)  secdef=true  md5=42375e9947116e6ecf08118580989109
CREATE OR REPLACE FUNCTION public.list_active_boost_placements(p_limit integer DEFAULT 40)
 RETURNS SETOF boost_placements
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.expire_stale_boost_placements();
  return query
  select *
  from public.boost_placements
  where status = 'active'
    and ends_at > now()
  order by ends_at desc
  limit greatest(coalesce(p_limit, 40), 1);
end;
$function$
;

-- ---- public.list_active_premium_overlays(integer)  secdef=true  md5=c5add0dee675977c5bab19deecd2d034
CREATE OR REPLACE FUNCTION public.list_active_premium_overlays(p_limit integer DEFAULT 80)
 RETURNS TABLE(id uuid, beneficiary_shop_id uuid, target_type text, target_id uuid, chart_id uuid, tier text, sku text, fan_customer_id uuid, fan_display_name text, echo_spent integer, starts_at timestamp with time zone, ends_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 80), 200));
begin
  perform public.expire_stale_premium_overlays();

  return query
  select
    o.id,
    o.beneficiary_shop_id,
    o.target_type,
    o.target_id,
    o.chart_id,
    o.tier,
    o.sku,
    o.fan_customer_id,
    o.fan_display_name,
    o.echo_spent,
    o.starts_at,
    o.ends_at
  from public.boost_premium_overlays o
  where o.status = 'active'
    and o.ends_at > now()
  order by o.ends_at desc
  limit v_limit;
end;
$function$
;

-- ---- public.list_boost_candidates_scored(text,integer)  secdef=true  md5=7e322e8e0633ab95971d28535fee3c2c
CREATE OR REPLACE FUNCTION public.list_boost_candidates_scored(p_segment text DEFAULT 'case'::text, p_limit integer DEFAULT 200)
 RETURNS TABLE(placement_id uuid, target_type text, target_id uuid, source text, points_spent integer, starts_at timestamp with time zone, ends_at timestamp with time zone, fandom_echo integer, paid_ratio numeric, recency numeric, fan_bonus numeric, score numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_seg text := lower(trim(coalesce(p_segment, 'case')));
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
  v_tau double precision := 12.0;
begin
  perform public.expire_stale_boost_placements();
  perform public.expire_stale_premium_overlays();

  return query
  with active as (
    select bp.*
    from public.boost_placements bp
    where bp.status = 'active'
      and bp.ends_at > now()
      and public.boost_feed_segment(bp.target_type, bp.target_id) = v_seg
  ),
  fandom as (
    select
      bp.target_type,
      bp.target_id,
      sum(bp.points_spent)::int as echo_sum
    from public.boost_placements bp
    where bp.source = 'fan_boost'
    group by bp.target_type, bp.target_id
  ),
  overlay as (
    select
      o.target_type,
      o.target_id,
      max(case o.tier when 'platinum' then 0.22 when 'gold' then 0.12 else 0 end)::numeric
        as tier_bonus
    from public.boost_premium_overlays o
    where o.status = 'active' and o.ends_at > now()
    group by o.target_type, o.target_id
  ),
  bookmarks as (
    select
      b.chart_id as tid,
      count(*)::int as cnt
    from public.case_bookmarks b
    group by b.chart_id
  )
  select
    a.id,
    a.target_type,
    a.target_id,
    a.source,
    a.points_spent,
    a.starts_at,
    a.ends_at,
    coalesce(f.echo_sum, 0)::int as fandom_echo,
    (case when a.source = 'fan_boost' then 0.85 else 0.55 end)::numeric
      as paid_ratio,
    (exp(
      - greatest(0, extract(epoch from (now() - a.starts_at)) / 3600.0) / v_tau
    ))::numeric as recency,
    (case when a.source = 'fan_boost' then 1.0 else 0.45 end)::numeric
      as fan_bonus,
    (
      0.36 * least(
        1.0,
        ln(1 + coalesce(f.echo_sum, 0)::double precision) / ln(1 + 5000)
      )
      + 0.22 * (case when a.source = 'fan_boost' then 0.85 else 0.55 end)
      + 0.18 * exp(
        - greatest(0, extract(epoch from (now() - a.starts_at)) / 3600.0) / v_tau
      )
      + 0.14 * (case when a.source = 'fan_boost' then 1.0 else 0.45 end)
      + 0.10 * least(
        1.0,
        ln(1 + coalesce(bk.cnt, 0)::double precision) / ln(1 + 200)
      )
      + coalesce(ov.tier_bonus, 0)
    )::numeric as score
  from active a
  left join fandom f
    on f.target_type = a.target_type
   and f.target_id = a.target_id
  left join overlay ov
    on ov.target_type = a.target_type
   and ov.target_id = a.target_id
  left join bookmarks bk
    on a.target_type = 'chart'
   and bk.tid = a.target_id
  order by score desc, a.starts_at desc
  limit v_limit;
end;
$function$
;

-- ---- public.list_boost_gift_impact_reports_for_customer(uuid,integer)  secdef=true  md5=841d5c6836f5585ba46eb535b29980a0
CREATE OR REPLACE FUNCTION public.list_boost_gift_impact_reports_for_customer(p_customer_id uuid, p_limit integer DEFAULT 50)
 RETURNS TABLE(fan_gift_id uuid, target_type text, chart_id uuid, shop_id uuid, shop_name text, sku text, echo_spent integer, gift_kind text, created_at timestamp with time zone, case_title text, has_thank_you boolean, thank_you_post_id uuid, bookmarks_since_gift integer, estimated_reach integer, boost_still_active boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select * from public.list_boost_gift_impact_reports(p_customer_id, p_limit);
$function$
;

-- ---- public.list_boost_gift_impact_reports(uuid,integer)  secdef=true  md5=8f08bd6a029d62636efccc58bac34930
CREATE OR REPLACE FUNCTION public.list_boost_gift_impact_reports(p_fan_customer_id uuid, p_limit integer DEFAULT 50)
 RETURNS TABLE(fan_gift_id uuid, target_type text, chart_id uuid, shop_id uuid, shop_name text, sku text, echo_spent integer, gift_kind text, created_at timestamp with time zone, case_title text, has_thank_you boolean, thank_you_post_id uuid, bookmarks_since_gift integer, estimated_reach integer, boost_still_active boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if p_fan_customer_id is null then
    raise exception 'fan_customer_id required';
  end if;

  return query
  with base as (
    select
      fg.id as gift_id,
      fg.target_type,
      case
        when fg.target_type = 'chart' then fg.target_id
        else cp.source_chart_id
      end as resolved_chart_id,
      fg.beneficiary_shop_id,
      coalesce(nullif(trim(s.name), ''), 'SORI') as shop_nm,
      fg.sku,
      fg.echo_spent,
      fg.gift_kind,
      fg.created_at as gift_created_at,
      coalesce(
        nullif(trim(cc.care_name), ''),
        nullif(trim(cc.treatment_summary), ''),
        '케이스'
      ) as case_nm,
      fg.boost_placement_id,
      fg.id as fg_id
    from public.fan_gifts fg
    join public.shops s on s.id = fg.beneficiary_shop_id
    left join public.customer_charts cc
      on fg.target_type = 'chart' and cc.id = fg.target_id
    left join public.community_posts cp
      on fg.target_type = 'community_post' and cp.id = fg.target_id
    where fg.fan_customer_id = p_fan_customer_id
      and fg.status = 'completed'
      and fg.gift_kind in (
        'boost', 'boost_with_ai_fill',
        'boost_special_gold', 'boost_special_platinum'
      )
    order by fg.created_at desc
    limit v_limit
  )
  select
    b.gift_id,
    b.target_type,
    b.resolved_chart_id,
    b.beneficiary_shop_id,
    b.shop_nm,
    b.sku,
    b.echo_spent,
    b.gift_kind,
    b.gift_created_at,
    b.case_nm,
    exists (
      select 1 from public.community_posts p
      where p.reply_to_fan_gift_id = b.gift_id
    ),
    (
      select p.id from public.community_posts p
      where p.reply_to_fan_gift_id = b.gift_id
      limit 1
    ),
    coalesce((
      select count(*)::int
      from public.case_bookmarks cb
      where b.resolved_chart_id is not null
        and cb.chart_id = b.resolved_chart_id
        and cb.created_at >= b.gift_created_at
    ), 0),
    (
      coalesce((
        select round(
          greatest(
            0,
            extract(epoch from (
              least(coalesce(bp.ends_at, now()), now()) - bp.starts_at
            )) / 3600.0
          ) * 15
        )::int
        from public.boost_placements bp
        where bp.id = b.boost_placement_id
      ), 0)
      + coalesce((
        select round(
          greatest(
            0,
            extract(epoch from (
              least(coalesce(ov.ends_at, now()), now()) - ov.starts_at
            )) / 3600.0
          ) * 25
        )::int
        from public.boost_premium_overlays ov
        where ov.fan_gift_id = b.fg_id
        order by ov.created_at desc
        limit 1
      ), 0)
    ),
    (
      exists (
        select 1 from public.boost_placements bp
        where bp.id = b.boost_placement_id
          and bp.status = 'active'
          and bp.ends_at > now()
      )
      or exists (
        select 1 from public.boost_premium_overlays ov
        where ov.fan_gift_id = b.fg_id
          and ov.status = 'active'
          and ov.ends_at > now()
      )
    )
  from base b;
end;
$function$
;

-- ---- public.list_community_posts_safe(text,integer)  secdef=true  md5=371072665501573a4ea74cd9dd3f1f96
CREATE OR REPLACE FUNCTION public.list_community_posts_safe(p_post_type text DEFAULT NULL::text, p_limit integer DEFAULT 40)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_result jsonb;
begin
  select coalesce(jsonb_agg(row_data order by sort_created desc), '[]'::jsonb)
  into v_result
  from (
    select
      p.created_at as sort_created,
      jsonb_build_object(
        'id', p.id,
        'shop_id', p.shop_id,
        'author_user_id', p.author_user_id,
        'post_type', p.post_type,
        'title', p.title,
        'body', case
          when p.is_whisper and not public.can_view_whisper_post(p.id) then ''
          when public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id, p.id
          ) then p.body
          else ''
        end,
        'style_tags', p.style_tags,
        'region_code', p.region_code,
        'visibility', p.visibility,
        'status', p.status,
        'like_count', p.like_count,
        'comment_count', p.comment_count,
        'save_count', p.save_count,
        'source_chart_id', p.source_chart_id,
        'created_at', p.created_at,
        'updated_at', p.updated_at,
        'is_whisper', coalesce(p.is_whisper, false),
        'audience_spec', coalesce(p.audience_spec, '{}'::jsonb),
        'audience_op', p.audience_op,
        'whisper_recipient_count', coalesce(p.whisper_recipient_count, 0),
        'is_body_locked', case
          when p.is_whisper then not public.can_view_whisper_post(p.id)
          else not public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id, p.id
          )
        end,
        'unlock_cost', 500,
        'shops', jsonb_build_object(
          'id', s.id,
          'name', s.name,
          'owner_name', s.owner_name,
          'tier_badge', s.tier_badge::text,
          'profile_image_url', s.profile_image_url
        ),
        'post_media', case
          when p.is_whisper then '[]'::jsonb
          when public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id, p.id
          ) then coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', m.id,
                'post_id', m.post_id,
                'image_url', m.image_url,
                'sort_order', m.sort_order,
                'post_tags', coalesce((
                  select jsonb_agg(
                    jsonb_build_object(
                      'id', t.id,
                      'media_id', t.media_id,
                      'tag_kind', t.tag_kind,
                      'label', t.label,
                      'norm_x', t.norm_x,
                      'norm_y', t.norm_y,
                      'partner_id', t.partner_id,
                      'external_url', t.external_url,
                      'metadata', t.metadata
                    )
                    order by t.created_at
                  )
                  from public.post_tags t
                  where t.media_id = m.id
                ), '[]'::jsonb)
              )
              order by m.sort_order asc
            )
            from public.post_media m
            where m.post_id = p.id
          ), '[]'::jsonb)
          else '[]'::jsonb
        end,
        'device_reviews', coalesce((
          select jsonb_agg(to_jsonb(d))
          from public.device_reviews d
          where d.post_id = p.id
        ), '[]'::jsonb),
        'market_listings', coalesce((
          select jsonb_agg(to_jsonb(l))
          from public.market_listings l
          where l.post_id = p.id
        ), '[]'::jsonb)
      ) as row_data
    from public.community_posts p
    left join public.shops s on s.id = p.shop_id
    where p.status = 'published'
      and (
        coalesce(p.is_whisper, false) = false
        or public.can_view_whisper_post(p.id)
      )
      and (
        p_post_type is null
        or p_post_type = ''
        or p.post_type = p_post_type
      )
    order by p.created_at desc
    limit v_limit
  ) q;

  return coalesce(v_result, '[]'::jsonb);
end;
$function$
;

-- ---- public.list_discover_directors(integer,text)  secdef=true  md5=0203cc7bf2be1b45fce01ad546bf383c
CREATE OR REPLACE FUNCTION public.list_discover_directors(p_limit integer DEFAULT 40, p_query text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_q text := lower(trim(coalesce(p_query, '')));
BEGIN
  RETURN coalesce((
    SELECT jsonb_agg(row_data ORDER BY sort_followers DESC, sort_name)
    FROM (
      SELECT
        coalesce(s.follower_count, 0) AS sort_followers,
        lower(s.name) AS sort_name,
        jsonb_build_object(
          'shop_id', s.id,
          'shop_name', s.name,
          'owner_user_id', s.owner_user_id,
          'owner_name', s.owner_name,
          'nickname', coalesce(
            nullif(trim(p.nickname), ''),
            nullif(trim(p.name), ''),
            nullif(trim(s.owner_name), ''),
            s.name
          ),
          'avatar_url', coalesce(
            nullif(trim(p.avatar_url), ''),
            nullif(trim(s.profile_image_url), '')
          ),
          'bio', left(coalesce(s.bio, ''), 120),
          'address', coalesce(s.address, ''),
          'follower_count', coalesce(s.follower_count, 0),
          'shared_case_count', coalesce(s.shared_case_count, 0),
          'is_official', coalesce(s.is_official, false),
          'slug', coalesce(s.slug, ''),
          'is_seed', coalesce(p.is_seed, false),
          'last_seen_at', p.last_seen_at
        ) AS row_data
      FROM public.shops s
      LEFT JOIN public.profiles p ON p.id = s.owner_user_id
      WHERE coalesce(s.is_official, false) = false
        AND (
          v_q = ''
          OR lower(s.name) LIKE '%' || v_q || '%'
          OR lower(coalesce(s.owner_name, '')) LIKE '%' || v_q || '%'
          OR lower(coalesce(p.nickname, '')) LIKE '%' || v_q || '%'
          OR lower(coalesce(p.name, '')) LIKE '%' || v_q || '%'
          OR lower(coalesce(s.address, '')) LIKE '%' || v_q || '%'
        )
      ORDER BY coalesce(s.follower_count, 0) DESC, s.name ASC
      LIMIT v_limit
    ) q
  ), '[]'::jsonb);
END;
$function$
;

-- ---- public.list_fan_boost_supporters_batch(text,uuid[],integer)  secdef=true  md5=e0f584ebada174324c1080beb0a049fc
CREATE OR REPLACE FUNCTION public.list_fan_boost_supporters_batch(p_target_type text DEFAULT 'chart'::text, p_target_ids uuid[] DEFAULT '{}'::uuid[], p_limit_per_target integer DEFAULT 50)
 RETURNS TABLE(target_id uuid, paid_by_customer_id uuid, paid_by_wallet_id uuid, fan_display_name text, avatar_url text, echo_spent integer, boost_count integer, rank_in_target integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_per int := greatest(1, least(coalesce(p_limit_per_target, 50), 200));
begin
  if p_target_ids is null or cardinality(p_target_ids) = 0 then return; end if;
  if v_type not in ('chart', 'community_post') then raise exception 'invalid target_type'; end if;

  return query
  with agg as (
    select
      bp.target_id as tid,
      bp.paid_by_wallet_id as wid,
      (array_agg(bp.paid_by_customer_id order by bp.created_at desc)
        filter (where bp.paid_by_customer_id is not null))[1] as cid,
      coalesce(nullif(trim((
        array_agg(bp.fan_display_name order by bp.created_at desc)
          filter (where nullif(trim(bp.fan_display_name), '') is not null)
      )[1]), ''), '후원자') as fname,
      sum(bp.points_spent)::int as spent,
      count(*)::int as cnt
    from public.boost_placements bp
    where bp.source = 'fan_boost'
      and bp.target_type = v_type
      and bp.target_id = any (p_target_ids)
      and bp.paid_by_wallet_id is not null
    group by bp.target_id, bp.paid_by_wallet_id
  ),
  ranked as (
    select
      a.tid, a.cid, a.wid, a.fname,
      coalesce(nullif(trim(p.avatar_url), ''), '') as av,
      a.spent, a.cnt,
      row_number() over (partition by a.tid order by a.spent desc, a.fname asc)::int as rnk
    from agg a
    left join public.customers c on c.id = a.cid
    left join public.profiles p on p.id = c.user_id
  )
  select r.tid, r.cid, r.wid, r.fname, r.av, r.spent, r.cnt, r.rnk
  from ranked r
  where r.rnk <= v_per
  order by r.tid, r.rnk;
end;
$function$
;

-- ---- public.list_fan_boost_supporters(text,uuid,integer)  secdef=true  md5=4623b96992871cd7b8a4b7fcbd3beb40
CREATE OR REPLACE FUNCTION public.list_fan_boost_supporters(p_target_type text DEFAULT 'chart'::text, p_target_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 200)
 RETURNS TABLE(target_id uuid, paid_by_customer_id uuid, paid_by_wallet_id uuid, fan_display_name text, avatar_url text, echo_spent integer, boost_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
begin
  if p_target_id is null then raise exception 'target_id required'; end if;
  if v_type not in ('chart', 'community_post') then raise exception 'invalid target_type'; end if;

  return query
  with agg as (
    select
      bp.paid_by_wallet_id as wid,
      (array_agg(bp.paid_by_customer_id order by bp.created_at desc)
        filter (where bp.paid_by_customer_id is not null))[1] as cid,
      coalesce(nullif(trim((
        array_agg(bp.fan_display_name order by bp.created_at desc)
          filter (where nullif(trim(bp.fan_display_name), '') is not null)
      )[1]), ''), '후원자') as fname,
      sum(bp.points_spent)::int as spent,
      count(*)::int as cnt
    from public.boost_placements bp
    where bp.source = 'fan_boost'
      and bp.target_type = v_type
      and bp.target_id = p_target_id
      and bp.paid_by_wallet_id is not null
    group by bp.paid_by_wallet_id
  )
  select
    p_target_id, a.cid, a.wid, a.fname,
    coalesce(nullif(trim(p.avatar_url), ''), ''),
    a.spent, a.cnt
  from agg a
  left join public.customers c on c.id = a.cid
  left join public.profiles p on p.id = c.user_id
  order by a.spent desc, a.fname asc
  limit v_limit;
end;
$function$
;

-- ---- public.list_following_feed(integer)  secdef=true  md5=97326afd00a7708642fd2eac5e8870a5
CREATE OR REPLACE FUNCTION public.list_following_feed(p_limit integer DEFAULT 40)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_result jsonb;
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_data order by sort_created desc), '[]'::jsonb)
  into v_result
  from (
    select
      p.created_at as sort_created,
      jsonb_build_object(
        'id', p.id,
        'shop_id', p.shop_id,
        'author_user_id', p.author_user_id,
        'post_type', p.post_type,
        'title', p.title,
        'body', case
          when public.can_view_community_post_full(
            p.visibility, p.shop_id, p.author_user_id, p.id
          ) then p.body
          else ''
        end,
        'style_tags', p.style_tags,
        'region_code', p.region_code,
        'visibility', p.visibility,
        'status', p.status,
        'like_count', p.like_count,
        'comment_count', p.comment_count,
        'save_count', p.save_count,
        'source_chart_id', p.source_chart_id,
        'created_at', p.created_at,
        'updated_at', p.updated_at,
        'is_body_locked', not public.can_view_community_post_full(
          p.visibility, p.shop_id, p.author_user_id, p.id
        ),
        'unlock_cost', 500,
        'shops', jsonb_build_object(
          'id', s.id,
          'name', s.name,
          'owner_name', s.owner_name,
          'tier_badge', s.tier_badge::text,
          'profile_image_url', s.profile_image_url,
          'slug', s.slug,
          'is_official', s.is_official
        ),
        'author_nickname', coalesce(
          nullif(trim(ap.nickname), ''),
          nullif(trim(ap.name), ''),
          nullif(trim(s.owner_name), ''),
          'SORI'
        ),
        'post_media', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', m.id,
              'post_id', m.post_id,
              'image_url', m.image_url,
              'sort_order', m.sort_order
            )
            order by m.sort_order asc
          )
          from public.post_media m
          where m.post_id = p.id
        ), '[]'::jsonb)
      ) as row_data
    from public.community_posts p
    join public.shops s on s.id = p.shop_id
    left join public.profiles ap on ap.id = p.author_user_id
    where p.status = 'published'
      and exists (
        select 1
        from public.subscriptions sub
        where sub.follower_user_id = v_uid
          and (
            (sub.target_type = 'shop' and sub.target_shop_id = p.shop_id)
            or (
              sub.target_type = 'director'
              and sub.target_user_id is not null
              and (
                sub.target_user_id = p.author_user_id
                or sub.target_user_id = s.owner_user_id
              )
            )
          )
      )
    order by p.created_at desc
    limit v_limit
  ) q;

  return coalesce(v_result, '[]'::jsonb);
end;
$function$
;

-- ---- public.list_market_listings_scored(text,integer)  secdef=true  md5=4cad7942414a47452b2a6eee1afeff67
CREATE OR REPLACE FUNCTION public.list_market_listings_scored(p_device_name text DEFAULT ''::text, p_limit integer DEFAULT 50)
 RETURNS TABLE(listing_id uuid, post_id uuid, shop_id uuid, shop_name text, device_name text, price integer, listing_status text, seller_trust_score integer, seller_trust_label text, escrow_status text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
  v_q text := lower(trim(coalesce(p_device_name, '')));
begin
  return query
  select
    ml.id,
    ml.post_id,
    ml.shop_id,
    coalesce(nullif(trim(s.name), ''), 'SORI'),
    ml.device_name,
    ml.price,
    ml.listing_status,
    ml.seller_trust_score,
    ml.seller_trust_label,
    coalesce((
      select eh.status
      from public.market_escrow_holds eh
      where eh.listing_id = ml.id
        and eh.status = 'held'
      limit 1
    ), ''),
    ml.created_at
  from public.market_listings ml
  join public.shops s on s.id = ml.shop_id
  where ml.listing_status in ('active', 'reserved', 'sold')
    and (
      v_q = ''
      or lower(ml.device_name) like '%' || v_q || '%'
      or lower(ml.brand) like '%' || v_q || '%'
      or lower(ml.model) like '%' || v_q || '%'
    )
  order by
    case ml.listing_status
      when 'active' then 0
      when 'reserved' then 1
      else 2
    end,
    ml.seller_trust_score desc,
    ml.created_at desc
  limit v_limit;
end;
$function$
;

-- ---- public.list_my_boost_gifts_for_customer(uuid,integer)  secdef=true  md5=8f86d102b40bae1a082b2f391a3d2220
CREATE OR REPLACE FUNCTION public.list_my_boost_gifts_for_customer(p_customer_id uuid, p_limit integer DEFAULT 50)
 RETURNS TABLE(fan_gift_id uuid, target_type text, chart_id uuid, shop_id uuid, shop_name text, sku text, echo_spent integer, gift_kind text, created_at timestamp with time zone, case_title text, has_thank_you boolean, thank_you_post_id uuid)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select * from public.list_my_boost_gifts(p_customer_id, p_limit);
$function$
;

-- ---- public.list_my_boost_gifts(uuid,integer)  secdef=true  md5=6e4c22614735b6f3757df8f758c3418b
CREATE OR REPLACE FUNCTION public.list_my_boost_gifts(p_fan_customer_id uuid, p_limit integer DEFAULT 50)
 RETURNS TABLE(fan_gift_id uuid, target_type text, chart_id uuid, shop_id uuid, shop_name text, sku text, echo_spent integer, gift_kind text, created_at timestamp with time zone, case_title text, has_thank_you boolean, thank_you_post_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if p_fan_customer_id is null then
    raise exception 'fan_customer_id required';
  end if;

  return query
  select
    fg.id,
    fg.target_type,
    case when fg.target_type = 'chart' then fg.target_id else cp.source_chart_id end,
    fg.beneficiary_shop_id,
    coalesce(nullif(trim(s.name), ''), 'SORI'),
    fg.sku,
    fg.echo_spent,
    fg.gift_kind,
    fg.created_at,
    coalesce(
      nullif(trim(cc.care_name), ''),
      nullif(trim(cc.treatment_summary), ''),
      '케이스'
    ),
    exists (
      select 1 from public.community_posts p
      where p.reply_to_fan_gift_id = fg.id
    ),
    (
      select p.id from public.community_posts p
      where p.reply_to_fan_gift_id = fg.id
      limit 1
    )
  from public.fan_gifts fg
  join public.shops s on s.id = fg.beneficiary_shop_id
  left join public.customer_charts cc
    on fg.target_type = 'chart' and cc.id = fg.target_id
  left join public.community_posts cp
    on fg.target_type = 'community_post' and cp.id = fg.target_id
  where fg.fan_customer_id = p_fan_customer_id
    and fg.status = 'completed'
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    )
  order by fg.created_at desc
  limit v_limit;
end;
$function$
;

-- ---- public.list_my_case_bookmark_ids(integer)  secdef=true  md5=74a3e5cd81f429f2a191575a6aa4e90d
CREATE OR REPLACE FUNCTION public.list_my_case_bookmark_ids(p_limit integer DEFAULT 200)
 RETURNS TABLE(chart_id uuid, folder text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;

  return query
  select b.chart_id, b.folder, b.created_at
  from public.case_bookmarks b
  where b.user_id = v_uid
  order by b.created_at desc
  limit v_limit;
end;
$function$
;

-- ---- public.list_my_region_content_bookmarks(integer)  secdef=true  md5=f0affa4b8e902838616e99292fac87cc
CREATE OR REPLACE FUNCTION public.list_my_region_content_bookmarks(p_limit integer DEFAULT 200)
 RETURNS TABLE(kind text, target_id uuid, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 200), 1), 500);
begin
  if v_uid is null then
    return;
  end if;
  return query
    select b.kind, b.target_id, b.created_at
    from public.region_content_bookmarks b
    where b.user_id = v_uid
    order by b.created_at desc
    limit v_limit;
end;
$function$
;

-- ---- public.list_my_subscriptions(integer)  secdef=true  md5=bcbf5bb9f5d54227410a4243b70ba37b
CREATE OR REPLACE FUNCTION public.list_my_subscriptions(p_limit integer DEFAULT 200)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(s) order by s.created_at desc)
    from (
      select *
      from public.subscriptions
      where follower_user_id = v_uid
      order by created_at desc
      limit v_limit
    ) s
  ), '[]'::jsonb);
end;
$function$
;

-- ---- public.list_my_whispers(text,integer)  secdef=true  md5=e10e4c28516fa8972f9dad301f13da3e
CREATE OR REPLACE FUNCTION public.list_my_whispers(p_box text DEFAULT 'inbox'::text, p_limit integer DEFAULT 40)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_box text := lower(trim(coalesce(p_box, 'inbox')));
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;

  if v_box = 'sent' then
    return coalesce((
      select jsonb_agg(row_data order by sort_at desc)
      from (
        select
          w.created_at as sort_at,
          jsonb_build_object(
            'id', w.id,
            'body', w.body,
            'audience_spec', w.audience_spec,
            'audience_op', w.audience_op,
            'recipient_count', w.recipient_count,
            'truncated', w.truncated,
            'created_at', w.created_at,
            'box', 'sent',
            'read_at', null,
            'sender_user_id', w.sender_user_id,
            'sender_nickname', coalesce(
              nullif(trim(sp.nickname), ''),
              nullif(trim(sp.name), ''),
              '나'
            )
          ) as row_data
        from public.whispers w
        left join public.profiles sp on sp.id = w.sender_user_id
        where w.sender_user_id = v_uid and w.status = 'sent'
        order by w.created_at desc
        limit v_limit
      ) q
    ), '[]'::jsonb);
  end if;

  return coalesce((
    select jsonb_agg(row_data order by sort_at desc)
    from (
      select
        w.created_at as sort_at,
        jsonb_build_object(
          'id', w.id,
          'body', w.body,
          'audience_spec', w.audience_spec,
          'audience_op', w.audience_op,
          'recipient_count', w.recipient_count,
          'truncated', w.truncated,
          'created_at', w.created_at,
          'box', 'inbox',
          'read_at', r.read_at,
          'sender_user_id', w.sender_user_id,
          'sender_nickname', coalesce(
            nullif(trim(sp.nickname), ''),
            nullif(trim(sp.name), ''),
            '원장'
          ),
          'sender_avatar_url', coalesce(sp.avatar_url, '')
        ) as row_data
      from public.whisper_recipients r
      join public.whispers w on w.id = r.whisper_id
      left join public.profiles sp on sp.id = w.sender_user_id
      where r.user_id = v_uid and w.status = 'sent'
      order by w.created_at desc
      limit v_limit
    ) q
  ), '[]'::jsonb);
end;
$function$
;

-- ---- public.list_pending_supporter_notifications(uuid,integer)  secdef=true  md5=fce597c917787823dc0f72255a2745ce
CREATE OR REPLACE FUNCTION public.list_pending_supporter_notifications(p_shop_id uuid, p_limit integer DEFAULT 30)
 RETURNS TABLE(notification_id uuid, kind text, title text, body text, created_at timestamp with time zone, fan_gift_id uuid, chart_id uuid, supporter_name text, supporter_customer_id uuid, has_thank_you boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 30), 100));
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  return query
  select
    n.id,
    n.kind,
    n.title,
    n.body,
    n.created_at,
    nullif(trim(coalesce(n.payload->>'fan_gift_id', '')), '')::uuid,
    nullif(trim(coalesce(n.payload->>'chart_id', '')), '')::uuid,
    coalesce(
      nullif(trim(n.payload->>'supporter_name'), ''),
      nullif(trim(n.payload->>'fan_name'), ''),
      '후원자'
    ),
    nullif(trim(coalesce(n.payload->>'customer_id', '')), '')::uuid,
    exists (
      select 1 from public.community_posts cp
      where cp.reply_to_fan_gift_id =
        nullif(trim(coalesce(n.payload->>'fan_gift_id', '')), '')::uuid
    )
  from public.shop_notifications n
  where n.shop_id = p_shop_id
    and n.kind in ('fan_boost', 'special_supporter')
  order by n.created_at desc
  limit v_limit;
end;
$function$
;

-- ---- public.list_review_request_events(uuid,integer)  secdef=true  md5=5e4f7be9bbb5b98e13a7eafd73b0888e
CREATE OR REPLACE FUNCTION public.list_review_request_events(p_shop_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 80)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_limit int := greatest(1, least(coalesce(p_limit, 80), 200));
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;

  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;
  if v_shop is null then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(to_jsonb(e) order by e.sent_at desc)
    from (
      select *
      from public.review_request_events r
      where r.shop_id = v_shop
      order by r.sent_at desc
      limit v_limit
    ) e
  ), '[]'::jsonb);
end;
$function$
;

-- ---- public.list_shop_supporters(uuid,text,integer)  secdef=true  md5=341ce8dc0d660fd892c49529dc8be9fb
CREATE OR REPLACE FUNCTION public.list_shop_supporters(p_shop_id uuid, p_sort text DEFAULT 'echo_desc'::text, p_limit integer DEFAULT 50)
 RETURNS TABLE(supporter_customer_id uuid, display_name text, avatar_url text, echo_spent integer, boost_count integer, last_boost_at timestamp with time zone, supporter_tier text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_sort text := lower(trim(coalesce(p_sort, 'echo_desc')));
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if p_shop_id is null then raise exception 'shop_id required'; end if;

  return query
  with gifts as (
    select
      fg.fan_customer_id as cid,
      coalesce(nullif(trim(fg.fan_display_name), ''), '후원자') as fname,
      sum(fg.echo_spent)::int as spent,
      count(*)::int as cnt,
      max(fg.created_at) as last_at,
      max(case fg.gift_kind
        when 'boost_special_platinum' then 3
        when 'boost_special_gold' then 2
        else 1
      end)::int as gift_rank
    from public.fan_gifts fg
    where fg.beneficiary_shop_id = p_shop_id
      and fg.status = 'completed'
      and fg.gift_kind in (
        'boost', 'boost_with_ai_fill',
        'boost_special_gold', 'boost_special_platinum'
      )
    group by fg.fan_customer_id, coalesce(nullif(trim(fg.fan_display_name), ''), '후원자')
  ),
  ranked as (
    select
      a.*,
      row_number() over (order by a.spent desc, a.fname asc)::int as rnk
    from gifts a
  )
  select
    r.cid,
    r.fname,
    coalesce(nullif(trim(p.avatar_url), ''), ''),
    r.spent,
    r.cnt,
    r.last_at,
    case
      when r.gift_rank >= 3 then 'platinum'
      when r.gift_rank >= 2 then 'gold'
      when r.rnk = 1 and r.spent >= 50 then 'top'
      when r.rnk <= 3 and r.spent >= 200 then 'premium'
      else 'supporter'
    end
  from ranked r
  left join public.customers c on c.id = r.cid
  left join public.profiles p on p.id = c.user_id
  order by
    case when v_sort = 'recent' then extract(epoch from r.last_at) end desc nulls last,
    case when v_sort = 'count_desc' then r.cnt end desc nulls last,
    case when v_sort = 'echo_desc' or v_sort not in ('recent', 'count_desc') then r.spent end desc nulls last,
    r.fname asc
  limit v_limit;
end;
$function$
;

-- ---- public.list_unified_community_feed(text,integer,integer)  secdef=true  md5=6590df4481ec15f720ee898a9cba0845
CREATE OR REPLACE FUNCTION public.list_unified_community_feed(p_filter text DEFAULT 'all'::text, p_limit integer DEFAULT 80, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_filter text := lower(trim(coalesce(p_filter, 'all')));
  v_limit int := greatest(1, least(coalesce(p_limit, 80), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_result jsonb;
begin
  with base as (
    select u.*
    from public.unified_feed_items_v1 u
    where
      case v_filter
        when 'all' then
          -- PO: only public whispers in 전체; other whispers excluded
          (u.feed_kind <> 'whisper')
          or (
            u.feed_kind = 'whisper'
            and u.visibility = 'public'
            and coalesce(u.feed_metadata ->> 'is_public', 'false') = 'true'
          )
          or (
            u.feed_kind = 'whisper'
            and u.visibility = 'public'
            and exists (
              select 1
              from public.community_posts cp
              where cp.id = u.source_post_id
                and coalesce(cp.audience_spec -> 'atoms', '[]'::jsonb) ? 'everyone'
            )
          )
        when 'whisper' then u.feed_kind = 'whisper'
        when 'interior' then u.feed_kind = 'interior'
        when 'device_review' then u.feed_kind = 'device_review'
        when 'marketplace' then u.feed_kind = 'marketplace'
        when 'seminar' then u.feed_kind = 'seminar'
        when 'ba' then u.feed_kind = 'ba'
        else true
      end
  ),
  ranked as (
    select
      b.*,
      row_number() over (order by b.sort_at desc nulls last, b.feed_id) as rn
    from base b
  ),
  page as (
    select * from ranked
    where rn > v_offset and rn <= v_offset + v_limit
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'feed_id', feed_id,
      'kind', feed_kind,
      'shop_id', shop_id,
      'author_user_id', author_user_id,
      'sort_at', sort_at,
      'source_post_id', source_post_id,
      'source_chart_id', source_chart_id,
      'source_seminar_id', source_seminar_id,
      'feed_metadata', feed_metadata,
      'visibility', visibility
    ) order by rn
  ), '[]'::jsonb)
  into v_result
  from page;

  return jsonb_build_object(
    'items', v_result,
    'filter', v_filter,
    'limit', v_limit,
    'offset', v_offset
  );
end;
$function$
;

-- ---- public.mark_best_community_comment(uuid,integer)  secdef=true  md5=5808139a6f987bf7bef3743d2402daa7
CREATE OR REPLACE FUNCTION public.mark_best_community_comment(p_comment_id uuid, p_bonus integer DEFAULT 3)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_c public.community_comments%rowtype;
  v_bonus int := greatest(coalesce(p_bonus, 3), 1);
  v_res jsonb;
begin
  select * into v_c from public.community_comments where id = p_comment_id;
  if not found then
    raise exception 'comment not found';
  end if;
  if v_c.author_shop_id is null then
    raise exception 'comment has no author shop';
  end if;

  v_res := public.credit_free_echo_capped(
    v_c.author_shop_id, v_bonus, 'earn_best_comment',
    'community_comment', p_comment_id, '베스트 댓글 +3 Echo'
  );

  return jsonb_build_object(
    'ok', true,
    'comment_id', p_comment_id,
    'shop_id', v_c.author_shop_id,
    'bonus', v_bonus,
    'credit', v_res
  );
end;
$function$
;

-- ---- public.mark_review_request_reminded(uuid)  secdef=true  md5=3c8d0fdb393d938b4290b1e0b5990683
CREATE OR REPLACE FUNCTION public.mark_review_request_reminded(p_event_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or p_event_id is null then
    return false;
  end if;

  update public.review_request_events r
  set reminded_at = now(), updated_at = now()
  where r.id = p_event_id
    and r.reminded_at is null
    and exists (
      select 1 from public.shops s
      where s.id = r.shop_id
        and (
          s.owner_user_id = v_uid
          or exists (
            select 1 from public.shop_memberships m
            where m.shop_id = s.id and m.user_id = v_uid
          )
        )
    );

  return found;
end;
$function$
;

-- ---- public.mark_whisper_read(uuid)  secdef=true  md5=3f0e3fbefb495796f70bebb4f7fb4e72
CREATE OR REPLACE FUNCTION public.mark_whisper_read(p_whisper_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  update public.whisper_recipients
  set read_at = coalesce(read_at, now())
  where whisper_id = p_whisper_id and user_id = v_uid;
  return jsonb_build_object('ok', true);
end;
$function$
;

-- ---- public.merge_shop_customers(uuid,uuid[],jsonb)  secdef=true  md5=cf9f948e6849796b4d93348b04dcb473
CREATE OR REPLACE FUNCTION public.merge_shop_customers(p_primary_id uuid, p_source_ids uuid[], p_options jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

-- ---- public.pick_boost_slot_targets(text,integer,text,integer)  secdef=true  md5=255f13de947b192c985de8b1ee6b3677
CREATE OR REPLACE FUNCTION public.pick_boost_slot_targets(p_segment text DEFAULT 'case'::text, p_slot_count integer DEFAULT 4, p_viewer_seed text DEFAULT ''::text, p_pool_size integer DEFAULT 40)
 RETURNS TABLE(target_id uuid, placement_id uuid, score numeric, slot_rank integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_slots int := greatest(0, least(coalesce(p_slot_count, 4), 20));
  v_pool int := greatest(1, least(coalesce(p_pool_size, 40), 200));
  v_seed text := coalesce(nullif(trim(p_viewer_seed), ''), public.feed_viewer_seed('', p_segment));
begin
  if v_slots = 0 then
    return;
  end if;

  return query
  with scored as (
    select *
    from public.list_boost_candidates_scored(p_segment, v_pool)
  ),
  shuffled as (
    select
      s.target_id,
      s.placement_id,
      s.score,
      row_number() over (
        order by public.feed_seed_rank(v_seed, s.placement_id::text),
                 s.score desc
      ) as rn
    from scored s
  )
  select
    sh.target_id,
    sh.placement_id,
    sh.score,
    sh.rn::int
  from shuffled sh
  where sh.rn <= v_slots
  order by sh.rn;
end;
$function$
;

-- ---- public.post_body_needs_fan_fill(text,text,text,text)  secdef=false  md5=09b29a620915200579b85112a1490cb5
CREATE OR REPLACE FUNCTION public.post_body_needs_fan_fill(p_body text, p_summary text DEFAULT ''::text, p_insight text DEFAULT ''::text, p_care_name text DEFAULT ''::text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
declare
  v_body text := trim(coalesce(p_body, ''));
  v_summary text := trim(coalesce(p_summary, ''));
  v_insight text := trim(coalesce(p_insight, ''));
  v_care text := trim(coalesce(p_care_name, ''));
  v_generic text;
begin
  if v_summary <> '' and length(v_summary) >= 80 then
    return false;
  end if;
  if v_insight <> '' and length(v_insight) >= 80 then
    return false;
  end if;
  if v_body = '' then
    return true;
  end if;
  if length(v_body) < 80 then
    return true;
  end if;
  if v_care <> '' then
    v_generic := v_care || ' 임상 기록 공유 (고객 정보는 비식별화되었습니다)';
    if v_body = v_generic then
      return true;
    end if;
  end if;
  if v_body ilike '%임상 기록 공유 (고객 정보는 비식별화되었습니다)%'
     and length(v_body) < 120 then
    return true;
  end if;
  return false;
end;
$function$
;

-- ---- public.preview_whisper_audience(uuid,text,text[],uuid[],uuid[],integer)  secdef=true  md5=cc8dae7670d9b4d0060c157e688427fe
CREATE OR REPLACE FUNCTION public.preview_whisper_audience(p_shop_id uuid DEFAULT NULL::uuid, p_op text DEFAULT 'union'::text, p_atoms text[] DEFAULT '{}'::text[], p_explicit_user_ids uuid[] DEFAULT '{}'::uuid[], p_explicit_shop_ids uuid[] DEFAULT '{}'::uuid[], p_max integer DEFAULT 500)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_count int;
  v_preview jsonb;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;
  if v_shop is null
     or not exists (
       select 1 from public.shops s
       where s.id = v_shop
         and (
           s.owner_user_id = v_uid
           or exists (
             select 1 from public.shop_memberships m
             where m.shop_id = s.id and m.user_id = v_uid
           )
         )
     ) then
    raise exception 'shop access denied';
  end if;

  select count(*)::int into v_count
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, p_op, p_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, p_max
  );

  select coalesce(jsonb_agg(row_data), '[]'::jsonb) into v_preview
  from (
    select jsonb_build_object(
      'user_id', r.user_id,
      'atom_bits', r.atom_bits,
      'nickname', coalesce(
        nullif(trim(p.nickname), ''),
        nullif(trim(p.name), ''),
        'SORI'
      ),
      'avatar_url', coalesce(p.avatar_url, '')
    ) as row_data
    from public.resolve_whisper_audience_users(
      v_uid, v_shop, p_op, p_atoms,
      p_explicit_user_ids, p_explicit_shop_ids, least(12, p_max)
    ) r
    left join public.profiles p on p.id = r.user_id
  ) q;

  return jsonb_build_object(
    'ok', true,
    'count', coalesce(v_count, 0),
    'preview', coalesce(v_preview, '[]'::jsonb),
    'op', lower(trim(coalesce(p_op, 'union'))),
    'atoms', to_jsonb(coalesce(p_atoms, '{}'::text[]))
  );
end;
$function$
;

-- ---- public.program_customer_coupon_counts(uuid)  secdef=true  md5=65e38ff0cd9b6953f0ba63d47719c7b4
CREATE OR REPLACE FUNCTION public.program_customer_coupon_counts(p_shop_id uuid)
 RETURNS TABLE(customer_id uuid, unused_count integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select c.customer_id, count(*)::int
    from public.program_customer_coupons c
   where c.shop_id = p_shop_id
     and c.status = 'issued'
     and public.program_shop_is_director(p_shop_id)
   group by c.customer_id;
$function$
;

-- ---- public.program_expire_coupons(uuid)  secdef=true  md5=bbec688fd00886c018fbf1fc7a09803c
CREATE OR REPLACE FUNCTION public.program_expire_coupons(p_shop_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_n int;
begin
  if not public.program_shop_is_director(p_shop_id) then
    raise exception 'not director of shop' using errcode = '42501';
  end if;

  update public.program_customer_coupons
     set status = 'expired'
   where shop_id = p_shop_id
     and status = 'issued'
     and expires_at is not null
     and expires_at < now();
  get diagnostics v_n = row_count;
  return v_n;
end $function$
;

-- ---- public.program_shop_is_director(uuid)  secdef=true  md5=d4a3c0ea08dc60ceee5f5fb563a1107a
CREATE OR REPLACE FUNCTION public.program_shop_is_director(p_shop_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.shop_memberships sm
    where sm.shop_id = p_shop_id
      and sm.user_id = auth.uid()
      and sm.role in ('owner', 'director')
  );
$function$
;

-- ---- public.program_sweep_quotes(uuid)  secdef=true  md5=3f3bf4eceeeb8a242f84b4076d1f2b10
CREATE OR REPLACE FUNCTION public.program_sweep_quotes(p_shop_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_n int;
begin
  if not public.program_shop_is_director(p_shop_id) then
    raise exception 'not director of shop' using errcode = '42501';
  end if;

  -- 당일을 넘긴 미수락 견적은 이탈로 닫는다. 삭제하지 않는다 (재상담 리드).
  update public.program_quotes
     set status = 'abandoned'
   where shop_id = p_shop_id
     and status in ('draft', 'presented')
     and created_at < date_trunc('day', now());
  get diagnostics v_n = row_count;
  return v_n;
end $function$
;

-- ---- public.program_sync_quote_paid()  secdef=true  md5=029e86aa39793d2fccdbcfdf4a2b891b
CREATE OR REPLACE FUNCTION public.program_sync_quote_paid()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_quote_id uuid := coalesce(new.quote_id, old.quote_id);
  v_sum int;
  v_due int;
begin
  select coalesce(sum(amount_krw), 0) into v_sum
    from public.program_quote_payments
   where quote_id = v_quote_id;

  select payable_krw into v_due
    from public.program_quotes
   where id = v_quote_id;

  update public.program_quotes
     set paid_krw = v_sum,
         paid_at = case
           when v_sum >= coalesce(v_due, 0) and v_sum > 0 then now()
           else null end,
         payment_status = case
           when v_sum <= 0 then 'unpaid'
           when v_sum >= coalesce(v_due, 0) then 'paid'
           else 'partial' end
   where id = v_quote_id;

  return null;
end $function$
;

-- ---- public.publish_mentoring_post(uuid)  secdef=true  md5=016129cdf819c4726a04fb080e6a8da6
CREATE OR REPLACE FUNCTION public.publish_mentoring_post(p_mentoring_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_post public.mentoring_posts%rowtype;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  select * into v_post from public.mentoring_posts where id = p_mentoring_id;
  if not found then raise exception 'mentoring not found'; end if;
  if v_post.author_user_id <> v_uid then raise exception 'forbidden'; end if;
  if char_length(trim(v_post.body_locked)) < 20 then
    raise exception 'body too short';
  end if;

  update public.mentoring_posts
  set
    status = 'active',
    published_at = coalesce(published_at, now()),
    updated_at = now()
  where id = p_mentoring_id;

  return jsonb_build_object('ok', true, 'status', 'active');
end;
$function$
;

-- ---- public.purchase_ai_tool(uuid,uuid,text)  secdef=true  md5=8cbf7a1d5807a88babd404577ea97506
CREATE OR REPLACE FUNCTION public.purchase_ai_tool(p_shop_id uuid, p_chart_id uuid, p_sku text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item public.point_shop_items%rowtype;
  v_sku text := lower(trim(coalesce(p_sku, '')));
  v_chart_shop uuid;
  v_period text := public.ai_tool_period_key();
  v_used int := 0;
  v_limit int := 5;
  v_no_free boolean := false;
  v_mode text := 'marketing';
  v_charged int := 0;
  v_via text := 'free_quota';
  v_debit jsonb;
  v_wallet public.wallets%rowtype;
  v_have int;
  v_job public.ai_tool_jobs%rowtype;
  v_settlement_before int;
begin
  if p_shop_id is null or p_chart_id is null or v_sku = '' then
    raise exception 'shop_id, chart_id, sku required';
  end if;

  select shop_id into v_chart_shop
  from public.customer_charts where id = p_chart_id;
  if v_chart_shop is null or v_chart_shop is distinct from p_shop_id then
    raise exception 'chart does not belong to shop';
  end if;

  select * into v_item
  from public.point_shop_items
  where sku = v_sku and is_active = true and category = 'ai_tool';
  if not found then
    raise exception 'ai_tool sku not found: %', v_sku;
  end if;

  v_mode := coalesce(nullif(v_item.metadata->>'mode', ''), 'marketing');
  v_no_free := coalesce((v_item.metadata->>'no_free_quota')::boolean, false);

  if not v_no_free then
    insert into public.ai_tool_quota as q (shop_id, period_key, free_used, free_limit)
    values (p_shop_id, v_period, 0, 5)
    on conflict (shop_id, period_key) do nothing;

    select q.free_used, q.free_limit
    into v_used, v_limit
    from public.ai_tool_quota q
    where q.shop_id = p_shop_id and q.period_key = v_period
    for update;

    if v_used < v_limit then
      v_charged := 0;
      v_via := 'free_quota';
      update public.ai_tool_quota
      set free_used = free_used + 1, updated_at = now()
      where shop_id = p_shop_id and period_key = v_period;
    else
      v_charged := v_item.price_points;
      v_via := 'echo_wallet';
    end if;
  else
    v_charged := v_item.price_points;
    v_via := 'echo_wallet';
  end if;

  if v_charged > 0 then
    v_wallet := public.ensure_shop_wallet(p_shop_id);
    select * into v_wallet from public.wallets where id = v_wallet.id for update;
    v_settlement_before := v_wallet.settlement_balance;
    v_have := v_wallet.point_free_balance + v_wallet.point_paid_balance;
    if v_have < v_charged then
      raise exception 'insufficient points: have %, need %', v_have, v_charged
        using errcode = 'P0001', hint = format('gap=%s', v_charged - v_have);
    end if;

    v_debit := public.debit_points(
      p_shop_id,
      v_charged,
      'shop_spend',
      'ai_tool_job',
      v_item.id,
      null,
      coalesce(v_item.title, v_sku)
    );

    select * into v_wallet from public.wallets where shop_id = p_shop_id;
    if v_wallet.settlement_balance is distinct from v_settlement_before then
      raise exception 'settlement_balance must not change on ai_tool purchase';
    end if;
  end if;

  insert into public.ai_tool_jobs (
    shop_id, chart_id, sku, mode, status, charged_echo, charged_via
  ) values (
    p_shop_id, p_chart_id, v_item.sku, v_mode, 'queued', v_charged, v_via
  )
  returning * into v_job;

  return jsonb_build_object(
    'ok', true,
    'job_id', v_job.id,
    'sku', v_item.sku,
    'mode', v_mode,
    'charged_echo', v_charged,
    'charged_via', v_via,
    'quota', public.get_ai_tool_quota(p_shop_id),
    'debit', v_debit
  );
end;
$function$
;

-- ---- public.purchase_fan_boost(uuid,text,text,uuid,text,text)  secdef=true  md5=dbede959a7835238b2fa61c7273871dc
CREATE OR REPLACE FUNCTION public.purchase_fan_boost(p_customer_id uuid, p_sku text, p_target_type text DEFAULT 'chart'::text, p_target_id uuid DEFAULT NULL::uuid, p_fan_display_name text DEFAULT ''::text, p_region_code text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.purchase_fan_gift(
    p_customer_id, p_sku, p_target_type, p_target_id, p_fan_display_name, p_region_code
  );
$function$
;

-- ---- public.purchase_fan_gift(uuid,text,text,uuid,text,text)  secdef=true  md5=d2219384506431f601e2c6618d52b448
CREATE OR REPLACE FUNCTION public.purchase_fan_gift(p_fan_customer_id uuid, p_sku text, p_target_type text DEFAULT 'chart'::text, p_target_id uuid DEFAULT NULL::uuid, p_fan_display_name text DEFAULT ''::text, p_region_code text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item public.point_shop_items%rowtype;
  v_wallet public.wallets%rowtype;
  v_target_shop uuid;
  v_shop_wallet public.wallets%rowtype;
  v_settlement_before int;
  v_settlement_after int;
  v_debit jsonb;
  v_placement public.boost_placements%rowtype;
  v_gift public.fan_gifts%rowtype;
  v_sku text := lower(trim(coalesce(p_sku, '')));
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_need int;
  v_starts timestamptz := now();
  v_ends timestamptz;
  v_chart_id uuid;
  v_post_id uuid;
  v_name text;
  v_tx_id uuid;
  v_ai_fill jsonb;
begin
  if p_fan_customer_id is null then
    raise exception 'fan_customer_id required';
  end if;
  if v_sku = '' or p_target_id is null then
    raise exception 'sku and target_id required';
  end if;
  if v_type not in ('chart', 'community_post') then
    raise exception 'invalid target_type';
  end if;

  select * into v_item
  from public.point_shop_items
  where sku = v_sku and is_active = true and category = 'booster';
  if not found then
    raise exception 'booster sku not found: %', v_sku;
  end if;

  if v_type = 'chart' then
    select shop_id into v_target_shop from public.customer_charts where id = p_target_id;
    v_chart_id := p_target_id;
  else
    select shop_id, source_chart_id into v_target_shop, v_chart_id
    from public.community_posts where id = p_target_id;
    v_post_id := p_target_id;
  end if;

  if v_target_shop is null then
    raise exception 'target shop not found';
  end if;

  v_shop_wallet := public.ensure_shop_wallet(v_target_shop);
  select * into v_shop_wallet from public.wallets where id = v_shop_wallet.id for update;
  v_settlement_before := v_shop_wallet.settlement_balance;

  v_wallet := public.ensure_customer_wallet(p_fan_customer_id);
  v_need := v_item.price_points;

  v_debit := public.debit_echo_wallet(
    v_wallet.id, v_need, 'fan_boost_spend',
    'point_shop_item', v_item.id,
    'Supporter boost ' || v_item.title,
    v_target_shop
  );

  v_tx_id := nullif(trim(coalesce(v_debit->>'tx_id', '')), '')::uuid;

  select settlement_balance into v_settlement_after
  from public.wallets where id = v_shop_wallet.id;
  if v_settlement_after is distinct from v_settlement_before then
    raise exception 'Supporter gift must not change shop settlement_balance';
  end if;

  select * into v_wallet from public.wallets where id = v_wallet.id;
  if coalesce(v_wallet.settlement_balance, 0) <> 0 then
    raise exception 'customer wallet must not hold settlement';
  end if;

  v_ends := v_starts + make_interval(hours => v_item.duration_hours);

  update public.boost_placements
  set status = 'cancelled', updated_at = now()
  where status = 'active'
    and target_type = v_type
    and target_id = p_target_id;

  select coalesce(nullif(trim(p_fan_display_name), ''), c.name, '후원자')
  into v_name
  from public.customers c where c.id = p_fan_customer_id;

  insert into public.boost_placements (
    shop_id, item_id, item_sku, target_type, target_id,
    post_id, chart_id, region_code,
    starts_at, ends_at, status, points_spent,
    source, paid_by_customer_id, paid_by_wallet_id, fan_display_name
  ) values (
    v_target_shop, v_item.id, v_item.sku, v_type, p_target_id,
    v_post_id, v_chart_id, coalesce(p_region_code, ''),
    v_starts, v_ends, 'active', v_need,
    'fan_boost', p_fan_customer_id, v_wallet.id, coalesce(v_name, '후원자')
  )
  returning * into v_placement;

  insert into public.fan_gifts (
    beneficiary_shop_id, target_type, target_id,
    fan_customer_id, fan_wallet_id, fan_display_name,
    gift_kind, sku, echo_spent,
    boost_placement_id, point_tx_id, status
  ) values (
    v_target_shop, v_type, p_target_id,
    p_fan_customer_id, v_wallet.id, coalesce(v_name, '후원자'),
    'boost', v_item.sku, v_need,
    v_placement.id, v_tx_id, 'completed'
  )
  returning * into v_gift;

  v_ai_fill := jsonb_build_object('ok', false, 'skipped', true);
  if v_chart_id is not null then
    v_ai_fill := public.run_fan_boost_ai_fill(
      v_target_shop,
      v_chart_id,
      p_fan_customer_id,
      coalesce(v_name, '후원자'),
      v_gift.id
    );
  end if;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_target_shop,
    'fan_boost',
    '후원 알림',
    case
      when coalesce(v_ai_fill->>'skipped', 'true') = 'false' then
        format('%s님이 부스터를 지원하며 케이스 스토리를 완성해 주었습니다', coalesce(v_name, '○○'))
      else
        format('%s님이 부스터를 지원했습니다', coalesce(v_name, '○○'))
    end,
    jsonb_build_object(
      'placement_id', v_placement.id,
      'fan_gift_id', v_gift.id,
      'customer_id', p_fan_customer_id,
      'sku', v_item.sku,
      'chart_id', v_chart_id,
      'supporter_name', coalesce(v_name, '후원자'),
      'fan_name', coalesce(v_name, '후원자'),
      'ai_fill', v_ai_fill
    )
  );

  return jsonb_build_object(
    'ok', true,
    'sku', v_item.sku,
    'points_spent', v_need,
    'source', 'fan_boost',
    'target_shop_id', v_target_shop,
    'settlement_balance', v_settlement_after,
    'settlement_unchanged', true,
    'debit', v_debit,
    'placement', to_jsonb(v_placement),
    'fan_gift', to_jsonb(v_gift),
    'ai_fill', v_ai_fill,
    'notification', true
  );
end;
$function$
;

-- ---- public.purchase_mentoring_unlock(uuid,uuid)  secdef=true  md5=b37ca967c605bd8672fddc7a5ac55740
CREATE OR REPLACE FUNCTION public.purchase_mentoring_unlock(p_mentoring_id uuid, p_buyer_customer_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_post public.mentoring_posts%rowtype;
  v_buyer uuid := p_buyer_customer_id;
  v_wallet public.wallets%rowtype;
  v_debit jsonb;
  v_tx_id uuid;
  v_purchase_id uuid;
begin
  if v_uid is null and v_buyer is null then
    raise exception 'auth required';
  end if;

  select * into v_post
  from public.mentoring_posts
  where id = p_mentoring_id
  for update;

  if not found then raise exception 'mentoring not found'; end if;
  if v_post.status <> 'active' then
    raise exception 'mentoring not available for purchase (status=%)', v_post.status;
  end if;

  if v_buyer is null then
    select c.id into v_buyer from public.customers c where c.user_id = v_uid limit 1;
  end if;
  if v_buyer is null then raise exception 'buyer customer not found'; end if;

  if exists (
    select 1 from public.mentoring_purchases mp
    where mp.mentoring_post_id = p_mentoring_id
      and mp.buyer_customer_id = v_buyer
  ) then
    return jsonb_build_object(
      'ok', true,
      'already_purchased', true,
      'body_locked', v_post.body_locked
    );
  end if;

  v_wallet := public.ensure_customer_wallet(v_buyer);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  v_debit := public.debit_echo_wallet(
    v_wallet.id,
    v_post.price_echo,
    'mentoring_purchase',
    'mentoring_post',
    v_post.id,
    'Premium Mentoring unlock',
    v_post.author_shop_id
  );

  v_tx_id := nullif(trim(coalesce(v_debit->>'tx_id', '')), '')::uuid;

  perform public.credit_points(
    v_post.author_shop_id,
    v_post.price_echo,
    'paid',
    'mentoring_sale',
    'mentoring_post',
    v_post.id,
    null,
    'Premium Mentoring sale'
  );

  insert into public.mentoring_purchases (
    mentoring_post_id,
    buyer_customer_id,
    echo_paid,
    price_at_purchase,
    point_tx_id
  ) values (
    v_post.id,
    v_buyer,
    v_post.price_echo,
    v_post.price_echo,
    v_tx_id
  )
  returning id into v_purchase_id;

  update public.mentoring_posts
  set
    purchase_count = purchase_count + 1,
    revenue_echo_total = revenue_echo_total + v_post.price_echo,
    updated_at = now()
  where id = v_post.id;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_post.author_shop_id,
    'mentoring_purchase_received',
    'Premium Mentoring sold',
    format('%sE mentoring unlocked on your case', v_post.price_echo),
    jsonb_build_object(
      'mentoring_post_id', v_post.id,
      'purchase_id', v_purchase_id,
      'echo_paid', v_post.price_echo
    )
  );

  return jsonb_build_object(
    'ok', true,
    'purchase_id', v_purchase_id,
    'echo_paid', v_post.price_echo,
    'body_locked', v_post.body_locked
  );
end;
$function$
;

-- ---- public.purchase_point_shop_item(uuid,text,text,uuid,text)  secdef=true  md5=5cfaf677c9d134bed129aa362645f819
CREATE OR REPLACE FUNCTION public.purchase_point_shop_item(p_shop_id uuid, p_sku text, p_target_type text DEFAULT 'chart'::text, p_target_id uuid DEFAULT NULL::uuid, p_region_code text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item public.point_shop_items%rowtype;
  v_wallet public.wallets%rowtype;
  v_debit jsonb;
  v_placement public.boost_placements%rowtype;
  v_sku text := lower(trim(coalesce(p_sku, '')));
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_need int;
  v_have int;
  v_starts timestamptz := now();
  v_ends timestamptz;
  v_chart_id uuid;
  v_post_id uuid;
  v_settlement_before int;
  v_promo_id uuid;
  v_promo_balance int := 0;
  v_used_promo boolean := false;
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;
  if v_sku = '' then
    raise exception 'sku required';
  end if;
  if v_type not in ('chart', 'community_post') then
    raise exception 'invalid target_type %', v_type;
  end if;
  if p_target_id is null then
    raise exception 'target_id required';
  end if;

  select * into v_item
  from public.point_shop_items
  where sku = v_sku and is_active = true;
  if not found then
    raise exception 'shop item not found: %', v_sku;
  end if;

  if v_item.category = 'booster' and v_item.duration_hours <= 0 then
    raise exception 'booster requires duration_hours';
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);
  select * into v_wallet from public.wallets where id = v_wallet.id for update;
  v_settlement_before := v_wallet.settlement_balance;
  v_have := v_wallet.point_free_balance + v_wallet.point_paid_balance;
  v_need := v_item.price_points;

  -- Promo credit (e.g. legacy spotlight coupons)
  if v_item.category = 'booster' then
    select c.id, c.balance into v_promo_id, v_promo_balance
    from public.shop_promo_credits c
    where c.shop_id = p_shop_id
      and c.credit_sku = v_item.sku
      and c.balance > 0
    order by c.created_at
    limit 1
    for update;

    if v_promo_balance > 0 then
      update public.shop_promo_credits
      set balance = balance - 1, updated_at = now()
      where id = v_promo_id;
      v_need := 0;
      v_used_promo := true;
    end if;
  end if;

  if v_need > 0 and v_have < v_need then
    raise exception 'insufficient points: have %, need %', v_have, v_need
      using errcode = 'P0001',
            hint = format('gap=%s', v_need - v_have);
  end if;

  if v_need > 0 then
    v_debit := public.debit_points(
      p_shop_id,
      v_need,
      case when v_item.category = 'booster' then 'boost_spend' else 'shop_spend' end,
      'point_shop_item',
      v_item.id,
      null,
      coalesce(v_item.title, v_sku)
    );
  end if;

  select * into v_wallet from public.wallets where shop_id = p_shop_id;
  if v_wallet.settlement_balance is distinct from v_settlement_before then
    raise exception 'settlement_balance must not change on point shop purchase';
  end if;

  if v_item.category = 'booster' then
    v_ends := v_starts + make_interval(hours => v_item.duration_hours);

    if v_type = 'chart' then
      v_chart_id := p_target_id;
      v_post_id := null;
    else
      v_post_id := p_target_id;
      v_chart_id := null;
    end if;

    update public.boost_placements
    set status = 'cancelled', updated_at = now()
    where status = 'active'
      and target_type = v_type
      and target_id = p_target_id;

    insert into public.boost_placements (
      shop_id, item_id, item_sku, target_type, target_id,
      post_id, chart_id, region_code,
      starts_at, ends_at, status, points_spent
    ) values (
      p_shop_id, v_item.id, v_item.sku, v_type, p_target_id,
      v_post_id, v_chart_id, coalesce(p_region_code, ''),
      v_starts, v_ends, 'active',
      case when v_used_promo then 0 else v_need end
    )
    returning * into v_placement;
  end if;

  return jsonb_build_object(
    'ok', true,
    'sku', v_item.sku,
    'category', v_item.category,
    'points_spent', case when v_used_promo then 0 else v_need end,
    'used_promo_credit', v_used_promo,
    'debit', v_debit,
    'promo_credits', public.get_shop_promo_credits(p_shop_id),
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'settlement_balance', v_wallet.settlement_balance,
    'placement', case
      when v_placement.id is null then null
      else to_jsonb(v_placement)
    end
  );
end;
$function$
;

-- ---- public.purchase_sori_points_customer(uuid,integer,text,text)  secdef=true  md5=8f54a5c45a983c7042b13be1de9ae487
CREATE OR REPLACE FUNCTION public.purchase_sori_points_customer(p_customer_id uuid, p_amount integer, p_sku text DEFAULT 'sori_e_55'::text, p_order_ref text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_amount int := coalesce(p_amount, 0);
  v_wallet public.wallets%rowtype;
begin
  if v_amount <= 0 then
    raise exception 'purchase amount must be > 0';
  end if;
  v_wallet := public.ensure_customer_wallet(p_customer_id);
  update public.wallets
  set point_paid_balance = point_paid_balance + v_amount,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  insert into public.point_transactions (
    wallet_id, shop_id, customer_id, amount, bucket, kind,
    ref_type, note,
    balance_point_free_after, balance_point_paid_after
  ) values (
    v_wallet.id, v_wallet.shop_id, p_customer_id, v_amount, 'paid', 'purchase',
    'iap_order', coalesce(nullif(trim(p_order_ref), ''), p_sku),
    v_wallet.point_free_balance, v_wallet.point_paid_balance
  );

  return jsonb_build_object(
    'ok', true,
    'customer_id', p_customer_id,
    'amount', v_amount,
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'settlement_balance', v_wallet.settlement_balance
  );
end;
$function$
;

-- ---- public.purchase_sori_points(uuid,integer,text,text)  secdef=true  md5=cf2c8be45caecd0f51973619ee6a49c1
CREATE OR REPLACE FUNCTION public.purchase_sori_points(p_shop_id uuid, p_amount integer, p_sku text DEFAULT 'sori_points_pack'::text, p_order_ref text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_amount int := coalesce(p_amount, 0);
  v_tx public.point_transactions%rowtype;
  v_wallet public.wallets%rowtype;
begin
  if v_amount <= 0 then
    raise exception 'purchase amount must be > 0';
  end if;

  v_tx := public.credit_points(
    p_shop_id, v_amount, 'paid', 'purchase',
    'iap_order', null, null,
    coalesce(nullif(trim(p_order_ref), ''), p_sku)
  );
  select * into v_wallet from public.wallets where shop_id = p_shop_id;

  return jsonb_build_object(
    'ok', true,
    'shop_id', p_shop_id,
    'credited', v_amount,
    'sku', p_sku,
    'currency', 'point',
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'settlement_balance', v_wallet.settlement_balance,
    'tx_id', v_tx.id
  );
end;
$function$
;

-- ---- public.purchase_special_gift(uuid,text,text,uuid,text,text)  secdef=true  md5=7627f052b8aac169056daf19513330e5
CREATE OR REPLACE FUNCTION public.purchase_special_gift(p_customer_id uuid, p_sku text, p_target_type text DEFAULT 'chart'::text, p_target_id uuid DEFAULT NULL::uuid, p_fan_display_name text DEFAULT ''::text, p_region_code text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.purchase_special_supporter_gift(
    p_customer_id, p_sku, p_target_type, p_target_id, p_fan_display_name, p_region_code
  );
$function$
;

-- ---- public.purchase_special_supporter_gift(uuid,text,text,uuid,text,text)  secdef=true  md5=af77d78559ac7701eddc6ec2a1af6679
CREATE OR REPLACE FUNCTION public.purchase_special_supporter_gift(p_fan_customer_id uuid, p_sku text, p_target_type text DEFAULT 'chart'::text, p_target_id uuid DEFAULT NULL::uuid, p_fan_display_name text DEFAULT ''::text, p_region_code text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item public.point_shop_items%rowtype;
  v_wallet public.wallets%rowtype;
  v_target_shop uuid;
  v_shop_wallet public.wallets%rowtype;
  v_settlement_before int;
  v_settlement_after int;
  v_debit jsonb;
  v_overlay public.boost_premium_overlays%rowtype;
  v_gift public.fan_gifts%rowtype;
  v_sku text := lower(trim(coalesce(p_sku, '')));
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_tier text;
  v_gift_kind text;
  v_need int;
  v_starts timestamptz := now();
  v_ends timestamptz;
  v_chart_id uuid;
  v_post_id uuid;
  v_name text;
  v_tx_id uuid;
begin
  if p_fan_customer_id is null then
    raise exception 'fan_customer_id required';
  end if;
  if v_sku = '' or p_target_id is null then
    raise exception 'sku and target_id required';
  end if;
  if v_type not in ('chart', 'community_post') then
    raise exception 'invalid target_type';
  end if;

  select * into v_item
  from public.point_shop_items
  where sku = v_sku and is_active = true and category = 'supporter_gift';
  if not found then
    raise exception 'supporter_gift sku not found: %', v_sku;
  end if;

  v_tier := public.sku_premium_tier(v_sku);
  if v_tier not in ('gold', 'platinum') then
    raise exception 'invalid premium tier for sku: %', v_sku;
  end if;
  v_gift_kind := case v_tier
    when 'gold' then 'boost_special_gold'
    else 'boost_special_platinum'
  end;

  if v_type = 'chart' then
    select shop_id into v_target_shop from public.customer_charts where id = p_target_id;
    v_chart_id := p_target_id;
  else
    select shop_id, source_chart_id into v_target_shop, v_chart_id
    from public.community_posts where id = p_target_id;
    v_post_id := p_target_id;
  end if;

  if v_target_shop is null then
    raise exception 'target shop not found';
  end if;

  v_shop_wallet := public.ensure_shop_wallet(v_target_shop);
  select * into v_shop_wallet from public.wallets where id = v_shop_wallet.id for update;
  v_settlement_before := v_shop_wallet.settlement_balance;

  v_wallet := public.ensure_customer_wallet(p_fan_customer_id);
  v_need := v_item.price_points;

  v_debit := public.debit_echo_wallet(
    v_wallet.id, v_need, 'fan_boost_spend',
    'point_shop_item', v_item.id,
    'Special supporter ' || v_item.title,
    v_target_shop
  );

  v_tx_id := nullif(trim(coalesce(v_debit->>'tx_id', '')), '')::uuid;

  select settlement_balance into v_settlement_after
  from public.wallets where id = v_shop_wallet.id;
  if v_settlement_after is distinct from v_settlement_before then
    raise exception 'Special supporter gift must not change shop settlement_balance';
  end if;

  select * into v_wallet from public.wallets where id = v_wallet.id;
  if coalesce(v_wallet.settlement_balance, 0) <> 0 then
    raise exception 'customer wallet must not hold settlement';
  end if;

  v_ends := v_starts + make_interval(hours => v_item.duration_hours);

  -- Overlay stacks — do NOT cancel boost_placements.
  -- Same-tier active overlay on same target is replaced.
  update public.boost_premium_overlays
  set status = 'cancelled'
  where status = 'active'
    and target_type = v_type
    and target_id = p_target_id
    and tier = v_tier;

  select coalesce(nullif(trim(p_fan_display_name), ''), c.name, '후원자')
  into v_name
  from public.customers c where c.id = p_fan_customer_id;

  insert into public.boost_premium_overlays (
    beneficiary_shop_id, target_type, target_id, chart_id, post_id,
    tier, sku, fan_customer_id, fan_wallet_id, fan_display_name,
    echo_spent, starts_at, ends_at, status
  ) values (
    v_target_shop, v_type, p_target_id, v_chart_id, v_post_id,
    v_tier, v_item.sku, p_fan_customer_id, v_wallet.id, coalesce(v_name, '후원자'),
    v_need, v_starts, v_ends, 'active'
  )
  returning * into v_overlay;

  insert into public.fan_gifts (
    beneficiary_shop_id, target_type, target_id,
    fan_customer_id, fan_wallet_id, fan_display_name,
    gift_kind, sku, echo_spent,
    point_tx_id, status
  ) values (
    v_target_shop, v_type, p_target_id,
    p_fan_customer_id, v_wallet.id, coalesce(v_name, '후원자'),
    v_gift_kind, v_item.sku, v_need,
    v_tx_id, 'completed'
  )
  returning * into v_gift;

  update public.boost_premium_overlays
  set fan_gift_id = v_gift.id
  where id = v_overlay.id;

  insert into public.shop_notifications (
    shop_id, kind, title, body, payload
  ) values (
    v_target_shop,
    'special_supporter',
    '스페셜 후원 알림',
    format(
      '%s님이 %s 스페셜 후원을 보냈습니다',
      coalesce(v_name, '○○'),
      case v_tier when 'platinum' then '플래티넘' else '골드' end
    ),
    jsonb_build_object(
      'overlay_id', v_overlay.id,
      'fan_gift_id', v_gift.id,
      'customer_id', p_fan_customer_id,
      'sku', v_item.sku,
      'tier', v_tier,
      'chart_id', v_chart_id,
      'supporter_name', coalesce(v_name, '후원자'),
      'overlay_stacks', true
    )
  );

  return jsonb_build_object(
    'ok', true,
    'sku', v_item.sku,
    'tier', v_tier,
    'points_spent', v_need,
    'source', 'special_supporter',
    'target_shop_id', v_target_shop,
    'settlement_balance', v_settlement_after,
    'settlement_unchanged', true,
    'debit', v_debit,
    'overlay', to_jsonb(v_overlay),
    'fan_gift', to_jsonb(v_gift),
    'notification', true
  );
end;
$function$
;

-- ---- public.queue_fan_boost_edge_fill(uuid,uuid)  secdef=true  md5=682060f6ac3221a390ddac4b74a65f5b
CREATE OR REPLACE FUNCTION public.queue_fan_boost_edge_fill(p_job_id uuid, p_chart_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_url text;
  v_key text;
begin
  if p_job_id is null or p_chart_id is null then
    return;
  end if;

  begin
    select decrypted_secret into v_url
    from vault.decrypted_secrets
    where name = 'supabase_url'
    limit 1;
    select decrypted_secret into v_key
    from vault.decrypted_secrets
    where name = 'service_role_key'
    limit 1;
  exception when others then
    return;
  end;

  if coalesce(v_url, '') = '' or coalesce(v_key, '') = '' then
    return;
  end if;

  begin
    perform net.http_post(
      url := rtrim(v_url, '/') || '/functions/v1/ai-case-story',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_key
      ),
      body := jsonb_build_object(
        'chart_id', p_chart_id,
        'mode', 'dual',
        'job_id', p_job_id,
        'internal_fan_fill', true
      )
    );
  exception when others then
    null;
  end;
end;
$function$
;

-- ---- public.record_affiliate_conversion(uuid,integer,text,integer,uuid,uuid,uuid,text)  secdef=true  md5=09112650c6d3a2c212e0a20ee6daa967
CREATE OR REPLACE FUNCTION public.record_affiliate_conversion(p_shop_id uuid, p_commission_amount integer, p_order_ref text DEFAULT ''::text, p_gross_amount integer DEFAULT 0, p_link_id uuid DEFAULT NULL::uuid, p_click_id uuid DEFAULT NULL::uuid, p_post_id uuid DEFAULT NULL::uuid, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.affiliate_conversions%rowtype;
begin
  insert into public.affiliate_conversions (
    shop_id,
    link_id,
    click_id,
    post_id,
    order_ref,
    gross_amount,
    commission_amount,
    status,
    note
  ) values (
    p_shop_id,
    p_link_id,
    p_click_id,
    p_post_id,
    coalesce(p_order_ref, ''),
    coalesce(p_gross_amount, 0),
    coalesce(p_commission_amount, 0),
    'pending',
    coalesce(p_note, '')
  )
  returning * into v_row;

  return to_jsonb(v_row);
end;
$function$
;

-- ---- public.record_chart_view(uuid,text)  secdef=true  md5=e67835dbebf700506e64b1f130f55825
CREATE OR REPLACE FUNCTION public.record_chart_view(p_chart_id uuid, p_session_key text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_shop uuid;
  v_session text := nullif(trim(coalesce(p_session_key, '')), '');
  v_recent timestamptz;
begin
  if p_chart_id is null then
    raise exception 'chart_id required';
  end if;

  select cc.shop_id into v_shop
  from public.customer_charts cc
  where cc.id = p_chart_id;

  if v_shop is null then
    raise exception 'chart not found';
  end if;

  if v_uid is not null then
    select max(cve.created_at) into v_recent
    from public.chart_view_events cve
    where cve.chart_id = p_chart_id
      and cve.viewer_id = v_uid
      and cve.created_at > now() - interval '24 hours';
  elsif v_session is not null then
    select max(cve.created_at) into v_recent
    from public.chart_view_events cve
    where cve.chart_id = p_chart_id
      and cve.session_key = v_session
      and cve.created_at > now() - interval '24 hours';
  end if;

  if v_recent is not null then
    return jsonb_build_object('ok', true, 'deduped', true);
  end if;

  insert into public.chart_view_events (chart_id, shop_id, viewer_id, session_key)
  values (p_chart_id, v_shop, v_uid, v_session);

  return jsonb_build_object('ok', true, 'deduped', false);
end;
$function$
;

-- ---- public.refresh_market_listing_trust(uuid)  secdef=true  md5=216403bd066f336c72559e5a8f3cbf01
CREATE OR REPLACE FUNCTION public.refresh_market_listing_trust(p_listing_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_shop uuid;
  v_trust jsonb;
begin
  select shop_id into v_shop
  from public.market_listings
  where id = p_listing_id;

  if v_shop is null then return; end if;

  v_trust := public.get_shop_trust_score(v_shop);

  update public.market_listings
  set seller_trust_score = coalesce((v_trust->>'score')::int, 0),
      seller_trust_label = coalesce(v_trust->>'tier_label', '성장 중'),
      updated_at = now()
  where id = p_listing_id;
end;
$function$
;

-- ---- public.refresh_seminar_feedback_report(uuid)  secdef=true  md5=a19c190172c5c9145f232dde429e45ba
CREATE OR REPLACE FUNCTION public.refresh_seminar_feedback_report(p_class_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_class public.seminar_classes%rowtype;
  v_count int;
  v_top_tags jsonb;
  v_top1 text;
  v_top2 text;
  v_strength text;
  v_improvement text;
  v_report_id uuid;
begin
  if p_class_id is null then
    return null;
  end if;

  select * into v_class
  from public.seminar_classes
  where id = p_class_id;

  if not found then
    return null;
  end if;

  select count(*)::int into v_count
  from public.seminar_enrollment_reviews r
  inner join public.seminar_enrollments e on e.id = r.enrollment_id
  where e.class_id = p_class_id;

  if coalesce(v_count, 0) < 1 then
    return null;
  end if;

  select coalesce(jsonb_agg(tag order by cnt desc), '[]'::jsonb)
  into v_top_tags
  from (
    select tag, count(*)::int as cnt
    from public.seminar_enrollment_reviews r
    inner join public.seminar_enrollments e on e.id = r.enrollment_id
    cross join lateral jsonb_array_elements_text(r.insight_tags) as tag
    where e.class_id = p_class_id
    group by tag
    order by cnt desc
    limit 8
  ) t;

  v_top1 := coalesce(v_top_tags->>0, '#이해쏙쏙');
  v_top2 := coalesce(v_top_tags->>1, '#실무적용도100%');

  v_strength :=
    '수강생 ' || v_count || '명의 피드백에서 '
    || v_top1 || ', ' || v_top2
    || ' 인사이트가 두드러졌습니다. '
    || '현장 설명력과 임상 케이스 전달력이 높게 평가됐으며, '
    || '수강생 다수가 실무에 바로 적용 가능하다고 응답했습니다.';

  v_improvement :=
    '다음 기수에서는 Q&A·실습 비중을 '
    || case
      when v_count >= 5 then '15~20%'
      else '10%'
    end
    || ' 늘리고, 초급·중급 맞춤 블록을 분리하면 만족도가 더 올라갈 것으로 보입니다. '
    || '또한 ' || v_top1 || ' 강점을 유지하면서 사전 자료 공유를 추가하면 재등록률 개선에 도움이 됩니다.';

  insert into public.seminar_feedback_reports (
    class_id,
    shop_id,
    top_insight_tags,
    ai_summary_strength,
    ai_summary_improvement,
    raw_feedback_count,
    updated_at
  )
  values (
    p_class_id,
    v_class.director_shop_id,
    coalesce(v_top_tags, '[]'::jsonb),
    v_strength,
    v_improvement,
    v_count,
    now()
  )
  on conflict (class_id) do update
  set
    shop_id = excluded.shop_id,
    top_insight_tags = excluded.top_insight_tags,
    ai_summary_strength = excluded.ai_summary_strength,
    ai_summary_improvement = excluded.ai_summary_improvement,
    raw_feedback_count = excluded.raw_feedback_count,
    updated_at = now()
  returning id into v_report_id;

  return v_report_id;
end;
$function$
;

-- ---- public.refresh_shop_tier_badge(uuid)  secdef=true  md5=22d48d5720d8f743e08c0f7e0a8e5b8c
CREATE OR REPLACE FUNCTION public.refresh_shop_tier_badge(p_shop_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.update_shop_tier_badge(p_shop_id);
end;
$function$
;

-- ---- public.refund_market_escrow(uuid)  secdef=true  md5=11690c55fe0d608c0372ce5ea146a2a2
CREATE OR REPLACE FUNCTION public.refund_market_escrow(p_listing_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  update public.market_escrow_holds
  set status = 'refunded', completed_at = now()
  where listing_id = p_listing_id and status = 'held'
  returning id into v_id;

  if v_id is null then
    raise exception 'no held escrow';
  end if;

  update public.market_listings
  set listing_status = 'active', updated_at = now()
  where id = p_listing_id;

  return jsonb_build_object('ok', true, 'escrow_id', v_id, 'status', 'refunded');
end;
$function$
;

-- ---- public.request_seminar_interest(uuid,uuid,uuid)  secdef=true  md5=5a6daf38e14c9f4dd7a699ef806a8d1d
CREATE OR REPLACE FUNCTION public.request_seminar_interest(p_case_id uuid, p_requestor_shop_id uuid DEFAULT NULL::uuid, p_requestor_user_id uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_owner_shop uuid;
  v_count int;
  v_exists boolean := false;
begin
  if p_case_id is null then
    raise exception 'case_id required';
  end if;
  if p_requestor_shop_id is null and p_requestor_user_id is null then
    raise exception 'requestor_shop_id or requestor_user_id required';
  end if;

  select c.shop_id into v_owner_shop
  from public.customer_charts c
  where c.id = p_case_id;

  if v_owner_shop is null then
    raise exception 'case not found';
  end if;

  if p_requestor_shop_id is not null then
    select exists (
      select 1
      from public.seminar_requests r
      where r.case_id = p_case_id
        and r.requestor_shop_id = p_requestor_shop_id
    ) into v_exists;

    if not v_exists then
      insert into public.seminar_requests (
        case_id,
        requestor_shop_id,
        requestor_user_id
      ) values (
        p_case_id,
        p_requestor_shop_id,
        p_requestor_user_id
      );
    elsif p_requestor_user_id is not null then
      update public.seminar_requests
      set requestor_user_id = coalesce(requestor_user_id, p_requestor_user_id)
      where case_id = p_case_id
        and requestor_shop_id = p_requestor_shop_id;
    end if;
  else
    select exists (
      select 1
      from public.seminar_requests r
      where r.case_id = p_case_id
        and r.requestor_user_id = p_requestor_user_id
    ) into v_exists;

    if not v_exists then
      insert into public.seminar_requests (
        case_id,
        requestor_shop_id,
        requestor_user_id
      ) values (
        p_case_id,
        null,
        p_requestor_user_id
      );
    end if;
  end if;

  if to_regprocedure('public.sync_shop_tier_metrics(uuid)') is not null then
    perform public.sync_shop_tier_metrics(v_owner_shop);
  else
    select count(*)::int into v_count
    from public.seminar_requests r
    inner join public.customer_charts c on c.id = r.case_id
    where c.shop_id = v_owner_shop;

    update public.shops
    set
      seminar_request_count = coalesce(v_count, 0),
      updated_at = now()
    where id = v_owner_shop;
  end if;

  select coalesce(seminar_request_count, 0) into v_count
  from public.shops
  where id = v_owner_shop;

  return coalesce(v_count, 0);
end;
$function$
;

-- ---- public.request_settlement_withdraw(uuid,integer,text,text)  secdef=true  md5=1478186f4aceb55d8948982a403583e4
CREATE OR REPLACE FUNCTION public.request_settlement_withdraw(p_shop_id uuid, p_amount integer, p_bank_account_mask text DEFAULT ''::text, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_wallet public.wallets%rowtype;
  v_tx public.settlement_transactions%rowtype;
  v_amount int := coalesce(p_amount, 0);
begin
  if v_amount <= 0 then
    raise exception 'withdraw amount must be > 0';
  end if;

  v_wallet := public.ensure_shop_wallet(p_shop_id);
  -- Lock and read ONLY settlement_balance (never touch point_*)
  select * into v_wallet from public.wallets where id = v_wallet.id for update;

  if v_wallet.settlement_balance < v_amount then
    raise exception 'insufficient settlement: have %, need %',
      v_wallet.settlement_balance, v_amount
      using errcode = 'P0001';
  end if;

  update public.wallets
  set settlement_balance = settlement_balance - v_amount,
      settlement_pending = settlement_pending + v_amount,
      updated_at = now()
  where id = v_wallet.id
  returning * into v_wallet;

  update public.shops
  set sori_cash_balance = v_wallet.settlement_balance,
      updated_at = now()
  where id = p_shop_id;

  insert into public.settlement_transactions (
    wallet_id, shop_id, amount, kind, status,
    ref_type, note, balance_after, bank_account_mask
  ) values (
    v_wallet.id, p_shop_id, -v_amount, 'withdraw_request', 'pending',
    'withdraw', coalesce(p_note, '계좌 환전 요청'),
    v_wallet.settlement_balance,
    coalesce(p_bank_account_mask, '')
  )
  returning * into v_tx;

  return jsonb_build_object(
    'ok', true,
    'shop_id', p_shop_id,
    'amount', v_amount,
    'settlement_balance', v_wallet.settlement_balance,
    'settlement_pending', v_wallet.settlement_pending,
    'point_free_balance', v_wallet.point_free_balance,
    'point_paid_balance', v_wallet.point_paid_balance,
    'tx_id', v_tx.id,
    'status', 'pending'
  );
end;
$function$
;

-- ---- public.require_staff(text[])  secdef=true  md5=decedb19b9811cd9cc9d299f0eabe62d
CREATE OR REPLACE FUNCTION public.require_staff(p_roles text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.has_staff_role(p_roles) then
    raise exception 'forbidden: requires staff role %', p_roles;
  end if;
end;
$function$
;

-- ---- public.resolve_whisper_audience_users(uuid,uuid,text,text[],uuid[],uuid[],integer)  secdef=true  md5=d73302869132e33d2eab732add213a8b
CREATE OR REPLACE FUNCTION public.resolve_whisper_audience_users(p_sender uuid, p_shop_id uuid, p_op text, p_atoms text[], p_explicit_user_ids uuid[] DEFAULT '{}'::uuid[], p_explicit_shop_ids uuid[] DEFAULT '{}'::uuid[], p_max integer DEFAULT 500)
 RETURNS TABLE(user_id uuid, atom_bits integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_op text := lower(trim(coalesce(p_op, 'union')));
  v_max int := greatest(1, least(coalesce(p_max, 500), 500));
  v_has_everyone boolean := 'everyone' = any (p_atoms);
  v_has_visited boolean := 'visited' = any (p_atoms);
  v_has_followers boolean := 'followers' = any (p_atoms);
  v_has_following boolean := 'following' = any (p_atoms);
  v_has_peers boolean := 'peer_directors' = any (p_atoms);
  v_has_super boolean := 'super_fans' = any (p_atoms);
  v_has_explicit boolean := 'explicit' = any (p_atoms);
  v_has_seminar_hosts boolean := 'seminar_hosts' = any (p_atoms);
  v_has_customer_mode boolean := 'customer_mode' = any (p_atoms);
begin
  if v_op not in ('union', 'intersect') then
    v_op := 'union';
  end if;

  return query
  with
  a0 as (
    select p.id as uid, 32 as bits
    from public.profiles p
    where v_has_everyone
      and p.id <> p_sender
      and p.role in ('director', 'customer')
  ),
  -- 차트 고객: charts written in this shop with linked user_id
  a1 as (
    select distinct c.user_id as uid, 1 as bits
    from public.customer_charts cc
    join public.customers c on c.id = cc.customer_id
    where v_has_visited
      and p_shop_id is not null
      and cc.shop_id = p_shop_id
      and c.user_id is not null
      and c.user_id <> p_sender
  ),
  a2 as (
    select distinct s.follower_user_id as uid, 2 as bits
    from public.subscriptions s
    where v_has_followers
      and s.follower_user_id <> p_sender
      and (
        (s.target_type = 'shop' and s.target_shop_id = p_shop_id)
        or (s.target_type = 'director' and s.target_user_id = p_sender)
      )
  ),
  -- 내 팔로우: users/shops the sender follows → resolve to profile ids
  a2b as (
    select distinct x.uid, 256 as bits
    from (
      select s.target_user_id as uid
      from public.subscriptions s
      where v_has_following
        and s.follower_user_id = p_sender
        and s.target_type = 'director'
        and s.target_user_id is not null
      union
      select m.user_id as uid
      from public.subscriptions s
      join public.shop_memberships m
        on m.shop_id = s.target_shop_id
       and m.is_public = true
      where v_has_following
        and s.follower_user_id = p_sender
        and s.target_type = 'shop'
        and m.user_id is not null
    ) x
    where x.uid is not null and x.uid <> p_sender
  ),
  -- 원장 유저: all director-role profiles on SORI
  a3 as (
    select distinct p.id as uid, 4 as bits
    from public.profiles p
    where v_has_peers
      and p.id <> p_sender
      and p.role = 'director'
  ),
  a4 as (
    select distinct c.user_id as uid, 8 as bits
    from public.boost_placements bp
    join public.customers c on c.id = bp.paid_by_customer_id
    where v_has_super
      and bp.source = 'fan_boost'
      and bp.created_at > now() - interval '90 days'
      and c.user_id is not null
      and c.user_id <> p_sender
      and (
        bp.shop_id = p_shop_id
        or exists (
          select 1 from public.customer_charts cc
          where cc.id = bp.chart_id and cc.shop_id = p_shop_id
        )
      )
  ),
  a5 as (
    select distinct x.uid, 16 as bits
    from (
      select unnest(coalesce(p_explicit_user_ids, '{}'::uuid[])) as uid
      where v_has_explicit
      union
      select m.user_id
      from public.shop_memberships m
      where v_has_explicit
        and m.is_public = true
        and m.shop_id = any (coalesce(p_explicit_shop_ids, '{}'::uuid[]))
    ) x
    where x.uid is not null and x.uid <> p_sender
  ),
  a6 as (
    select distinct sm.user_id as uid, 64 as bits
    from public.shop_memberships sm
    join public.seminar_classes sc on sc.director_shop_id = sm.shop_id
    where v_has_seminar_hosts
      and sm.user_id <> p_sender
      and sm.is_public = true
      and sc.status in ('open', 'held', 'completed')
  ),
  a7 as (
    select distinct p.id as uid, 128 as bits
    from public.profiles p
    where v_has_customer_mode
      and p.id <> p_sender
      and p.role = 'customer'
  ),
  atoms as (
    select * from a0
    union all select * from a1
    union all select * from a2
    union all select * from a2b
    union all select * from a3
    union all select * from a4
    union all select * from a5
    union all select * from a6
    union all select * from a7
  ),
  merged as (
    select a.uid, bit_or(a.bits)::int as bits
    from atoms a
    group by a.uid
  ),
  filtered as (
    select m.uid, m.bits
    from merged m
    where
      case
        when v_op = 'intersect' then
          (
            (not v_has_everyone or (m.bits & 32) <> 0)
            and (not v_has_visited or (m.bits & 1) <> 0)
            and (not v_has_followers or (m.bits & 2) <> 0)
            and (not v_has_following or (m.bits & 256) <> 0)
            and (not v_has_peers or (m.bits & 4) <> 0)
            and (not v_has_super or (m.bits & 8) <> 0)
            and (not v_has_explicit or (m.bits & 16) <> 0)
            and (not v_has_seminar_hosts or (m.bits & 64) <> 0)
            and (not v_has_customer_mode or (m.bits & 128) <> 0)
            and (
              (v_has_everyone or v_has_visited or v_has_followers or v_has_following
               or v_has_peers or v_has_super or v_has_explicit
               or v_has_seminar_hosts or v_has_customer_mode)
            )
          )
        else true
      end
  )
  select f.uid, f.bits
  from filtered f
  order by
    (f.bits & 32) desc,
    (f.bits & 8) desc,
    (f.bits & 4) desc,
    f.uid
  limit v_max;
end;
$function$
;

-- ---- public.respond_mentoring_request(uuid,boolean)  secdef=true  md5=90ca8a1555235281b5760aa46c66cb0c
CREATE OR REPLACE FUNCTION public.respond_mentoring_request(p_request_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_req public.mentoring_requests%rowtype;
  v_chart public.customer_charts%rowtype;
  v_post_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  select * into v_req
  from public.mentoring_requests
  where id = p_request_id
  for update;

  if not found then raise exception 'request not found'; end if;
  if v_req.status <> 'pending' then raise exception 'request not pending'; end if;

  select * into v_chart from public.customer_charts where id = v_req.chart_id;
  if v_chart.shop_id is null then raise exception 'chart shop missing'; end if;

  if not exists (
    select 1 from public.shops s
    where s.id = v_chart.shop_id and s.owner_user_id = v_uid
  ) then
    raise exception 'forbidden';
  end if;

  if not p_accept then
    update public.mentoring_requests
    set status = 'rejected', author_response_at = now()
    where id = p_request_id;
    return jsonb_build_object('ok', true, 'accepted', false);
  end if;

  update public.mentoring_requests
  set status = 'accepted', author_response_at = now()
  where id = p_request_id;

  begin
    insert into public.mentoring_posts (
      chart_id, author_shop_id, author_user_id,
      origin, request_id, preview_teaser, status
    ) values (
      v_req.chart_id,
      v_chart.shop_id,
      v_uid,
      'request',
      v_req.id,
      left(v_req.question_body, 200),
      'draft'
    )
    returning id into v_post_id;
  exception when unique_violation then
    select mp.id into v_post_id
    from public.mentoring_posts mp
    where mp.chart_id = v_req.chart_id
      and mp.status <> 'archived'
    limit 1;
  end;

  if v_post_id is null then
    select mp.id into v_post_id
    from public.mentoring_posts mp
    where mp.chart_id = v_req.chart_id
      and mp.status <> 'archived'
    limit 1;
  end if;

  return jsonb_build_object(
    'ok', true,
    'accepted', true,
    'mentoring_post_id', v_post_id
  );
end;
$function$
;

-- ---- public.review_grand_director_tiers()  secdef=true  md5=62f4999874b0dc19f585555e294018ff
CREATE OR REPLACE FUNCTION public.review_grand_director_tiers()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r record;
  v_rolling int;
begin
  for r in
    select s.id
    from public.shops s
    where s.tier_badge::text = 'grand_director'
  loop
    v_rolling := public.shop_rolling_12m_funding(r.id);
    if coalesce(v_rolling, 0) < 100000000 then
      update public.shops
      set tier_badge = 'grand_master'::public.shop_tier_badge,
          updated_at = now()
      where id = r.id;
    end if;
  end loop;
end;
$function$
;

-- ---- public.run_fan_boost_ai_fill(uuid,uuid,uuid,text,uuid)  secdef=true  md5=72c3ef6eecb8e0b7399a49c0cdfe1c5c
CREATE OR REPLACE FUNCTION public.run_fan_boost_ai_fill(p_shop_id uuid, p_chart_id uuid, p_fan_customer_id uuid, p_fan_display_name text, p_fan_gift_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_chart public.customer_charts%rowtype;
  v_customer public.customers%rowtype;
  v_post public.community_posts%rowtype;
  v_fill jsonb;
  v_job public.ai_tool_jobs%rowtype;
  v_apply jsonb;
  v_post_body text := '';
begin
  select * into v_chart from public.customer_charts where id = p_chart_id;
  if not found then
    return jsonb_build_object('ok', false, 'skipped', true, 'reason', 'no_chart');
  end if;

  select * into v_customer from public.customers where id = v_chart.customer_id;

  select p.* into v_post
  from public.community_posts p
  where p.source_chart_id = p_chart_id and p.status = 'published'
  order by p.created_at desc
  limit 1;
  if found then
    v_post_body := coalesce(v_post.body, '');
  end if;

  if not public.post_body_needs_fan_fill(
    v_post_body,
    v_chart.treatment_summary,
    v_chart.director_insight,
    v_chart.care_name
  ) then
    return jsonb_build_object('ok', true, 'skipped', true, 'reason', 'body_sufficient');
  end if;

  insert into public.ai_tool_jobs (
    shop_id, chart_id, sku, mode, status,
    charged_echo, charged_via,
    fan_customer_id, fan_display_name, community_post_id, fan_gift_id
  ) values (
    p_shop_id, p_chart_id, 'ai_copy_dual', 'dual', 'queued',
    0, 'fan_boost_bundle',
    p_fan_customer_id, coalesce(nullif(trim(p_fan_display_name), ''), '팬'),
    v_post.id, p_fan_gift_id
  )
  returning * into v_job;

  update public.fan_gifts
  set
    gift_kind = 'boost_with_ai_fill',
    ai_tool_job_id = v_job.id
  where id = p_fan_gift_id;

  -- Immediate sync fill (edge-equivalent fallback) inside transaction.
  v_fill := public.fan_boost_build_fill_copy(v_chart, v_customer);
  v_apply := public.fan_boost_apply_fill(p_chart_id, v_fill, p_fan_gift_id);

  update public.ai_tool_jobs
  set
    status = 'done',
    result = v_fill || jsonb_build_object('apply', v_apply),
    completed_at = now()
  where id = v_job.id
  returning * into v_job;

  -- Async OpenAI upgrade when vault + pg_net configured.
  perform public.queue_fan_boost_edge_fill(v_job.id, p_chart_id);

  return jsonb_build_object(
    'ok', true,
    'skipped', false,
    'job_id', v_job.id,
    'fill', v_fill,
    'apply', v_apply,
    'edge_queued', true
  );
end;
$function$
;

-- ---- public.save_chart_and_publish_case(uuid,uuid,boolean,text,text,text[],uuid)  secdef=true  md5=7bd80394340ec1207a62141924db4d04
CREATE OR REPLACE FUNCTION public.save_chart_and_publish_case(p_chart_id uuid, p_shop_id uuid, p_publish boolean DEFAULT true, p_title text DEFAULT NULL::text, p_body text DEFAULT NULL::text, p_image_urls text[] DEFAULT '{}'::text[], p_author_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_chart public.customer_charts%rowtype;
  v_post_id uuid;
  v_title text;
  v_body text;
  v_urls text[];
  v_url text;
  v_ord int := 0;
  v_existing uuid;
begin
  if p_chart_id is null or p_shop_id is null then
    raise exception 'chart_id and shop_id required';
  end if;

  select * into v_chart
  from public.customer_charts
  where id = p_chart_id
  for update;

  if not found then
    raise exception 'chart not found: %', p_chart_id;
  end if;

  if v_chart.shop_id is distinct from p_shop_id then
    raise exception 'shop_id mismatch for chart';
  end if;

  if not coalesce(p_publish, false) then
    update public.customer_charts
    set is_case_shared = false,
        case_shared = false,
        updated_at = now()
    where id = p_chart_id;
    return jsonb_build_object(
      'chart_id', p_chart_id,
      'published', false,
      'post_id', null
    );
  end if;

  -- ★ SNS 마케팅 동의 게이트
  perform public.assert_chart_community_publishable(p_chart_id);

  update public.customer_charts
  set is_case_shared = true,
      case_shared = true,
      updated_at = now()
  where id = p_chart_id;

  select p.id into v_existing
  from public.community_posts p
  where p.source_chart_id = p_chart_id
    and p.post_type = 'case_share'
  order by p.created_at desc
  limit 1;

  if v_existing is not null then
    return jsonb_build_object(
      'chart_id', p_chart_id,
      'published', true,
      'post_id', v_existing,
      'deduped', true
    );
  end if;

  v_title := nullif(trim(coalesce(p_title, '')), '');
  if v_title is null then
    v_title := trim(coalesce(v_chart.care_name, '')) || ' · 임상 케이스';
    if trim(coalesce(v_chart.care_name, '')) = '' then
      v_title := '시술 케이스 · 임상 케이스';
    end if;
  end if;

  v_body := nullif(trim(coalesce(p_body, '')), '');
  if v_body is null then
    v_body := trim(both E'\n' from concat_ws(
      E'\n\n',
      nullif(trim(coalesce(v_chart.treatment_summary, '')), ''),
      nullif(trim(coalesce(v_chart.director_insight, '')), '')
    ));
    if v_body is null or v_body = '' then
      v_body := coalesce(nullif(trim(v_chart.care_name), ''), '시술')
        || ' 임상 기록 공유 (고객 정보는 비식별화되었습니다)';
    end if;
  end if;

  insert into public.community_posts (
    shop_id,
    author_user_id,
    post_type,
    title,
    body,
    style_tags,
    visibility,
    status,
    source_chart_id
  ) values (
    p_shop_id,
    p_author_user_id,
    'case_share',
    v_title,
    v_body,
    array['케이스공유', '비식별']::text[],
    'public',
    'published',
    p_chart_id
  )
  returning id into v_post_id;

  v_urls := coalesce(p_image_urls, '{}'::text[]);
  if coalesce(array_length(v_urls, 1), 0) = 0 then
    v_urls := array_remove(array[
      nullif(trim(coalesce(v_chart.before_image_url, '')), ''),
      nullif(trim(coalesce(v_chart.after_image_url, '')), '')
    ], null);
  end if;

  foreach v_url in array coalesce(v_urls, '{}'::text[])
  loop
    if v_url is null or length(trim(v_url)) = 0 then
      continue;
    end if;
    if v_url not like 'http%' and v_url not like 'data:%' then
      continue;
    end if;
    insert into public.post_media (post_id, image_url, sort_order)
    values (v_post_id, trim(v_url), v_ord);
    v_ord := v_ord + 1;
  end loop;

  return jsonb_build_object(
    'chart_id', p_chart_id,
    'published', true,
    'post_id', v_post_id,
    'deduped', false
  );
exception
  when others then
    raise;
end;
$function$
;

-- ---- public.send_thank_you_whisper(uuid,text)  secdef=true  md5=afafbfe55ee8cd751aba9e999d3de0ce
CREATE OR REPLACE FUNCTION public.send_thank_you_whisper(p_fan_gift_id uuid, p_body text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_gift public.fan_gifts%rowtype;
  v_shop uuid;
  v_supporter_user uuid;
  v_body text;
  v_post_id uuid;
  v_name text;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_fan_gift_id is null then
    raise exception 'fan_gift_id required';
  end if;

  select * into v_gift
  from public.fan_gifts
  where id = p_fan_gift_id and status = 'completed';
  if not found then
    raise exception 'fan_gift not found';
  end if;

  if exists (
    select 1 from public.community_posts cp
    where cp.reply_to_fan_gift_id = p_fan_gift_id
  ) then
    raise exception 'thank you whisper already sent';
  end if;

  select s.id into v_shop
  from public.shops s
  where s.id = v_gift.beneficiary_shop_id
    and (
      s.owner_user_id = v_uid
      or exists (
        select 1 from public.shop_memberships m
        where m.shop_id = s.id and m.user_id = v_uid
      )
    );
  if v_shop is null then
    raise exception 'shop access denied';
  end if;

  select c.user_id, coalesce(nullif(trim(v_gift.fan_display_name), ''), c.name, '후원자')
  into v_supporter_user, v_name
  from public.customers c
  where c.id = v_gift.fan_customer_id;

  if v_supporter_user is null then
    raise exception 'supporter user not linked';
  end if;

  v_body := left(trim(coalesce(p_body, '')), 2000);
  if v_body = '' then
    v_body := format('%s님, 후원해 주셔서 감사합니다!', v_name);
  end if;

  insert into public.community_posts (
    shop_id,
    author_user_id,
    post_type,
    title,
    body,
    visibility,
    status,
    is_whisper,
    audience_spec,
    audience_op,
    whisper_recipient_count,
    reply_to_fan_gift_id
  ) values (
    v_shop,
    v_uid,
    'case_share',
    '',
    v_body,
    'directors_only',
    'published',
    true,
    jsonb_build_object(
      'op', 'union',
      'atoms', jsonb_build_array('explicit'),
      'explicit_user_ids', jsonb_build_array(v_supporter_user),
      'shop_id', v_shop,
      'kind', 'thank_you_supporter',
      'fan_gift_id', p_fan_gift_id
    ),
    'union',
    0,
    p_fan_gift_id
  )
  returning id into v_post_id;

  insert into public.community_whisper_recipients (post_id, user_id, atom_bits)
  values (v_post_id, v_supporter_user, 16)
  on conflict (post_id, user_id) do nothing;

  update public.community_posts
  set whisper_recipient_count = 1, updated_at = now()
  where id = v_post_id;

  return jsonb_build_object(
    'ok', true,
    'post_id', v_post_id,
    'whisper_id', v_post_id,
    'recipient_count', 1,
    'fan_gift_id', p_fan_gift_id,
    'supporter_name', v_name
  );
end;
$function$
;

-- ---- public.send_whisper_post(text,text,text[],uuid[],uuid[],uuid,integer)  secdef=true  md5=fb1d5d069d327b829a12487d692cd3aa
CREATE OR REPLACE FUNCTION public.send_whisper_post(p_body text, p_op text DEFAULT 'union'::text, p_atoms text[] DEFAULT '{}'::text[], p_explicit_user_ids uuid[] DEFAULT '{}'::uuid[], p_explicit_shop_ids uuid[] DEFAULT '{}'::uuid[], p_shop_id uuid DEFAULT NULL::uuid, p_max integer DEFAULT 500)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_op text := lower(trim(coalesce(p_op, 'union')));
  v_body text := left(trim(coalesce(p_body, '')), 2000);
  v_max int := greatest(1, least(coalesce(p_max, 500), 500));
  v_atoms text[];
  v_post_id uuid;
  v_count int := 0;
  v_full int := 0;
  v_truncated boolean := false;
  v_day_count int;
  v_spec jsonb;
  v_has_everyone boolean;
  v_visibility text;
begin
  select coalesce(array_agg(distinct trim(a)), '{}'::text[])
  into v_atoms
  from unnest(coalesce(p_atoms, '{}'::text[])) as a
  where trim(a) <> '';

  v_has_everyone := 'everyone' = any (v_atoms);

  if v_uid is null then raise exception 'auth required'; end if;
  if length(v_body) < 1 then raise exception 'body required'; end if;
  if coalesce(array_length(v_atoms, 1), 0) < 1 then
    raise exception 'at least one audience atom required';
  end if;
  if v_op not in ('union', 'intersect') then v_op := 'union'; end if;

  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;
  if v_shop is null or not exists (
    select 1 from public.shops s
    where s.id = v_shop
      and (
        s.owner_user_id = v_uid
        or exists (
          select 1 from public.shop_memberships m
          where m.shop_id = s.id and m.user_id = v_uid
        )
      )
  ) then
    raise exception 'shop access denied';
  end if;

  select count(*)::int into v_day_count
  from public.community_posts p
  where p.author_user_id = v_uid
    and coalesce(p.is_whisper, false) = true
    and p.status = 'published'
    and p.created_at > now() - interval '1 day';
  if coalesce(v_day_count, 0) >= 20 then
    raise exception 'daily whisper limit reached';
  end if;

  select count(*)::int into v_full
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, v_op, v_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, 501
  );
  if v_full > v_max then v_truncated := true; end if;

  v_visibility := case when v_has_everyone then 'public' else 'directors_only' end;

  v_spec := jsonb_build_object(
    'op', v_op,
    'atoms', to_jsonb(v_atoms),
    'explicit_user_ids', to_jsonb(coalesce(p_explicit_user_ids, '{}'::uuid[])),
    'explicit_shop_ids', to_jsonb(coalesce(p_explicit_shop_ids, '{}'::uuid[])),
    'shop_id', v_shop,
    'is_public', v_has_everyone,
    'caps', jsonb_build_object('max_recipients', v_max)
  );

  insert into public.community_posts (
    shop_id, author_user_id, post_type, title, body,
    visibility, status, is_whisper, audience_spec, audience_op,
    whisper_recipient_count, feed_metadata
  ) values (
    v_shop, v_uid, 'whisper', '', v_body,
    v_visibility, 'published', true, v_spec, v_op,
    0, jsonb_build_object('is_public', v_has_everyone)
  )
  returning id into v_post_id;

  insert into public.community_whisper_recipients (post_id, user_id, atom_bits)
  select v_post_id, r.user_id, r.atom_bits
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, v_op, v_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, v_max
  ) r
  on conflict (post_id, user_id) do nothing;

  get diagnostics v_count = row_count;

  if v_count < 1 and not v_has_everyone then
    delete from public.community_posts where id = v_post_id;
    raise exception 'no recipients matched';
  end if;

  update public.community_posts
  set whisper_recipient_count = v_count, updated_at = now()
  where id = v_post_id;

  return jsonb_build_object(
    'ok', true,
    'post_id', v_post_id,
    'whisper_id', v_post_id,
    'recipient_count', v_count,
    'truncated', v_truncated,
    'op', v_op,
    'atoms', to_jsonb(v_atoms),
    'visibility', v_visibility,
    'is_public', v_has_everyone,
    'post_type', 'whisper'
  );
end;
$function$
;

-- ---- public.send_whisper(text,uuid,text,text[],uuid[],uuid[],integer)  secdef=true  md5=8cbdb4f46c41803719dac729855bbc96
CREATE OR REPLACE FUNCTION public.send_whisper(p_body text, p_shop_id uuid DEFAULT NULL::uuid, p_op text DEFAULT 'union'::text, p_atoms text[] DEFAULT '{}'::text[], p_explicit_user_ids uuid[] DEFAULT '{}'::uuid[], p_explicit_shop_ids uuid[] DEFAULT '{}'::uuid[], p_max integer DEFAULT 500)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_op text := lower(trim(coalesce(p_op, 'union')));
  v_body text := left(trim(coalesce(p_body, '')), 2000);
  v_max int := greatest(1, least(coalesce(p_max, 500), 500));
  v_whisper_id uuid;
  v_count int := 0;
  v_full int := 0;
  v_truncated boolean := false;
  v_day_count int;
  v_spec jsonb;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if length(v_body) < 1 then
    raise exception 'body required';
  end if;
  if coalesce(array_length(p_atoms, 1), 0) < 1 then
    raise exception 'at least one audience atom required';
  end if;
  if v_op not in ('union', 'intersect') then
    v_op := 'union';
  end if;

  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;
  if v_shop is null
     or not exists (
       select 1 from public.shops s
       where s.id = v_shop
         and (
           s.owner_user_id = v_uid
           or exists (
             select 1 from public.shop_memberships m
             where m.shop_id = s.id and m.user_id = v_uid
           )
         )
     ) then
    raise exception 'shop access denied';
  end if;

  select count(*)::int into v_day_count
  from public.whispers w
  where w.sender_user_id = v_uid
    and w.status = 'sent'
    and w.created_at > now() - interval '1 day';
  if coalesce(v_day_count, 0) >= 20 then
    raise exception 'daily whisper limit reached';
  end if;

  select count(*)::int into v_full
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, v_op, p_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, 501
  );
  if v_full > v_max then
    v_truncated := true;
  end if;

  v_spec := jsonb_build_object(
    'op', v_op,
    'atoms', to_jsonb(p_atoms),
    'explicit_user_ids', to_jsonb(coalesce(p_explicit_user_ids, '{}'::uuid[])),
    'explicit_shop_ids', to_jsonb(coalesce(p_explicit_shop_ids, '{}'::uuid[])),
    'shop_id', v_shop,
    'caps', jsonb_build_object('max_recipients', v_max)
  );

  insert into public.whispers (
    sender_user_id, shop_id, body, audience_spec, audience_op,
    recipient_count, truncated, status
  ) values (
    v_uid, v_shop, v_body, v_spec, v_op, 0, v_truncated, 'sent'
  )
  returning id into v_whisper_id;

  insert into public.whisper_recipients (whisper_id, user_id, atom_bits)
  select v_whisper_id, r.user_id, r.atom_bits
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, v_op, p_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, v_max
  ) r
  on conflict (whisper_id, user_id) do nothing;

  get diagnostics v_count = row_count;

  if v_count < 1 then
    update public.whispers set status = 'deleted', updated_at = now()
    where id = v_whisper_id;
    raise exception 'no recipients matched';
  end if;

  update public.whispers
  set recipient_count = v_count, updated_at = now()
  where id = v_whisper_id;

  return jsonb_build_object(
    'ok', true,
    'whisper_id', v_whisper_id,
    'recipient_count', v_count,
    'truncated', v_truncated,
    'op', v_op,
    'atoms', to_jsonb(p_atoms)
  );
end;
$function$
;

-- ---- public.set_review_naver_publish_status(uuid,text)  secdef=true  md5=677881dfe69c57b8bdf3d2dbd993686e
CREATE OR REPLACE FUNCTION public.set_review_naver_publish_status(p_review_id uuid, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_status text := lower(trim(coalesce(p_status, 'none')));
  v_row public.customer_reviews%rowtype;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if v_status not in ('none', 'copied', 'registered', 'confirmed') then
    raise exception 'invalid status';
  end if;

  update public.customer_reviews r
  set
    naver_publish_status = v_status,
    naver_registered = (v_status in ('registered', 'confirmed')),
    naver_registered_at = case
      when v_status in ('registered', 'confirmed')
        then coalesce(r.naver_registered_at, now())
      else r.naver_registered_at
    end,
    updated_at = now()
  where r.id = p_review_id
    and exists (
      select 1 from public.shops s
      where s.id = r.shop_id
        and (
          s.owner_user_id = v_uid
          or exists (
            select 1 from public.shop_memberships m
            where m.shop_id = s.id and m.user_id = v_uid
          )
        )
    )
  returning * into v_row;

  if v_row.id is null then
    raise exception 'review not found or access denied';
  end if;
  return to_jsonb(v_row);
end;
$function$
;

-- ---- public.set_subscription(text,uuid,uuid,boolean,text)  secdef=true  md5=55f6bf2ceea8976d160319ec0d626eb8
CREATE OR REPLACE FUNCTION public.set_subscription(p_target_type text, p_target_shop_id uuid DEFAULT NULL::uuid, p_target_user_id uuid DEFAULT NULL::uuid, p_following boolean DEFAULT true, p_source text DEFAULT 'discover'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_type text := lower(trim(coalesce(p_target_type, '')));
  v_src text := lower(trim(coalesce(p_source, 'discover')));
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if v_type not in ('shop', 'director') then
    raise exception 'invalid target_type';
  end if;
  if v_src not in ('discover', 'shop_page', 'chart', 'seed', 'legacy_backfill') then
    v_src := 'discover';
  end if;

  if not coalesce(p_following, true) then
    if v_type = 'shop' then
      delete from public.subscriptions
      where follower_user_id = v_uid
        and target_type = 'shop'
        and target_shop_id = p_target_shop_id;
    else
      delete from public.subscriptions
      where follower_user_id = v_uid
        and target_type = 'director'
        and target_user_id = p_target_user_id;
    end if;
    return jsonb_build_object('ok', true, 'following', false);
  end if;

  if v_type = 'shop' then
    if p_target_shop_id is null then
      raise exception 'target_shop_id required';
    end if;
    insert into public.subscriptions (
      follower_user_id, target_type, target_shop_id, source
    ) values (v_uid, 'shop', p_target_shop_id, v_src)
    on conflict do nothing;
  else
    if p_target_user_id is null then
      raise exception 'target_user_id required';
    end if;
    if p_target_user_id = v_uid then
      raise exception 'cannot follow self';
    end if;
    insert into public.subscriptions (
      follower_user_id, target_type, target_user_id, target_shop_id, source
    ) values (
      v_uid, 'director', p_target_user_id,
      (
        select s.id from public.shops s
        where s.owner_user_id = p_target_user_id
        order by s.created_at asc
        limit 1
      ),
      v_src
    )
    on conflict do nothing;
  end if;

  return jsonb_build_object('ok', true, 'following', true);
end;
$function$
;

-- ---- public.settle_affiliate_conversion(uuid,text,uuid)  secdef=true  md5=5b75a69b3df88f538c8fff1de8aca2dd
CREATE OR REPLACE FUNCTION public.settle_affiliate_conversion(p_conversion_id uuid, p_to_status text, p_actor_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.affiliate_conversions%rowtype;
  v_status text := lower(trim(coalesce(p_to_status, '')));
begin
  if v_status not in ('confirmed', 'paid', 'void', 'pending') then
    raise exception 'invalid status: %', p_to_status;
  end if;

  update public.affiliate_conversions
  set status = v_status,
      confirmed_by = coalesce(p_actor_user_id, confirmed_by),
      updated_at = now()
  where id = p_conversion_id
  returning * into v_row;

  if not found then
    raise exception 'conversion not found: %', p_conversion_id;
  end if;

  return to_jsonb(v_row);
end;
$function$
;

-- ---- public.settle_seminar_enrollment(uuid,numeric)  secdef=true  md5=7637c2b81afa839a16627405b7a595d6
CREATE OR REPLACE FUNCTION public.settle_seminar_enrollment(p_enrollment_id uuid, p_platform_fee_pct numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_enrollment public.seminar_enrollments%rowtype;
  v_class public.seminar_classes%rowtype;
  v_director_tier text;
  v_fee_pct numeric;
  v_net int;
begin
  select * into v_enrollment
  from public.seminar_enrollments
  where id = p_enrollment_id
  for update;

  if not found then
    raise exception 'enrollment not found';
  end if;

  if v_enrollment.status <> 'held' then
    raise exception 'enrollment not in held status';
  end if;

  if not exists (
    select 1
    from public.seminar_enrollment_reviews r
    where r.enrollment_id = p_enrollment_id
  ) then
    raise exception 'review required before settlement';
  end if;

  select * into v_class
  from public.seminar_classes
  where id = v_enrollment.class_id;

  select coalesce(s.tier_badge, 'none') into v_director_tier
  from public.shops s
  where s.id = v_class.director_shop_id;

  v_fee_pct := coalesce(
    p_platform_fee_pct,
    public.compute_platform_fee_pct(v_director_tier)
  );

  v_net := greatest(
    0,
    floor(v_enrollment.amount * (1 - v_fee_pct))::int
  );

  update public.seminar_enrollments
  set status = 'completed',
      completed_at = now()
  where id = p_enrollment_id;

  update public.shops
  set sori_cash_balance = sori_cash_balance + v_net,
      updated_at = now()
  where id = v_class.director_shop_id;

  perform public.refresh_seminar_feedback_report(v_class.id);

  return jsonb_build_object(
    'enrollment_id', p_enrollment_id,
    'class_id', v_class.id,
    'net_amount', v_net,
    'director_shop_id', v_class.director_shop_id,
    'platform_fee_pct', v_fee_pct,
    'tier_badge', v_director_tier
  );
end;
$function$
;

-- ---- public.shop_rolling_12m_funding(uuid)  secdef=true  md5=70848df55d5a0b3da25254a0164d7fc8
CREATE OR REPLACE FUNCTION public.shop_rolling_12m_funding(p_shop_id uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(sum(
    greatest(0, coalesce(sc.current_enrollment, 0) * coalesce(sc.price, 0))
  ), 0)::int
  from public.seminar_classes sc
  where sc.director_shop_id = p_shop_id
    and sc.status = 'completed'
    and coalesce(sc.updated_at, sc.created_at) >= (now() - interval '365 days');
$function$
;

-- ---- public.shop_tier_rank(text)  secdef=false  md5=60f18cce493c6b6efc59e5abb2baee99
CREATE OR REPLACE FUNCTION public.shop_tier_rank(p_badge text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case lower(trim(replace(coalesce(p_badge, 'none'), ' ', '_')))
    when 'iron' then 1
    when 'bronze' then 2
    when 'silver' then 3
    when 'gold' then 4
    when 'platinum' then 5
    when 'diamond' then 6
    when 'mentor' then 7
    when 'master' then 8
    when 'grand_master' then 9
    when 'grand_director' then 10
    else 0
  end;
$function$
;

-- ---- public.sku_premium_tier(text)  secdef=false  md5=947a0346b3a49ffe9e46b8a5b06f62b9
CREATE OR REPLACE FUNCTION public.sku_premium_tier(p_sku text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case lower(trim(coalesce(p_sku, '')))
    when 'boost_special_gold_24h' then 'gold'
    when 'boost_special_platinum_7d' then 'platinum'
    else coalesce(
      (select lower(trim(metadata->>'tier'))
       from public.point_shop_items
       where sku = lower(trim(coalesce(p_sku, '')))
       limit 1),
      ''
    )
  end;
$function$
;

-- ---- public.submit_mentoring_feedback(uuid,text)  secdef=true  md5=f7666a8101266c7daac2564514a822f8
CREATE OR REPLACE FUNCTION public.submit_mentoring_feedback(p_purchase_id uuid, p_vote text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_customer uuid;
  v_vote text := lower(trim(coalesce(p_vote, '')));
  v_purchase public.mentoring_purchases%rowtype;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if v_vote not in ('helpful', 'not_helpful') then
    raise exception 'invalid vote';
  end if;

  select c.id into v_customer from public.customers c where c.user_id = v_uid limit 1;
  if v_customer is null then raise exception 'customer not found'; end if;

  select * into v_purchase
  from public.mentoring_purchases
  where id = p_purchase_id;

  if not found then raise exception 'purchase not found'; end if;
  if v_purchase.buyer_customer_id <> v_customer then raise exception 'forbidden'; end if;

  insert into public.mentoring_feedback (purchase_id, vote)
  values (p_purchase_id, v_vote)
  on conflict (purchase_id) do update set vote = excluded.vote;

  return jsonb_build_object('ok', true, 'vote', v_vote);
end;
$function$
;

-- ---- public.submit_seminar_enrollment_review(uuid,jsonb,text)  secdef=true  md5=104b9e7364c2985acdd8a7ed7b567b9a
CREATE OR REPLACE FUNCTION public.submit_seminar_enrollment_review(p_enrollment_id uuid, p_insight_tags jsonb, p_comment text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_review_id uuid;
  v_tags jsonb;
  v_class_id uuid;
begin
  if p_enrollment_id is null then
    raise exception 'enrollment_id required';
  end if;

  if not exists (
    select 1 from public.seminar_enrollments e where e.id = p_enrollment_id
  ) then
    raise exception 'enrollment not found';
  end if;

  v_tags := coalesce(p_insight_tags, '[]'::jsonb);
  if jsonb_typeof(v_tags) <> 'array' or jsonb_array_length(v_tags) < 1 then
    raise exception 'at least one insight tag required';
  end if;

  insert into public.seminar_enrollment_reviews (
    enrollment_id,
    insight_tags,
    comment
  )
  values (
    p_enrollment_id,
    v_tags,
    coalesce(trim(p_comment), '')
  )
  on conflict (enrollment_id) do update
  set
    insight_tags = excluded.insight_tags,
    comment = excluded.comment
  returning id into v_review_id;

  select e.class_id into v_class_id
  from public.seminar_enrollments e
  where e.id = p_enrollment_id;

  perform public.refresh_seminar_feedback_report(v_class_id);

  return v_review_id;
end;
$function$
;

-- ---- public.sync_affiliate_conversion_commission()  secdef=true  md5=c202675e99cef25cee584577f0213a5a
CREATE OR REPLACE FUNCTION public.sync_affiliate_conversion_commission()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_commission_id uuid := new.commission_id;
  v_link_id uuid := new.link_id;
begin
  -- Ensure a commission row exists for confirmed/paid conversions.
  if new.status in ('confirmed', 'paid') then
    if v_commission_id is null then
      if v_link_id is null then
        insert into public.affiliate_links (
          shop_id, destination_url, label, commission_per_click, status
        ) values (
          new.shop_id,
          'conversion://' || new.id::text,
          coalesce(nullif(trim(new.order_ref), ''), '전환 정산'),
          greatest(new.commission_amount, 0),
          'active'
        )
        returning id into v_link_id;
        new.link_id := v_link_id;
      end if;

      insert into public.affiliate_commissions (
        shop_id,
        link_id,
        click_id,
        amount,
        currency,
        status,
        note
      ) values (
        new.shop_id,
        v_link_id,
        new.click_id,
        greatest(new.commission_amount, 0),
        new.currency,
        new.status,
        coalesce(nullif(trim(new.note), ''), 'from conversion ' || new.id::text)
      )
      returning id into v_commission_id;
      new.commission_id := v_commission_id;
    else
      update public.affiliate_commissions
      set amount = greatest(new.commission_amount, 0),
          status = new.status,
          updated_at = now(),
          note = case
            when nullif(trim(new.note), '') is null then note
            else new.note
          end
      where id = v_commission_id;
    end if;
  elsif new.status = 'void' and v_commission_id is not null then
    update public.affiliate_commissions
    set status = 'void', updated_at = now()
    where id = v_commission_id;
  end if;

  new.updated_at := now();
  if new.status = 'confirmed' and new.confirmed_at is null then
    new.confirmed_at := now();
  end if;
  if new.status = 'paid' and new.paid_at is null then
    new.paid_at := now();
  end if;
  return new;
end;
$function$
;

-- ---- public.sync_affiliate_paid_to_settlement()  secdef=true  md5=8e0c404a9a663572887a72879e426647
CREATE OR REPLACE FUNCTION public.sync_affiliate_paid_to_settlement()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'UPDATE'
     and old.status is distinct from 'paid'
     and new.status = 'paid'
     and coalesce(new.amount, 0) > 0 then
    perform public.credit_settlement(
      new.shop_id,
      new.amount,
      'affiliate_payout',
      'affiliate_commission',
      new.id,
      '제휴 수수료 정산 입금'
    );
  end if;
  return new;
end;
$function$
;

-- ---- public.sync_membership_tickets_for_customer(uuid)  secdef=true  md5=652a7d6cbe36c8b8fd06e3a87ad0b50a
CREATE OR REPLACE FUNCTION public.sync_membership_tickets_for_customer(p_customer_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_user_phone text;
  v_customer_name text;
  v_phone_digits text;
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

  v_user_phone := coalesce(nullif(trim(c.phone), ''), '');
  v_customer_name := coalesce(nullif(trim(c.name), ''), '고객');
  v_phone_digits := regexp_replace(v_user_phone, '[^0-9]', '', 'g');

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
        user_phone, customer_name,
        ticket_name, total_visits, used_visits, expires_at, is_active,
        paid_amount, per_session_value, updated_at
      ) values (
        tid_uuid,
        c.shop_id,
        c.id,
        v_phone_digits,
        v_user_phone,
        v_customer_name,
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
        user_phone = excluded.user_phone,
        customer_name = excluded.customer_name,
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
        user_phone, customer_name,
        ticket_name, total_visits, used_visits, expires_at, is_active,
        paid_amount, per_session_value, updated_at
      ) values (
        tid_text,
        c.shop_id,
        c.id,
        v_phone_digits,
        v_user_phone,
        v_customer_name,
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
        user_phone = excluded.user_phone,
        customer_name = excluded.customer_name,
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
$function$
;

-- ---- public.sync_profile_from_auth_user()  secdef=true  md5=2866a2c0d29fe4c400b9ac805f277999
CREATE OR REPLACE FUNCTION public.sync_profile_from_auth_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  display_name text;
  avatar text;
begin
  display_name := coalesce(
    nullif(trim(meta->>'name'), ''),
    nullif(trim(meta->>'full_name'), ''),
    nullif(trim(meta->>'nickname'), ''),
    nullif(trim(meta->>'preferred_username'), ''),
    ''
  );
  avatar := coalesce(
    nullif(trim(meta->>'avatar_url'), ''),
    nullif(trim(meta->>'picture'), ''),
    nullif(trim(meta->>'profile_image'), ''),
    nullif(trim(meta->>'profile_image_url'), ''),
    ''
  );

  insert into public.profiles (id, name, phone, avatar_url, role, active_mode)
  values (
    new.id,
    display_name,
    coalesce(meta->>'phone', ''),
    avatar,
    'guest',
    'customer'
  )
  on conflict (id) do update
    set
      name = case
        when excluded.name <> '' then excluded.name
        else public.profiles.name
      end,
      phone = case
        when coalesce(excluded.phone, '') <> '' then excluded.phone
        else public.profiles.phone
      end,
      avatar_url = case
        when excluded.avatar_url <> '' then excluded.avatar_url
        else public.profiles.avatar_url
      end,
      updated_at = now();

  return new;
end;
$function$
;

-- ---- public.sync_shop_menus_from_jsonb()  secdef=true  md5=15ca2af374ab5ae15109dbae164a0d80
CREATE OR REPLACE FUNCTION public.sync_shop_menus_from_jsonb()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  item jsonb;
  idx int := 0;
  menu_name text;
  menu_desc text;
  menu_device text;
begin
  delete from public.shop_menus where shop_id = new.id;
  if new.service_menu is null or jsonb_typeof(new.service_menu) <> 'array' then
    return new;
  end if;
  for item in select * from jsonb_array_elements(new.service_menu)
  loop
    if jsonb_typeof(item) = 'string' then
      menu_name := trim(item #>> '{}');
      menu_desc := '';
      menu_device := null;
    else
      menu_name := trim(coalesce(item->>'name', ''));
      menu_desc := coalesce(item->>'description', '');
      menu_device := nullif(trim(coalesce(item->>'device_info', '')), '');
    end if;
    if menu_name is not null and menu_name <> '' then
      insert into public.shop_menus (
        shop_id, name, description, device_info, sort_order
      ) values (
        new.id, menu_name, menu_desc, menu_device, idx
      )
      on conflict (shop_id, name) do update set
        description = excluded.description,
        device_info = excluded.device_info,
        sort_order = excluded.sort_order,
        updated_at = now();
      idx := idx + 1;
    end if;
  end loop;
  return new;
end;
$function$
;

-- ---- public.sync_shop_owner_membership()  secdef=true  md5=3acafc35d121a4b8129b7d2c9c69ea46
CREATE OR REPLACE FUNCTION public.sync_shop_owner_membership()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.owner_user_id is null then
    return new;
  end if;
  insert into public.shop_memberships (shop_id, user_id, role, title, is_public)
  values (new.id, new.owner_user_id, 'owner', '원장', true)
  on conflict (shop_id, user_id) do update set
    role = 'owner',
    updated_at = now();
  return new;
end;
$function$
;

-- ---- public.sync_shop_tier_metrics(uuid)  secdef=true  md5=fd377976b2de0b41e6e0c675a84c3f38
CREATE OR REPLACE FUNCTION public.sync_shop_tier_metrics(p_shop_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_likes int;
  v_shared int;
  v_requests int;
  v_completed int;
  v_funding int;
  v_followers int;
begin
  if p_shop_id is null then
    return;
  end if;
  select count(*)::int into v_shared
  from public.customer_charts c
  where c.shop_id = p_shop_id
    and c.is_case_shared = true
    and (
      coalesce(c.signature_url, '') <> ''
      or coalesce(c.consent_pdf_url, '') <> ''
    );
  select count(*)::int into v_likes
  from public.chart_likes l
  inner join public.customer_charts c on c.id = l.chart_id
  where c.shop_id = p_shop_id;
  select count(*)::int into v_requests
  from public.seminar_requests r
  inner join public.customer_charts c on c.id = r.case_id
  where c.shop_id = p_shop_id;
  select count(*)::int into v_completed
  from public.seminar_classes sc
  where sc.director_shop_id = p_shop_id
    and sc.status = 'completed';
  select coalesce(sum(
    greatest(0, coalesce(sc.current_enrollment, 0) * coalesce(sc.price, 0))
  ), 0)::int into v_funding
  from public.seminar_classes sc
  where sc.director_shop_id = p_shop_id
    and sc.status = 'completed';
  select count(*)::int into v_followers
  from public.shop_followers f
  where f.shop_id = p_shop_id;
  update public.shops
  set
    total_likes = coalesce(v_likes, 0),
    shared_case_count = coalesce(v_shared, 0),
    seminar_request_count = coalesce(v_requests, 0),
    completed_seminar_count = coalesce(v_completed, 0),
    total_seminar_count = coalesce(v_completed, 0),
    total_funding_amount = coalesce(v_funding, 0),
    follower_count = coalesce(v_followers, 0),
    updated_at = now()
  where id = p_shop_id;
end;
$function$
;

-- ---- public.sync_subscription_to_shop_followers()  secdef=true  md5=78aef03d53135a1e6885171a76987f63
CREATE OR REPLACE FUNCTION public.sync_subscription_to_shop_followers()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_customer_id uuid;
begin
  if tg_op = 'INSERT'
     and new.target_type = 'shop'
     and new.target_shop_id is not null then
    select c.id into v_customer_id
    from public.customers c
    where c.user_id = new.follower_user_id
      and c.shop_id = new.target_shop_id
    order by c.created_at desc
    limit 1;
    if v_customer_id is null then
      select c.id into v_customer_id
      from public.customers c
      where c.user_id = new.follower_user_id
      order by c.created_at desc
      limit 1;
    end if;
    if v_customer_id is not null then
      insert into public.shop_followers (shop_id, customer_id)
      values (new.target_shop_id, v_customer_id)
      on conflict (shop_id, customer_id) do nothing;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE'
     and old.target_type = 'shop'
     and old.target_shop_id is not null then
    delete from public.shop_followers f
    using public.customers c
    where f.shop_id = old.target_shop_id
      and f.customer_id = c.id
      and c.user_id = old.follower_user_id;
    return old;
  end if;

  return coalesce(new, old);
end;
$function$
;

-- ---- public.tier_badge_rank(text)  secdef=false  md5=514bae56d6cbd482649664d7f2723848
CREATE OR REPLACE FUNCTION public.tier_badge_rank(p_badge text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case lower(trim(replace(coalesce(p_badge, 'none'), ' ', '_')))
    when 'iron' then 1
    when 'bronze' then 2
    when 'silver' then 3
    when 'gold' then 4
    when 'platinum' then 5
    when 'diamond' then 6
    when 'mentor' then 7
    when 'master' then 8
    when 'grand_master' then 9
    when 'grand_director' then 10
    else 0
  end;
$function$
;

-- ---- public.toggle_case_bookmark(uuid,text)  secdef=true  md5=bba35942a08db641715642c85a9aa5de
CREATE OR REPLACE FUNCTION public.toggle_case_bookmark(p_chart_id uuid, p_folder text DEFAULT 'default'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_folder text := coalesce(nullif(trim(p_folder), ''), 'default');
  v_shop uuid;
  v_nickname text;
  v_bookmarked boolean;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_chart_id is null then
    raise exception 'chart_id required';
  end if;
  if not exists (select 1 from public.customer_charts where id = p_chart_id) then
    raise exception 'chart not found';
  end if;

  if exists (
    select 1 from public.case_bookmarks
    where user_id = v_uid and chart_id = p_chart_id
  ) then
    delete from public.case_bookmarks
    where user_id = v_uid and chart_id = p_chart_id;
    v_bookmarked := false;
  else
    insert into public.case_bookmarks (user_id, chart_id, folder)
    values (v_uid, p_chart_id, v_folder)
    on conflict (user_id, chart_id) do nothing;
    v_bookmarked := true;

    select cc.shop_id into v_shop
    from public.customer_charts cc where cc.id = p_chart_id;

    select coalesce(nullif(trim(p.nickname), ''), '팔로워')
    into v_nickname
    from public.profiles p where p.id = v_uid;

    if v_shop is not null then
      insert into public.shop_notifications (
        shop_id, kind, title, body, payload
      ) values (
        v_shop,
        'case_bookmark',
        '케이스 저장 알림',
        format('%s님이 케이스를 보관함에 저장했습니다', v_nickname),
        jsonb_build_object(
          'chart_id', p_chart_id,
          'user_id', v_uid,
          'folder', v_folder
        )
      );
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'chart_id', p_chart_id,
    'bookmarked', v_bookmarked,
    'folder', v_folder
  );
end;
$function$
;

-- ---- public.toggle_region_content_bookmark(text,uuid)  secdef=true  md5=8e72235c7ec63bfbb276168684dd0c8e
CREATE OR REPLACE FUNCTION public.toggle_region_content_bookmark(p_kind text, p_target_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_kind text := lower(trim(coalesce(p_kind, '')));
  v_bookmarked boolean;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if v_kind not in ('post', 'seminar') then
    raise exception 'kind must be post or seminar';
  end if;
  if p_target_id is null then
    raise exception 'target_id required';
  end if;

  if v_kind = 'post' and not exists (
    select 1 from public.community_posts where id = p_target_id
  ) then
    raise exception 'post not found';
  end if;
  if v_kind = 'seminar' and not exists (
    select 1 from public.seminar_classes where id = p_target_id
  ) then
    raise exception 'seminar not found';
  end if;

  if exists (
    select 1 from public.region_content_bookmarks
    where user_id = v_uid and kind = v_kind and target_id = p_target_id
  ) then
    delete from public.region_content_bookmarks
    where user_id = v_uid and kind = v_kind and target_id = p_target_id;
    v_bookmarked := false;
  else
    insert into public.region_content_bookmarks (user_id, kind, target_id)
    values (v_uid, v_kind, p_target_id)
    on conflict (user_id, kind, target_id) do nothing;
    v_bookmarked := true;
  end if;

  return jsonb_build_object(
    'ok', true,
    'kind', v_kind,
    'target_id', p_target_id,
    'bookmarked', v_bookmarked
  );
end;
$function$
;

-- ---- public.touch_ba_capture_session()  secdef=false  md5=9dacc6fb78a7938b39648080bb810f39
CREATE OR REPLACE FUNCTION public.touch_ba_capture_session()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at := now();
  return new;
end $function$
;

-- ---- public.trg_market_listing_trust_refresh()  secdef=true  md5=bd1682daa70b92727390f45eb6e73035
CREATE OR REPLACE FUNCTION public.trg_market_listing_trust_refresh()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.refresh_market_listing_trust(NEW.id);
  return NEW;
end;
$function$
;

-- ---- public.trg_mentoring_body_updated()  secdef=false  md5=f4bcb2bd7f4c12413fb63aa959abe65c
CREATE OR REPLACE FUNCTION public.trg_mentoring_body_updated()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.body_locked is distinct from old.body_locked
     or new.preview_teaser is distinct from old.preview_teaser then
    new.last_body_updated_at := now();
    if new.status = 'enhancement_required'
       and new.last_body_updated_at > coalesce(new.enhancement_started_at, '-infinity'::timestamptz) then
      new.status := 'active';
      new.enhancement_started_at := null;
      new.enhancement_deadline_at := null;
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$function$
;

-- ---- public.trg_mentoring_feedback_counts()  secdef=true  md5=9c4227c086d5c913bc8c25e4dde7764e
CREATE OR REPLACE FUNCTION public.trg_mentoring_feedback_counts()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_post_id uuid;
  v_help int;
  v_not int;
begin
  select mpu.mentoring_post_id into v_post_id
  from public.mentoring_purchases mpu
  where mpu.id = coalesce(new.purchase_id, old.purchase_id);

  if v_post_id is null then return coalesce(new, old); end if;

  select
    count(*) filter (where mf.vote = 'helpful'),
    count(*) filter (where mf.vote = 'not_helpful')
  into v_help, v_not
  from public.mentoring_feedback mf
  join public.mentoring_purchases mpu on mpu.id = mf.purchase_id
  where mpu.mentoring_post_id = v_post_id;

  update public.mentoring_posts
  set
    help_count = coalesce(v_help, 0),
    not_help_count = coalesce(v_not, 0),
    updated_at = now()
  where id = v_post_id;

  return coalesce(new, old);
end;
$function$
;

-- ---- public.trg_mentoring_feedback_quality()  secdef=true  md5=18234d10ad24ce624d9231d55f47b1bd
CREATE OR REPLACE FUNCTION public.trg_mentoring_feedback_quality()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_post_id uuid;
  v_post public.mentoring_posts%rowtype;
  v_help int;
  v_not int;
  v_total int;
  v_ratio numeric;
begin
  select mpu.mentoring_post_id into v_post_id
  from public.mentoring_purchases mpu
  where mpu.id = coalesce(new.purchase_id, old.purchase_id);

  if v_post_id is null then return coalesce(new, old); end if;

  select * into v_post from public.mentoring_posts where id = v_post_id;
  if not found then return coalesce(new, old); end if;

  select
    count(*) filter (where mf.vote = 'helpful'),
    count(*) filter (where mf.vote = 'not_helpful')
  into v_help, v_not
  from public.mentoring_feedback mf
  join public.mentoring_purchases mpu on mpu.id = mf.purchase_id
  where mpu.mentoring_post_id = v_post_id;

  v_total := coalesce(v_help, 0) + coalesce(v_not, 0);
  if v_total < 5 then return coalesce(new, old); end if;

  v_ratio := coalesce(v_not, 0)::numeric / v_total;

  if v_ratio > 0.30 and v_post.status = 'active' then
    update public.mentoring_posts
    set
      status = 'enhancement_required',
      enhancement_started_at = now(),
      enhancement_deadline_at = now() + interval '48 hours',
      updated_at = now()
    where id = v_post_id
      and status = 'active';

    insert into public.shop_notifications (
      shop_id, kind, title, body, payload
    ) values (
      v_post.author_shop_id,
      'mentoring_enhance_request',
      'Mentoring content needs improvement',
      format(
        'Downvote ratio %.0f%% exceeded 30%%. Update within 48h or new purchases will be disabled.',
        v_ratio * 100
      ),
      jsonb_build_object(
        'mentoring_post_id', v_post_id,
        'downvote_ratio', v_ratio,
        'deadline_at', now() + interval '48 hours'
      )
    );
  end if;

  return coalesce(new, old);
end;
$function$
;

-- ---- public.trg_refresh_tier_on_case_share()  secdef=true  md5=af782d5dd256c3d09aff493f35a120df
CREATE OR REPLACE FUNCTION public.trg_refresh_tier_on_case_share()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if TG_OP = 'INSERT' then
    if NEW.is_case_shared = true then
      perform public.refresh_shop_tier_badge(NEW.shop_id);
    end if;
  elsif TG_OP = 'UPDATE' then
    if NEW.is_case_shared is distinct from OLD.is_case_shared
       or NEW.shop_id is distinct from OLD.shop_id then
      perform public.refresh_shop_tier_badge(NEW.shop_id);
      if OLD.shop_id is distinct from NEW.shop_id then
        perform public.refresh_shop_tier_badge(OLD.shop_id);
      end if;
    end if;
  end if;
  return NEW;
end;
$function$
;

-- ---- public.trg_seminar_class_completed_funding()  secdef=true  md5=0f92e5e1dbf6e1aa0580e8311facbaaa
CREATE OR REPLACE FUNCTION public.trg_seminar_class_completed_funding()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.status = 'completed'
     and (tg_op = 'INSERT' or old.status is distinct from 'completed') then
    update public.shops
    set
      total_seminar_count = total_seminar_count + 1,
      total_funding_amount = total_funding_amount
        + greatest(0, coalesce(new.current_enrollment, 0) * coalesce(new.price, 0)),
      updated_at = now()
    where id = new.director_shop_id;
  end if;
  return new;
end;
$function$
;

-- ---- public.trg_shop_tier_refresh()  secdef=true  md5=a34a9d061c5486c970030cd4da49466b
CREATE OR REPLACE FUNCTION public.trg_shop_tier_refresh()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_shop uuid;
  v_shop_old uuid;
begin
  if tg_table_name = 'customer_charts' then
    if tg_op = 'DELETE' then
      v_shop := old.shop_id;
    else
      v_shop := new.shop_id;
      if tg_op = 'UPDATE' then
        v_shop_old := old.shop_id;
      end if;
    end if;
    perform public.update_shop_tier_badge(v_shop);
    if v_shop_old is not null and v_shop_old is distinct from v_shop then
      perform public.update_shop_tier_badge(v_shop_old);
    end if;
  elsif tg_table_name = 'chart_likes' then
    select c.shop_id into v_shop
    from public.customer_charts c
    where c.id = case when tg_op = 'DELETE' then old.chart_id else new.chart_id end;
    perform public.update_shop_tier_badge(v_shop);
  elsif tg_table_name = 'shop_followers' then
    v_shop := case when tg_op = 'DELETE' then old.shop_id else new.shop_id end;
    perform public.update_shop_tier_badge(v_shop);
  elsif tg_table_name = 'seminar_requests' then
    select c.shop_id into v_shop
    from public.customer_charts c
    where c.id = case when tg_op = 'DELETE' then old.case_id else new.case_id end;
    perform public.update_shop_tier_badge(v_shop);
  elsif tg_table_name = 'seminar_classes' then
    v_shop := case
      when tg_op = 'DELETE' then old.director_shop_id
      else new.director_shop_id
    end;
    perform public.update_shop_tier_badge(v_shop);
  end if;
  return coalesce(new, old);
end;
$function$
;

-- ---- public.unlock_community_post_with_points(uuid,uuid,integer,integer)  secdef=true  md5=d01bf2e6a30e8d7f825666f676e5d54c
CREATE OR REPLACE FUNCTION public.unlock_community_post_with_points(p_post_id uuid, p_viewer_shop_id uuid, p_cost integer DEFAULT 5, p_creator_share_pct integer DEFAULT 70)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_post public.community_posts%rowtype;
  v_cost int := greatest(coalesce(p_cost, 5), 1);
  v_share_pct int := greatest(least(coalesce(p_creator_share_pct, 70), 100), 0);
  v_creator_share int;
  v_debit jsonb;
  v_media jsonb;
  v_unlocked boolean;
  v_creator_tx public.point_transactions%rowtype;
begin
  if p_post_id is null or p_viewer_shop_id is null then
    raise exception 'post_id and viewer_shop_id required';
  end if;

  select * into v_post from public.community_posts where id = p_post_id for share;
  if not found then
    raise exception 'post not found';
  end if;
  if v_post.shop_id = p_viewer_shop_id then
    raise exception 'cannot unlock own post';
  end if;

  if exists (
    select 1 from public.post_unlocks
    where post_id = p_post_id and shop_id = p_viewer_shop_id
  ) then
    v_unlocked := true;
  elsif public.can_view_community_post_full(
    v_post.visibility, v_post.shop_id, v_post.author_user_id, v_post.id
  ) then
    v_unlocked := true;
  else
    v_unlocked := false;
  end if;

  if not v_unlocked then
    v_creator_share := (v_cost * v_share_pct) / 100;

    v_debit := public.debit_points(
      p_viewer_shop_id, v_cost, 'unlock_spend',
      'community_post', p_post_id, v_post.shop_id, 'paywall unlock'
    );

    v_creator_tx := public.credit_points(
      v_post.shop_id,
      greatest(v_creator_share, 0),
      'free',
      'unlock_revenue',
      'community_post',
      p_post_id,
      p_viewer_shop_id,
      '창작 Echo(출금불가) ' || v_share_pct::text || '%'
    );

    if v_creator_tx.bucket is distinct from 'free'
       or v_creator_tx.kind is distinct from 'unlock_revenue' then
      raise exception 'creator share must remain non-withdrawable echo';
    end if;

    insert into public.post_unlocks (
      post_id, shop_id, user_id, points_spent, creator_share
    ) values (
      p_post_id, p_viewer_shop_id, auth.uid(), v_cost, v_creator_share
    )
    on conflict (post_id, shop_id) do nothing;
  else
    v_creator_share := 0;
    v_debit := '{}'::jsonb;
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'post_id', m.post_id,
      'image_url', m.image_url,
      'sort_order', m.sort_order
    )
    order by m.sort_order
  ), '[]'::jsonb)
  into v_media
  from public.post_media m
  where m.post_id = p_post_id;

  return jsonb_build_object(
    'ok', true,
    'already_unlocked', v_unlocked,
    'points_spent', case when v_unlocked then 0 else v_cost end,
    'creator_share', v_creator_share,
    'creator_currency', 'echo',
    'debit', v_debit,
    'post', jsonb_build_object(
      'id', v_post.id,
      'shop_id', v_post.shop_id,
      'author_user_id', v_post.author_user_id,
      'post_type', v_post.post_type,
      'title', v_post.title,
      'body', v_post.body,
      'style_tags', v_post.style_tags,
      'visibility', v_post.visibility,
      'status', v_post.status,
      'like_count', v_post.like_count,
      'comment_count', v_post.comment_count,
      'save_count', v_post.save_count,
      'source_chart_id', v_post.source_chart_id,
      'created_at', v_post.created_at,
      'is_body_locked', false,
      'unlock_cost', v_cost,
      'post_media', v_media
    )
  );
end;
$function$
;

-- ---- public.update_mentoring_price(uuid,integer)  secdef=true  md5=64446224cbfe6c0641b070d92192f0bb
CREATE OR REPLACE FUNCTION public.update_mentoring_price(p_mentoring_id uuid, p_price_echo integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_post public.mentoring_posts%rowtype;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if p_price_echo is null or p_price_echo < 1 then
    raise exception 'price_echo must be >= 1';
  end if;

  select * into v_post from public.mentoring_posts where id = p_mentoring_id;
  if not found then raise exception 'mentoring not found'; end if;
  if v_post.author_user_id <> v_uid then raise exception 'forbidden'; end if;
  if v_post.status = 'archived' then raise exception 'archived'; end if;

  update public.mentoring_posts
  set price_echo = p_price_echo, updated_at = now()
  where id = p_mentoring_id;

  return jsonb_build_object('ok', true, 'price_echo', p_price_echo);
end;
$function$
;

-- ---- public.update_shop_tier_badge(uuid)  secdef=true  md5=27ba54c7d1fa185ab93b7b10f1acde2c
CREATE OR REPLACE FUNCTION public.update_shop_tier_badge(p_shop_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_shared int;
  v_likes int;
  v_followers int;
  v_requests int;
  v_seminars int;
  v_funding int;
  v_rolling int;
  v_social text := 'none';
  v_business text := 'none';
  v_badge text := 'none';
  v_prev text := 'none';
begin
  if p_shop_id is null then
    return 'none';
  end if;

  perform public.sync_shop_tier_metrics(p_shop_id);

  select
    coalesce(s.shared_case_count, 0),
    coalesce(s.total_likes, 0),
    coalesce(s.follower_count, 0),
    coalesce(s.seminar_request_count, 0),
    coalesce(s.completed_seminar_count, 0),
    coalesce(s.total_funding_amount, 0),
    coalesce(s.tier_badge::text, 'none')
  into v_shared, v_likes, v_followers, v_requests, v_seminars, v_funding, v_prev
  from public.shops s
  where s.id = p_shop_id;

  if not found then
    return 'none';
  end if;

  v_rolling := public.shop_rolling_12m_funding(p_shop_id);

  if v_shared >= 100 and v_likes >= 1200 and v_followers >= 500 then
    v_social := 'diamond';
  elsif v_shared >= 70 and v_likes >= 700 and v_followers >= 250 then
    v_social := 'platinum';
  elsif v_shared >= 45 and v_likes >= 350 and v_followers >= 120 then
    v_social := 'gold';
  elsif v_shared >= 25 and v_likes >= 150 and v_followers >= 60 then
    v_social := 'silver';
  elsif v_shared >= 10 and v_likes >= 60 and v_followers >= 25 then
    v_social := 'bronze';
  elsif v_shared >= 3 and v_likes >= 15 and v_followers >= 5 then
    v_social := 'iron';
  else
    v_social := 'none';
  end if;

  if v_requests >= 1000 and v_seminars >= 100 and v_rolling >= 100000000 then
    v_business := 'grand_director';
  elsif v_requests >= 200 and v_seminars >= 50 and v_funding >= 20000000 then
    v_business := 'grand_master';
  elsif v_requests >= 50 and v_seminars >= 10 and v_funding >= 5000000 then
    v_business := 'master';
  elsif v_requests >= 10 and v_seminars >= 1 then
    v_business := 'mentor';
  else
    v_business := 'none';
  end if;

  if v_business <> 'none' then
    v_badge := v_business;
  else
    v_badge := v_social;
  end if;

  update public.shops
  set tier_badge = v_badge::public.shop_tier_badge,
      updated_at = now()
  where id = p_shop_id;

  if public.tier_badge_rank(v_badge) > public.tier_badge_rank(v_prev) then
    perform public.grant_tier_upgrade_reward(p_shop_id, v_prev, v_badge);
  end if;

  return v_badge;
end;
$function$
;

-- ---- public.upsert_my_profile(text,text,text)  secdef=true  md5=487d21bb3df9422f946d2079c4a25ceb
CREATE OR REPLACE FUNCTION public.upsert_my_profile(p_name text DEFAULT NULL::text, p_avatar_url text DEFAULT NULL::text, p_phone text DEFAULT NULL::text)
 RETURNS profiles
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid uuid := auth.uid();
  row public.profiles;
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  insert into public.profiles (id, name, phone, avatar_url, role, active_mode)
  values (
    uid,
    coalesce(nullif(trim(p_name), ''), ''),
    coalesce(nullif(trim(p_phone), ''), ''),
    coalesce(nullif(trim(p_avatar_url), ''), ''),
    'guest',
    'customer'
  )
  on conflict (id) do update
    set
      name = case
        when coalesce(nullif(trim(excluded.name), ''), '') <> '' then excluded.name
        else public.profiles.name
      end,
      phone = case
        when coalesce(nullif(trim(excluded.phone), ''), '') <> '' then excluded.phone
        else public.profiles.phone
      end,
      avatar_url = case
        when coalesce(nullif(trim(excluded.avatar_url), ''), '') <> '' then excluded.avatar_url
        else public.profiles.avatar_url
      end,
      updated_at = now()
  returning * into row;

  return row;
end;
$function$
;

-- ---- public.upsert_proactive_mentoring(uuid,text,text,integer)  secdef=true  md5=e05ab454950cbf383d304537baf1af49
CREATE OR REPLACE FUNCTION public.upsert_proactive_mentoring(p_chart_id uuid, p_teaser text, p_body text, p_price_echo integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_chart public.customer_charts%rowtype;
  v_post public.mentoring_posts%rowtype;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if p_price_echo is null or p_price_echo < 1 then
    raise exception 'price_echo must be >= 1';
  end if;
  if char_length(trim(coalesce(p_body, ''))) < 20 then
    raise exception 'body too short';
  end if;

  select * into v_chart from public.customer_charts where id = p_chart_id;
  if not found then raise exception 'chart not found'; end if;

  if not exists (
    select 1 from public.shops s
    where s.id = v_chart.shop_id and s.owner_user_id = v_uid
  ) then
    raise exception 'forbidden';
  end if;

  select * into v_post
  from public.mentoring_posts mp
  where mp.chart_id = p_chart_id
    and mp.status <> 'archived'
  limit 1;

  if found then
    update public.mentoring_posts
    set
      preview_teaser = coalesce(nullif(trim(p_teaser), ''), preview_teaser),
      body_locked = trim(p_body),
      price_echo = p_price_echo,
      origin = 'proactive',
      updated_at = now()
    where id = v_post.id
    returning * into v_post;
  else
    insert into public.mentoring_posts (
      chart_id, author_shop_id, author_user_id,
      origin, preview_teaser, body_locked, price_echo, status
    ) values (
      p_chart_id, v_chart.shop_id, v_uid,
      'proactive', coalesce(trim(p_teaser), ''), trim(p_body), p_price_echo, 'draft'
    )
    returning * into v_post;
  end if;

  return jsonb_build_object(
    'ok', true,
    'mentoring_post_id', v_post.id,
    'status', v_post.status
  );
end;
$function$
;

-- ---- public.upsert_seminar_class(jsonb)  secdef=true  md5=6226e4dca56a04960f6ed6c7a8a910c6
CREATE OR REPLACE FUNCTION public.upsert_seminar_class(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

-- ---- public.verify_b2b_partner(uuid,text,text)  secdef=true  md5=e4f1b4af29d499bfef4b6a0a4e0f523f
CREATE OR REPLACE FUNCTION public.verify_b2b_partner(p_partner_id uuid, p_status text, p_notes text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_status text := lower(trim(coalesce(p_status, '')));
  v_id uuid;
begin
  perform public.require_staff(array['ops_admin', 'super_admin']);
  if p_partner_id is null then
    raise exception 'partner_id required';
  end if;
  if v_status not in ('none', 'business_verified', 'sori_partner') then
    raise exception 'invalid status';
  end if;

  update public.b2b_partners
  set verification_status = v_status,
      notes = case
        when coalesce(p_notes, '') = '' then notes
        else p_notes
      end,
      updated_at = now()
  where id = p_partner_id
  returning id into v_id;

  if v_id is null then
    raise exception 'partner not found';
  end if;

  perform public.write_admin_audit(
    'verify_b2b_partner', 'b2b_partner', v_id::text,
    jsonb_build_object('status', v_status)
  );

  return jsonb_build_object('ok', true, 'partner_id', v_id, 'status', v_status);
end;
$function$
;

-- ---- public.verify_shop(uuid,text,text)  secdef=true  md5=b3976db13ad76adff19b6a75eaedd616
CREATE OR REPLACE FUNCTION public.verify_shop(p_shop_id uuid, p_status text, p_notes text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_status text := lower(trim(coalesce(p_status, '')));
begin
  perform public.require_staff(array['ops_admin', 'super_admin']);
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;
  if v_status not in ('none', 'pending', 'business_verified', 'rejected') then
    raise exception 'invalid status';
  end if;

  insert into public.shop_verifications (
    shop_id, status, verified_at, verified_by, notes, updated_at
  ) values (
    p_shop_id,
    v_status,
    case when v_status = 'business_verified' then now() else null end,
    coalesce(auth.uid()::text, ''),
    coalesce(p_notes, ''),
    now()
  )
  on conflict (shop_id) do update set
    status = excluded.status,
    verified_at = excluded.verified_at,
    verified_by = excluded.verified_by,
    notes = excluded.notes,
    updated_at = now();

  perform public.write_admin_audit(
    'verify_shop', 'shop', p_shop_id::text,
    jsonb_build_object('status', v_status, 'notes', coalesce(p_notes, ''))
  );

  return jsonb_build_object('ok', true, 'shop_id', p_shop_id, 'status', v_status);
end;
$function$
;

-- ---- public.viewer_has_post_unlock(uuid)  secdef=true  md5=934c3e6f14196a6cd52233c17dd4e095
CREATE OR REPLACE FUNCTION public.viewer_has_post_unlock(p_post_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.post_unlocks u
    where u.post_id = p_post_id
      and u.shop_id = public.viewer_shop_id()
  );
$function$
;

-- ---- public.viewer_owns_shop(uuid)  secdef=true  md5=678326abe0e4e859561e612efbd57fdc
CREATE OR REPLACE FUNCTION public.viewer_owns_shop(p_shop_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.shops s
    where s.id = p_shop_id
      and s.owner_user_id is not null
      and s.owner_user_id = auth.uid()
  );
$function$
;

-- ---- public.viewer_shop_id()  secdef=true  md5=869bb8abd8d090c505cdfa719ec3c426
CREATE OR REPLACE FUNCTION public.viewer_shop_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select s.id
  from public.shops s
  where s.owner_user_id = auth.uid()
  order by s.updated_at desc nulls last
  limit 1;
$function$
;

-- ---- public.viewer_shop_tier_rank()  secdef=true  md5=e7ab8da8642801319fcbd21b540e12bc
CREATE OR REPLACE FUNCTION public.viewer_shop_tier_rank()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (
      select public.shop_tier_rank(s.tier_badge::text)
      from public.shops s
      where s.owner_user_id = auth.uid()
      order by s.updated_at desc nulls last
      limit 1
    ),
    0
  );
$function$
;

-- ---- public.write_admin_audit(text,text,text,jsonb)  secdef=true  md5=3a04353a868d24dbe776e2f2c099ac98
CREATE OR REPLACE FUNCTION public.write_admin_audit(p_action text, p_target_type text DEFAULT ''::text, p_target_id text DEFAULT ''::text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_super_count int;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  -- Staff only; allow bootstrap when no super_admin exists yet.
  if not public.has_staff_role(
    array['moderator', 'ops_admin', 'super_admin']
  ) then
    select count(*) into v_super_count
    from public.staff_roles
    where role = 'super_admin';
    if coalesce(v_super_count, 0) > 0 then
      raise exception 'forbidden: audit write requires staff';
    end if;
  end if;
  insert into public.admin_audit_log (
    actor_user_id, action, target_type, target_id, payload
  ) values (
    auth.uid(), coalesce(p_action, ''), coalesce(p_target_type, ''),
    coalesce(p_target_id, ''), coalesce(p_payload, '{}'::jsonb)
  );
end;
$function$
;

