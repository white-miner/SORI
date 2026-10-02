-- =============================================================================
-- ROLLBACK for supabase/migrations/20261002225112_sec_m1_tokens_rpcs.sql (SORI P0 M1 / S1)
-- -----------------------------------------------------------------------------
-- Drops ONLY the objects created by M1, in dependency order. Nothing that existed
-- before M1 is touched, so no snapshot restore is needed for this step.
-- Not reverted (data, by design): customer_charts rows whose is_case_shared was
-- coerced to false by trg_enforce_case_share_consent, and community_posts hidden by
-- it, while M1 was active. Check with:
--   select id, status, updated_at from public.community_posts
--    where post_type = 'case_share' and status = 'hidden' and updated_at > '<apply time>';
-- Issued customer links stop working (their table is dropped).
-- =============================================================================
begin;

drop trigger if exists trg_guard_shop_protected_columns on public.shops;
drop trigger if exists trg_enforce_case_share_consent on public.customer_charts;
drop function if exists public.guard_shop_protected_columns();
drop function if exists public.enforce_case_share_consent();

drop function if exists public.list_community_shared_cases(integer, integer);
drop function if exists public.submit_care_request(uuid, text, text, timestamptz, text, text);
drop function if exists public.submit_review_with_token(text, integer, text, jsonb);
drop function if exists public.get_review_context(text);
drop function if exists public.get_care_report_by_token(text);
drop function if exists public._resolve_customer_token(text, text);
drop function if exists public.revoke_customer_links(uuid, text);
drop function if exists public.create_customer_link(uuid, text, integer);

drop table if exists public.customer_access_tokens;

drop function if exists public.mask_person_name(text);
drop function if exists public.is_shop_manager(uuid);
drop function if exists public.is_shop_owner(uuid);
drop function if exists public.try_uuid(text);

notify pgrst, 'reload schema';
commit;
