-- =============================================================================
-- SORI P0 M1 tests (supabase/migrations/20261003090000_sec_m1_tokens_rpcs.sql)
-- -----------------------------------------------------------------------------
-- * Runs in ONE transaction and ends with ROLLBACK: fixtures (test users/shops/
--   charts with ids e1../e2../e3../e4..) and every write are discarded.
-- * Requires M1 to be applied. Run as postgres (SQL editor, psql, MCP execute_sql).
-- * Any failure raises 'Mx FAIL: ...' and aborts. Success = last row
--   'M1 TESTS PASSED' (psql also prints NOTICE lines 'Mx ok').
-- * Role switching mimics PostgREST: set local role + request.jwt.claims.
-- * Values are passed between role sections with transaction-local GUCs (m1.*).
-- =============================================================================
begin;

-- ---------------------------------------------------------------- fixtures (postgres)
insert into auth.users (id, email) values
  ('e1000000-0000-4000-8000-000000000001', 'm1-owner@test.invalid'),
  ('e1000000-0000-4000-8000-000000000002', 'm1-stranger@test.invalid'),
  ('e1000000-0000-4000-8000-000000000003', 'm1-new-director@test.invalid');
insert into public.profiles (id, name) values
  ('e1000000-0000-4000-8000-000000000001', 'M1 원장'),
  ('e1000000-0000-4000-8000-000000000002', 'M1 외부인'),
  ('e1000000-0000-4000-8000-000000000003', 'M1 신규원장')
on conflict (id) do nothing;
insert into public.shops (id, name, owner_user_id) values
  ('e2000000-0000-4000-8000-000000000001', 'M1 테스트샵', 'e1000000-0000-4000-8000-000000000001');
insert into public.shops (id, name) values
  ('e2000000-0000-4000-8000-000000000002', 'M1 주인없는샵');
insert into public.shops (id, name, is_official) values
  ('e2000000-0000-4000-8000-000000000003', 'M1 공식샵', true);
insert into public.customers (id, shop_id, name, phone, birth_date, gender) values
  ('e3000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000001',
   '김민희', '010-1234-5678', '1990-05-01', 'female');
insert into public.customer_charts
  (id, shop_id, customer_id, visit_number, care_name, consent_marketing, consent_photo, signature_url,
   before_image_url, after_image_url, is_case_shared, allergy_notes, director_insight, treatment_summary, created_at)
values
  ('e4000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000001',
   'e3000000-0000-4000-8000-000000000001', 1, 'M1 진정관리', true, true, 'data:image/png;base64,AAAA',
   'https://example.invalid/m1/before.webp', 'https://example.invalid/m1/after.webp', true,
   'M1 땅콩 알레르기', 'M1 장벽 회복 중', 'M1 진정 앰플', now() + interval '1 day'),
  ('e4000000-0000-4000-8000-000000000002', 'e2000000-0000-4000-8000-000000000001',
   'e3000000-0000-4000-8000-000000000001', 2, 'M1 미동의', false, false, 'data:image/png;base64,AAAA',
   'https://example.invalid/m1/before2.webp', null, false,
   null, null, null, now() + interval '1 day');

-- ---------------------------------------------------------------- M1-01 privileges
do $$
begin
  if has_function_privilege('anon', 'public.create_customer_link(uuid, text, integer)', 'EXECUTE')
     or has_function_privilege('anon', 'public.revoke_customer_links(uuid, text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.submit_review_with_token(text, integer, text, jsonb)', 'EXECUTE')
     or has_function_privilege('anon', 'public._resolve_customer_token(text, text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public._resolve_customer_token(text, text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.is_shop_owner(uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.is_shop_manager(uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.mask_person_name(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.enforce_case_share_consent()', 'EXECUTE')
     or has_function_privilege('anon', 'public.guard_shop_protected_columns()', 'EXECUTE')
     or has_table_privilege('anon', 'public.customer_access_tokens', 'SELECT')
     or has_table_privilege('anon', 'public.customer_access_tokens', 'INSERT')
     or has_table_privilege('authenticated', 'public.customer_access_tokens', 'INSERT')
     or has_table_privilege('authenticated', 'public.customer_access_tokens', 'UPDATE') then
    raise exception 'M1-01 FAIL: unexpected privilege on an M1 object';
  end if;
  if not (has_function_privilege('anon', 'public.get_care_report_by_token(text)', 'EXECUTE')
      and has_function_privilege('anon', 'public.get_review_context(text)', 'EXECUTE')
      and has_function_privilege('anon', 'public.submit_care_request(uuid, text, text, timestamptz, text, text)', 'EXECUTE')
      and has_function_privilege('anon', 'public.list_community_shared_cases(integer, integer)', 'EXECUTE')
      and has_function_privilege('authenticated', 'public.create_customer_link(uuid, text, integer)', 'EXECUTE')
      and has_function_privilege('authenticated', 'public.submit_review_with_token(text, integer, text, jsonb)', 'EXECUTE')) then
    raise exception 'M1-01 FAIL: missing expected EXECUTE grant';
  end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.prosecdef
                and p.proname in ('is_shop_owner', 'is_shop_manager', 'create_customer_link', 'revoke_customer_links',
                                  '_resolve_customer_token', 'get_care_report_by_token', 'get_review_context',
                                  'submit_review_with_token', 'submit_care_request', 'list_community_shared_cases',
                                  'enforce_case_share_consent')
                and not ('search_path=""' = any (coalesce(p.proconfig, '{}'::text[])))) then
    raise exception 'M1-01 FAIL: SECURITY DEFINER function without fixed empty search_path';
  end if;
  if (select prosecdef from pg_proc where oid = 'public.guard_shop_protected_columns()'::regprocedure) then
    raise exception 'M1-01 FAIL: guard_shop_protected_columns must be SECURITY INVOKER';
  end if;
  raise notice 'M1-01 ok privileges';
end $$;

-- ---------------------------------------------------------------- M1-02 helpers
do $$
begin
  if public.mask_person_name('김민희') <> '김*희' or public.mask_person_name('이수') <> '이*'
     or public.mask_person_name('남궁민수') <> '남**수' or public.mask_person_name('  ') is not null
     or public.mask_person_name('김') <> '*' then
    raise exception 'M1-02 FAIL: mask_person_name';
  end if;
  if public.try_uuid('nope') is not null
     or public.try_uuid('e2000000-0000-4000-8000-000000000001') <> 'e2000000-0000-4000-8000-000000000001'::uuid then
    raise exception 'M1-02 FAIL: try_uuid';
  end if;
  raise notice 'M1-02 ok helpers';
end $$;

-- ---------------------------------------------------------------- M1-03 anon basics
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
do $$
begin
  begin
    perform count(*) from public.customer_access_tokens;
    raise exception 'M1-03 FAIL: anon read customer_access_tokens';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.create_customer_link('e4000000-0000-4000-8000-000000000001'::uuid, 'care_report', 30);
    raise exception 'M1-03 FAIL: anon executed create_customer_link';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.get_review_context('short');
    raise exception 'M1-03 FAIL: short token accepted';
  exception when sqlstate 'PT404' then null;
  end;
  begin
    perform public.get_care_report_by_token('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
    raise exception 'M1-03 FAIL: unknown token accepted';
  exception when sqlstate 'PT404' then null;
  end;
  raise notice 'M1-03 ok anon basics';
end $$;

-- ---------------------------------------------------------------- M1-04 community list (anon)
do $$
declare
  v jsonb := public.list_community_shared_cases(100, 0);
  e jsonb;
begin
  if jsonb_typeof(v) <> 'array' then raise exception 'M1-04 FAIL: not an array'; end if;
  select x into e from jsonb_array_elements(v) x where x->>'chart_id' = 'e4000000-0000-4000-8000-000000000001';
  if e is null then raise exception 'M1-04 FAIL: consented shared case missing'; end if;
  if exists (select 1 from jsonb_array_elements(v) x where x->>'chart_id' = 'e4000000-0000-4000-8000-000000000002') then
    raise exception 'M1-04 FAIL: non-consented case listed';
  end if;
  if exists (select 1 from jsonb_array_elements(v) x, jsonb_object_keys(x) k
              where k in ('signature_url', 'consent_pdf_url', 'customer_review_text', 'review_original_text',
                          'review_edited_text', 'director_reply', 'treatment_summary', 'customer_age',
                          'customer_id', 'allergy_notes', 'phone')) then
    raise exception 'M1-04 FAIL: forbidden key in community payload';
  end if;
  if (e->>'customer_age_band')::int is distinct from ((extract(year from current_date)::int - 1990) / 10 * 10) then
    raise exception 'M1-04 FAIL: age band %', e->>'customer_age_band';
  end if;
  if e->>'customer_gender_label' <> '여성' or e->>'shop_name' <> 'M1 테스트샵' then
    raise exception 'M1-04 FAIL: payload fields';
  end if;
  raise notice 'M1-04 ok community list';
end $$;

-- ---------------------------------------------------------------- M1-05 care request (anon)
do $$
declare v_id uuid;
begin
  v_id := public.submit_care_request('e2000000-0000-4000-8000-000000000001', '박고객', '010-9999-0000',
                                     now() + interval '2 days', '진정관리', '오후 희망');
  if v_id is null then raise exception 'M1-05 FAIL: no id'; end if;
  begin
    perform public.submit_care_request('e2000000-0000-4000-8000-000000000001', '박고객', '12', now() + interval '2 days');
    raise exception 'M1-05 FAIL: bad phone accepted';
  exception when sqlstate '22023' then null;
  end;
  begin
    perform public.submit_care_request('e2000000-0000-4000-8000-0000000000ff', '박고객', '01099990000', now() + interval '2 days');
    raise exception 'M1-05 FAIL: unknown shop accepted';
  exception when sqlstate 'PT404' then null;
  end;
  begin
    perform public.submit_care_request('e2000000-0000-4000-8000-000000000001', '박고객', '01099990000', now() + interval '400 days');
    raise exception 'M1-05 FAIL: far future accepted';
  exception when sqlstate '22023' then null;
  end;
  perform public.submit_care_request('e2000000-0000-4000-8000-000000000001', '박고객', '01099990000', now() + interval '3 days');
  perform public.submit_care_request('e2000000-0000-4000-8000-000000000001', '박고객', '01099990000', now() + interval '4 days');
  begin
    perform public.submit_care_request('e2000000-0000-4000-8000-000000000001', '박고객', '01099990000', now() + interval '5 days');
    raise exception 'M1-05 FAIL: rate limit not enforced';
  exception when sqlstate 'PT429' then null;
  end;
  raise notice 'M1-05 ok care request';
end $$;
reset role;
do $$
begin
  if (select count(*) from public.care_schedule_entries
       where shop_id = 'e2000000-0000-4000-8000-000000000001' and source = 'customerLead'
         and customer_phone = '01099990000' and status = 'scheduled') <> 3 then
    raise exception 'M1-05 FAIL: expected 3 stored leads';
  end if;
end $$;

-- ---------------------------------------------------------------- M1-06 link creation (authenticated)
set local role authenticated;
set local request.jwt.claims = '{"sub":"e1000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$
begin
  begin
    perform public.create_customer_link('e4000000-0000-4000-8000-000000000001'::uuid, 'care_report', 30);
    raise exception 'M1-06 FAIL: stranger created a link';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.revoke_customer_links('e4000000-0000-4000-8000-000000000001'::uuid, null);
    raise exception 'M1-06 FAIL: stranger revoked links';
  exception when insufficient_privilege then null;
  end;
end $$;

set local request.jwt.claims = '{"sub":"e1000000-0000-4000-8000-000000000001","role":"authenticated"}';
do $$
declare r jsonb;
begin
  begin
    perform public.create_customer_link('e4000000-0000-4000-8000-000000000001'::uuid, 'bogus', 30);
    raise exception 'M1-06 FAIL: bad kind accepted';
  exception when sqlstate '22023' then null;
  end;
  r := public.create_customer_link('e4000000-0000-4000-8000-000000000001'::uuid, 'care_report', 30);
  if char_length(r->>'token') <> 43 or (r->>'token') !~ '^[A-Za-z0-9_-]{43}$' then
    raise exception 'M1-06 FAIL: token format %', r->>'token';
  end if;
  if (r->>'expires_at')::timestamptz not between now() + interval '29 days 23 hours' and now() + interval '30 days 1 minute' then
    raise exception 'M1-06 FAIL: default expiry';
  end if;
  perform set_config('m1.care_token', r->>'token', true);
  r := public.create_customer_link('e4000000-0000-4000-8000-000000000001'::uuid, 'review');
  perform set_config('m1.review_token', r->>'token', true);
  r := public.create_customer_link('e4000000-0000-4000-8000-000000000001'::uuid, 'care_report', 365);
  if (r->>'expires_at')::timestamptz > now() + interval '30 days 1 minute' then
    raise exception 'M1-06 FAIL: ttl not clamped to 30 days (Q2)';
  end if;
  perform set_config('m1.expire_token', r->>'token', true);
  perform set_config('m1.expire_id', r->>'id', true);
  if (select count(*) from public.customer_access_tokens) <> 3 then
    raise exception 'M1-06 FAIL: owner should see 3 tokens via RLS';
  end if;
  raise notice 'M1-06 ok link creation';
end $$;

set local request.jwt.claims = '{"sub":"e1000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$
begin
  if (select count(*) from public.customer_access_tokens) <> 0 then
    raise exception 'M1-06 FAIL: stranger can see tokens';
  end if;
end $$;

-- ---------------------------------------------------------------- M1-07 care report (anon)
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
do $$
declare
  r jsonb := public.get_care_report_by_token(current_setting('m1.care_token'));
  allowed text[] := array['id', 'shop_id', 'visit_number', 'visit_date', 'created_at', 'care_name', 'treatment_summary',
                          'director_insight', 'home_care_prescriptions', 'care_report_json', 'care_report_generated_at',
                          'before_image_url', 'after_image_url'];
begin
  if r->>'customer_display_name' <> '김*희' then raise exception 'M1-07 FAIL: name not masked (Q4)'; end if;
  if exists (select 1 from jsonb_object_keys(r->'chart') k where k <> all (allowed)) then
    raise exception 'M1-07 FAIL: unexpected chart key';
  end if;
  if exists (select 1 from jsonb_object_keys(r->'shop') k
              where k in ('owner_user_id', 'kakao_point', 'sori_cash_balance', 'is_official')) then
    raise exception 'M1-07 FAIL: unexpected shop key';
  end if;
  if r::text like '%M1 땅콩%' or r::text like '%data:image%' or r::text like '%010-1234%' then
    raise exception 'M1-07 FAIL: sensitive value leaked';
  end if;
  if r->'chart'->>'before_image_url' is null or (r->>'photos_withheld')::boolean then
    raise exception 'M1-07 FAIL: consented photo missing';
  end if;
  if r->'chart'->>'care_name' <> 'M1 진정관리' then raise exception 'M1-07 FAIL: care_name'; end if;
  begin
    perform public.get_review_context(current_setting('m1.care_token'));
    raise exception 'M1-07 FAIL: care_report token accepted as review token';
  exception when sqlstate 'PT404' then null;
  end;
  raise notice 'M1-07 ok care report';
end $$;
reset role;
do $$
begin
  if (select open_count from public.customer_access_tokens
       where token_hash = extensions.digest(current_setting('m1.care_token'), 'sha256')) <> 1 then
    raise exception 'M1-07 FAIL: open_count not recorded';
  end if;
  -- photo consent gate (Q6)
  update public.customer_charts set consent_photo = false where id = 'e4000000-0000-4000-8000-000000000001';
  if (public.get_care_report_by_token(current_setting('m1.care_token'))->'chart'->>'before_image_url') is not null
     or not (public.get_care_report_by_token(current_setting('m1.care_token'))->>'photos_withheld')::boolean then
    raise exception 'M1-07 FAIL: photo shown without consent_photo';
  end if;
  update public.customer_charts set consent_photo = true where id = 'e4000000-0000-4000-8000-000000000001';
  -- expiry
  update public.customer_access_tokens
     set created_at = now() - interval '31 days', expires_at = now() - interval '1 day'
   where id = current_setting('m1.expire_id')::uuid;
end $$;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
do $$
begin
  begin
    perform public.get_care_report_by_token(current_setting('m1.expire_token'));
    raise exception 'M1-08 FAIL: expired token accepted';
  exception when sqlstate 'PT410' then null;
  end;
  raise notice 'M1-08 ok expiry';
end $$;

-- ---------------------------------------------------------------- M1-09 review flow
do $$
declare r jsonb := public.get_review_context(current_setting('m1.review_token'));
begin
  if r->'shop'->>'name' <> 'M1 테스트샵' or r->>'customer_display_name' <> '김*희'
     or r->'review' <> 'null'::jsonb then
    raise exception 'M1-09 FAIL: review context %', r;
  end if;
  begin
    perform public.submit_review_with_token(current_setting('m1.review_token'), 5, '좋아요', '[]'::jsonb);
    raise exception 'M1-09 FAIL: anon submitted a review';
  exception when insufficient_privilege then null;
  end;
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"e1000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$
declare v1 uuid; v2 uuid;
begin
  begin
    perform public.submit_review_with_token(current_setting('m1.review_token'), 6, '좋아요', '[]'::jsonb);
    raise exception 'M1-09 FAIL: rating 6 accepted';
  exception when sqlstate '22023' then null;
  end;
  v1 := public.submit_review_with_token(current_setting('m1.review_token'), 5, '피부가 편안해졌어요', '["진정"]'::jsonb);
  v2 := public.submit_review_with_token(current_setting('m1.review_token'), 4, '수정한 후기', '[]'::jsonb);
  if v1 is null or v1 <> v2 then raise exception 'M1-09 FAIL: resubmit should update the same draft'; end if;
  if (public.get_review_context(current_setting('m1.review_token'))->'review'->>'status') <> 'draft' then
    raise exception 'M1-09 FAIL: review status';
  end if;
  perform set_config('m1.review_id', v1::text, true);
end $$;
reset role;
update public.customer_reviews set status = 'published' where id = current_setting('m1.review_id')::uuid;
do $$
begin
  if (select rating from public.customer_reviews where id = current_setting('m1.review_id')::uuid) <> 4
     or (select shop_id from public.customer_reviews where id = current_setting('m1.review_id')::uuid)
        <> 'e2000000-0000-4000-8000-000000000001' then
    raise exception 'M1-09 FAIL: stored review';
  end if;
end $$;
set local role authenticated;
set local request.jwt.claims = '{"sub":"e1000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$
begin
  begin
    perform public.submit_review_with_token(current_setting('m1.review_token'), 5, '또 씀', '[]'::jsonb);
    raise exception 'M1-09 FAIL: published review overwritten';
  exception when sqlstate 'PT409' then null;
  end;
  raise notice 'M1-09 ok review flow';
end $$;

-- ---------------------------------------------------------------- M1-10 revoke
set local request.jwt.claims = '{"sub":"e1000000-0000-4000-8000-000000000001","role":"authenticated"}';
do $$
begin
  if public.revoke_customer_links('e4000000-0000-4000-8000-000000000001'::uuid, 'care_report') <> 2 then
    raise exception 'M1-10 FAIL: expected 2 care_report links revoked';
  end if;
end $$;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
do $$
begin
  begin
    perform public.get_care_report_by_token(current_setting('m1.care_token'));
    raise exception 'M1-10 FAIL: revoked token accepted';
  exception when sqlstate 'PT410' then null;
  end;
  perform public.get_review_context(current_setting('m1.review_token'));  -- other kind still valid
  raise notice 'M1-10 ok revoke';
end $$;
reset role;

-- ---------------------------------------------------------------- M1-11 consent trigger
do $$
begin
  update public.customer_charts set is_case_shared = true, case_shared = true
   where id = 'e4000000-0000-4000-8000-000000000002';
  if (select is_case_shared or case_shared from public.customer_charts
       where id = 'e4000000-0000-4000-8000-000000000002') then
    raise exception 'M1-11 FAIL: share without marketing consent was kept';
  end if;
  insert into public.customer_charts (id, shop_id, customer_id, visit_number, care_name, consent_marketing, is_case_shared, case_shared)
  values ('e4000000-0000-4000-8000-000000000003', 'e2000000-0000-4000-8000-000000000001',
          'e3000000-0000-4000-8000-000000000001', 3, 'M1 서명없음', true, true, true);
  if (select is_case_shared or case_shared from public.customer_charts
       where id = 'e4000000-0000-4000-8000-000000000003') then
    raise exception 'M1-11 FAIL: share without signature/PDF was kept';
  end if;
  insert into public.community_posts (shop_id, post_type, title, status, source_chart_id)
  values ('e2000000-0000-4000-8000-000000000001', 'case_share', 'M1 case', 'published',
          'e4000000-0000-4000-8000-000000000001');
  update public.customer_charts set consent_marketing = false where id = 'e4000000-0000-4000-8000-000000000001';
  if (select is_case_shared from public.customer_charts where id = 'e4000000-0000-4000-8000-000000000001') then
    raise exception 'M1-11 FAIL: withdrawn consent kept the case shared';
  end if;
  if exists (select 1 from public.community_posts
              where source_chart_id = 'e4000000-0000-4000-8000-000000000001' and status <> 'hidden') then
    raise exception 'M1-11 FAIL: case_share post not hidden after consent withdrawal';
  end if;
  if exists (select 1 from jsonb_array_elements(public.list_community_shared_cases(100, 0)) x
              where x->>'chart_id' = 'e4000000-0000-4000-8000-000000000001') then
    raise exception 'M1-11 FAIL: withdrawn case still listed';
  end if;
  raise notice 'M1-11 ok consent trigger';
end $$;

-- ---------------------------------------------------------------- M1-12 shops guard
-- (a) anon cannot take over an owned shop (42501, or 0 rows once S5 policies exist)
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
do $$
begin
  begin
    update public.shops set owner_user_id = 'e1000000-0000-4000-8000-000000000002'
     where id = 'e2000000-0000-4000-8000-000000000001';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.shops set owner_user_id = 'e1000000-0000-4000-8000-000000000002'
     where id = 'e2000000-0000-4000-8000-000000000002';
  exception when insufficient_privilege then null;
  end;
end $$;
-- (b..g) authenticated
set local role authenticated;
set local request.jwt.claims = '{"sub":"e1000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$
begin
  begin
    update public.shops set owner_user_id = 'e1000000-0000-4000-8000-000000000002'
     where id = 'e2000000-0000-4000-8000-000000000001';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.shops set owner_user_id = 'e1000000-0000-4000-8000-000000000001'
     where id = 'e2000000-0000-4000-8000-000000000002';
    raise exception 'M1-12 FAIL: claimed an ownerless shop for someone else';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.shops set owner_user_id = 'e1000000-0000-4000-8000-000000000002'
     where id = 'e2000000-0000-4000-8000-000000000003';
    raise exception 'M1-12 FAIL: claimed the official shop (Q14)';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.shops (name, owner_user_id) values ('M1 남의샵', 'e1000000-0000-4000-8000-000000000001');
    raise exception 'M1-12 FAIL: inserted a shop owned by someone else';
  exception when insufficient_privilege then null;
  end;
end $$;
-- (e) current onboarding flow: new director inserts a shop without owner, then linkShopOwner sets it
set local request.jwt.claims = '{"sub":"e1000000-0000-4000-8000-000000000003","role":"authenticated"}';
insert into public.shops (id, name, is_official, kakao_point) values
  ('e2000000-0000-4000-8000-000000000004', 'M1 신규샵', true, 500);
update public.shops set owner_user_id = 'e1000000-0000-4000-8000-000000000003', updated_at = now()
 where id = 'e2000000-0000-4000-8000-000000000004';
-- (g) owner edits own shop; protected columns stay
set local request.jwt.claims = '{"sub":"e1000000-0000-4000-8000-000000000001","role":"authenticated"}';
update public.shops
   set name = 'M1 테스트샵 수정', kakao_point = 999999, is_official = true,
       tier_badge = 'gold', sori_cash_balance = 5, follower_count = 77
 where id = 'e2000000-0000-4000-8000-000000000001';
reset role;
do $$
declare s record;
begin
  if (select owner_user_id from public.shops where id = 'e2000000-0000-4000-8000-000000000001')
     <> 'e1000000-0000-4000-8000-000000000001' then
    raise exception 'M1-12 FAIL: owned shop was taken over';
  end if;
  if (select owner_user_id from public.shops where id = 'e2000000-0000-4000-8000-000000000003') is not null then
    raise exception 'M1-12 FAIL: official shop got an owner';
  end if;
  select * into s from public.shops where id = 'e2000000-0000-4000-8000-000000000004';
  if s.owner_user_id <> 'e1000000-0000-4000-8000-000000000003' or s.is_official or s.kakao_point <> 0 then
    raise exception 'M1-12 FAIL: onboarding insert/claim (owner %, official %, kakao %)', s.owner_user_id, s.is_official, s.kakao_point;
  end if;
  if not exists (select 1 from public.shop_memberships
                  where shop_id = 'e2000000-0000-4000-8000-000000000004'
                    and user_id = 'e1000000-0000-4000-8000-000000000003' and role = 'owner') then
    raise exception 'M1-12 FAIL: owner membership not synced by existing trigger';
  end if;
  select * into s from public.shops where id = 'e2000000-0000-4000-8000-000000000001';
  if s.name <> 'M1 테스트샵 수정' or s.kakao_point = 999999 or s.is_official or s.tier_badge::text = 'gold'
     or s.sori_cash_balance = 5 or s.follower_count = 77 then
    raise exception 'M1-12 FAIL: owner edit / protected columns';
  end if;
end $$;
-- (i) owner transfer, postgres and service_role bypass
set local role authenticated;
set local request.jwt.claims = '{"sub":"e1000000-0000-4000-8000-000000000001","role":"authenticated"}';
update public.shops set owner_user_id = 'e1000000-0000-4000-8000-000000000002'
 where id = 'e2000000-0000-4000-8000-000000000001';
reset role;
do $$
begin
  if (select owner_user_id from public.shops where id = 'e2000000-0000-4000-8000-000000000001')
     <> 'e1000000-0000-4000-8000-000000000002' then
    raise exception 'M1-12 FAIL: current owner could not transfer';
  end if;
  update public.shops set owner_user_id = 'e1000000-0000-4000-8000-000000000001', kakao_point = 42
   where id = 'e2000000-0000-4000-8000-000000000001';
  if (select kakao_point from public.shops where id = 'e2000000-0000-4000-8000-000000000001') <> 42 then
    raise exception 'M1-12 FAIL: postgres blocked';
  end if;
end $$;
set local role service_role;
set local request.jwt.claims = '{"role":"service_role"}';
update public.shops set owner_user_id = 'e1000000-0000-4000-8000-000000000003', is_official = true
 where id = 'e2000000-0000-4000-8000-000000000002';
reset role;
do $$
begin
  if (select owner_user_id from public.shops where id = 'e2000000-0000-4000-8000-000000000002')
     <> 'e1000000-0000-4000-8000-000000000003'
     or not (select is_official from public.shops where id = 'e2000000-0000-4000-8000-000000000002') then
    raise exception 'M1-12 FAIL: service_role blocked';
  end if;
  raise notice 'M1-12 ok shops guard';
end $$;

select 'M1 TESTS PASSED' as result;
rollback;
