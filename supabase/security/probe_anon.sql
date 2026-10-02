-- =============================================================================
-- SORI security baseline probe: what can the `anon` role (public anon key) do?
-- -----------------------------------------------------------------------------
-- * 100% read-only. Every block runs in `begin read only; ... rollback;` and
--   never executes INSERT/UPDATE/DELETE. "Would write be permitted" is answered
--   with has_table_privilege() + evaluating the applicable RLS policy
--   expressions in a SELECT (rows matched by the UPDATE/DELETE USING clauses,
--   INSERT WITH CHECK text).
-- * Repeatable: run before/after each P0 step (S1, S4, S5, S8) and diff.
-- * How to run: Supabase SQL editor, psql, or MCP execute_sql - one block at a time.
-- * Dynamic counting uses query_to_xml() so it works inside a single SELECT.
-- * request.jwt.claims is set like PostgREST does for the anon key (some policies
--   call current_setting('request.jwt.claims') without missing_ok).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- P1. Key tables: privileges, rows readable, rows UPDATE/DELETE-able by policy,
--     INSERT policy check.
-- ---------------------------------------------------------------------------
begin read only;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';  -- same as PostgREST for anon requests
set local search_path = public, extensions;

with t(tbl) as (
  values ('customers'), ('customer_charts'), ('customer_reviews'), ('chart_photo_records'),
         ('photo_sets'), ('review_replies'), ('ai_replies'), ('membership_tickets'),
         ('care_diary_notes'), ('kakao_msg_logs'), ('chart_records'), ('customer_merge_events'),
         ('chart_view_events'), ('care_schedule_entries'), ('ba_capture_sessions'),
         ('shops'), ('shop_posts'), ('shop_gallery_items'), ('shop_highlights'), ('shop_memberships'),
         ('shop_notifications'), ('profiles'), ('community_posts'), ('community_comments'),
         ('wallets'), ('point_transactions'), ('settlement_transactions'), ('market_escrow_holds'),
         ('shop_entitlements'), ('shop_promo_credits'), ('customer_access_tokens')
),
pol as (
  select p.tablename::text as tbl, p.cmd, p.qual, p.with_check
    from pg_policies p
   where p.schemaname = 'public'
     and p.permissive = 'PERMISSIVE'
     and p.roles && array['public', 'anon']::name[]
),
agg as (
  select t.tbl,
         to_regclass('public.' || quote_ident(t.tbl)) as rel,
         string_agg('(' || coalesce(p.qual, 'false') || ')', ' or ')
           filter (where p.cmd in ('UPDATE', 'ALL')) as upd_using,
         string_agg('(' || coalesce(p.qual, 'false') || ')', ' or ')
           filter (where p.cmd in ('DELETE', 'ALL')) as del_using,
         string_agg(coalesce(p.with_check, p.qual, 'false'), ' | ')
           filter (where p.cmd in ('INSERT', 'ALL')) as ins_check
    from t left join pol p on p.tbl = t.tbl
   group by t.tbl
),
priv as (
  select a.*,
         a.rel is not null and has_table_privilege(a.rel, 'SELECT') as p_sel,
         a.rel is not null and has_table_privilege(a.rel, 'INSERT') as p_ins,
         a.rel is not null and has_table_privilege(a.rel, 'UPDATE') as p_upd,
         a.rel is not null and has_table_privilege(a.rel, 'DELETE') as p_del
    from agg a
)
select tbl,
       case when rel is null then 'missing' else concat_ws('',
         case when p_sel then 'S' end, case when p_ins then 'I' end,
         case when p_upd then 'U' end, case when p_del then 'D' end) end as anon_table_privs,
       case when p_sel then (xpath('/row/c/text()', query_to_xml(
         format('select count(*) as c from public.%I', tbl), false, true, '')))[1]::text::bigint end
         as rows_readable,
       case when p_upd and p_sel and upd_using is not null then (xpath('/row/c/text()', query_to_xml(
         format('select count(*) as c from public.%I where %s', tbl, upd_using), false, true, '')))[1]::text::bigint
         when rel is null then null else 0 end as rows_updatable,
       case when p_del and p_sel and del_using is not null then (xpath('/row/c/text()', query_to_xml(
         format('select count(*) as c from public.%I where %s', tbl, del_using), false, true, '')))[1]::text::bigint
         when rel is null then null else 0 end as rows_deletable,
       case when rel is null then 'missing'
            when not p_ins or ins_check is null then 'no'
            when ins_check ~ '(^|\| )true( \||$)' then 'YES (any row)'
            else 'conditional: ' || left(ins_check, 120) end as insert_allowed
  from priv
 order by tbl;
rollback;

-- ---------------------------------------------------------------------------
-- P2. Sensitive columns readable by anon (counts only, never the values).
-- ---------------------------------------------------------------------------
begin read only;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';  -- same as PostgREST for anon requests
select
  (select count(*) from public.customer_charts where coalesce(signature_url, '') <> '')             as charts_with_signature,
  (select count(*) from public.customer_charts where signature_url like 'data:%')                   as signature_data_uri,
  (select count(*) from public.customer_charts where coalesce(consent_pdf_url, '') <> '')           as charts_with_consent_pdf_url,
  (select count(*) from public.customer_charts
     where concat(allergy_notes, side_effects, psychological_interview, side_effect_history) ~ '\S') as charts_with_sensitive_notes,
  (select count(*) from public.customer_charts
     where coalesce(before_image_url, '') like '%/object/public/%'
        or coalesce(after_image_url, '') like '%/object/public/%')                                  as charts_with_public_photo_url,
  (select count(*) from public.customers where coalesce(phone, '') <> '')                           as customers_with_phone,
  (select count(*) from public.customer_reviews where coalesce(original_text, '') <> '')            as reviews_with_text,
  (select count(*) from public.community_shared_cases)                                              as community_view_rows,
  (select count(*) from public.profiles where coalesce(name, '') <> '')                             as profiles_with_name;
rollback;

-- ---------------------------------------------------------------------------
-- P3. Storage: objects listable by anon via storage.objects RLS (the Storage
--     `list` API uses the same policies). anon cannot read storage.buckets, so
--     bucket ids are listed explicitly; P3b reads the public flag as owner.
-- ---------------------------------------------------------------------------
begin read only;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';  -- same as PostgREST for anon requests
select b.id as bucket,
       (select count(*) from storage.objects o where o.bucket_id = b.id) as objects_listable_by_anon
  from (values ('chart_photos'), ('consent_pdfs'), ('shop_profiles'), ('chart-signatures'), ('chart-photos')) as b(id)
 order by b.id;
rollback;

-- P3b. (runs as the connecting role, still read-only) bucket public flags + object totals
begin read only;
select b.id as bucket, b.public,
       (select count(*) from storage.objects o where o.bucket_id = b.id) as objects_total
  from storage.buckets b
 order by b.id;
rollback;

-- ---------------------------------------------------------------------------
-- P4. RPC surface: SECURITY DEFINER functions anon can EXECUTE, and a watch-list
--     of money / publishing functions.
-- ---------------------------------------------------------------------------
begin read only;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';  -- same as PostgREST for anon requests
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef and has_function_privilege(p.oid, 'EXECUTE')) as anon_exec_secdef,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef) as total_secdef,
  (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege(p.oid, 'EXECUTE')
      and p.proname in ('purchase_sori_points', 'purchase_sori_points_customer', 'credit_points', 'debit_points',
                        'credit_settlement', 'request_settlement_withdraw', 'complete_settlement_withdraw',
                        'hold_market_escrow', 'complete_market_escrow', 'refund_market_escrow',
                        'save_chart_and_publish_case', 'purchase_point_shop_item', 'get_customer_wallet',
                        'delete_shop_customers', 'merge_shop_customers')) as anon_exec_watchlist,
  (select string_agg(p.proname, ', ' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege(p.oid, 'EXECUTE')
      and p.proname in ('get_care_report_by_token', 'get_review_context', 'submit_care_request',
                        'list_community_shared_cases', 'submit_review_with_token', 'create_customer_link',
                        'revoke_customer_links', 'is_shop_owner', 'is_shop_manager')) as anon_exec_m1_functions;
rollback;
