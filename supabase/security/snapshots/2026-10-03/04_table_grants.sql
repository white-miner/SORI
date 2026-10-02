-- SORI security snapshot: table/view privileges for PUBLIC, anon, authenticated, service_role (100 relations)
-- project: tieojdbzmqcmlwyqltrk / captured at 2026-10-02 22:30:45.429761+00 (UTC) = 2026-10-03 KST
-- server: PostgreSQL 17.6 on aarch64-unknown-linux-gnu, compiled by gcc (GCC) 15.2.0, 64-bit
-- Generated read-only from catalog queries (pg_policies, pg_class.relacl, pg_proc, pg_views, storage.buckets).
-- See README.md in this folder before running anything.

-- For each relation: revoke everything from the four API roles, then re-grant exactly what was captured.
-- Owner (postgres) privileges are not touched. No column-level ACLs existed at capture time.
begin;

-- table public.admin_audit_log  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.admin_audit_log from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.admin_audit_log to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.admin_audit_log to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.admin_audit_log to service_role;

-- table public.affiliate_clicks  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.affiliate_clicks from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_clicks to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_clicks to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_clicks to service_role;

-- table public.affiliate_commissions  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.affiliate_commissions from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_commissions to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_commissions to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_commissions to service_role;

-- table public.affiliate_conversions  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.affiliate_conversions from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_conversions to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_conversions to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_conversions to service_role;

-- table public.affiliate_links  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.affiliate_links from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_links to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_links to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.affiliate_links to service_role;

-- table public.ai_replies  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.ai_replies from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ai_replies to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ai_replies to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ai_replies to service_role;

-- table public.ai_tool_jobs  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.ai_tool_jobs from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ai_tool_jobs to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ai_tool_jobs to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ai_tool_jobs to service_role;

-- table public.ai_tool_quota  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.ai_tool_quota from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ai_tool_quota to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ai_tool_quota to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ai_tool_quota to service_role;

-- table public.b2b_partners  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.b2b_partners from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.b2b_partners to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.b2b_partners to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.b2b_partners to service_role;

-- table public.ba_capture_sessions  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.ba_capture_sessions from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ba_capture_sessions to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ba_capture_sessions to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.ba_capture_sessions to service_role;

-- table public.boost_placements  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.boost_placements from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.boost_placements to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.boost_placements to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.boost_placements to service_role;

-- table public.boost_premium_overlays  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.boost_premium_overlays from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.boost_premium_overlays to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.boost_premium_overlays to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.boost_premium_overlays to service_role;

-- table public.care_diary_notes  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.care_diary_notes from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.care_diary_notes to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.care_diary_notes to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.care_diary_notes to service_role;

-- table public.care_program_templates  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.care_program_templates from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.care_program_templates to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.care_program_templates to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.care_program_templates to service_role;

-- table public.care_schedule_entries  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.care_schedule_entries from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.care_schedule_entries to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.care_schedule_entries to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.care_schedule_entries to service_role;

-- table public.case_bookmarks  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.case_bookmarks from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.case_bookmarks to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.case_bookmarks to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.case_bookmarks to service_role;

-- table public.chart_likes  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.chart_likes from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_likes to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_likes to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_likes to service_role;

-- table public.chart_photo_records  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.chart_photo_records from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_photo_records to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_photo_records to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_photo_records to service_role;

-- table public.chart_records  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.chart_records from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_records to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_records to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_records to service_role;

-- table public.chart_view_events  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.chart_view_events from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_view_events to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_view_events to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.chart_view_events to service_role;

-- table public.clinical_environment_rules  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.clinical_environment_rules from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.clinical_environment_rules to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.clinical_environment_rules to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.clinical_environment_rules to service_role;

-- table public.clinical_trend_keywords  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.clinical_trend_keywords from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.clinical_trend_keywords to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.clinical_trend_keywords to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.clinical_trend_keywords to service_role;

-- table public.clinical_trend_scripts  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.clinical_trend_scripts from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.clinical_trend_scripts to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.clinical_trend_scripts to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.clinical_trend_scripts to service_role;

-- table public.community_comments  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.community_comments from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_comments to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_comments to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_comments to service_role;

-- table public.community_posts  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.community_posts from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_posts to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_posts to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_posts to service_role;

-- view public.community_shared_cases  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres,=r/postgres}
revoke all on public.community_shared_cases from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_shared_cases to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_shared_cases to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_shared_cases to service_role;
grant SELECT on public.community_shared_cases to PUBLIC;

-- table public.community_whisper_recipients  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.community_whisper_recipients from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_whisper_recipients to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_whisper_recipients to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.community_whisper_recipients to service_role;

-- table public.customer_charts  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.customer_charts from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_charts to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_charts to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_charts to service_role;

-- table public.customer_diaries  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.customer_diaries from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_diaries to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_diaries to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_diaries to service_role;

-- table public.customer_merge_events  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.customer_merge_events from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_merge_events to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_merge_events to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_merge_events to service_role;

-- table public.customer_reviews  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.customer_reviews from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_reviews to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_reviews to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customer_reviews to service_role;

-- table public.customers  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.customers from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customers to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customers to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.customers to service_role;

-- table public.device_reviews  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.device_reviews from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.device_reviews to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.device_reviews to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.device_reviews to service_role;

-- table public.echo_earn_quota  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.echo_earn_quota from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.echo_earn_quota to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.echo_earn_quota to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.echo_earn_quota to service_role;

-- table public.echo_earn_quota_customer  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.echo_earn_quota_customer from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.echo_earn_quota_customer to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.echo_earn_quota_customer to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.echo_earn_quota_customer to service_role;

-- table public.fan_gifts  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.fan_gifts from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.fan_gifts to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.fan_gifts to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.fan_gifts to service_role;

-- table public.kakao_msg_logs  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.kakao_msg_logs from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.kakao_msg_logs to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.kakao_msg_logs to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.kakao_msg_logs to service_role;

-- table public.listing_inquiries  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.listing_inquiries from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.listing_inquiries to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.listing_inquiries to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.listing_inquiries to service_role;

-- table public.market_escrow_holds  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.market_escrow_holds from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.market_escrow_holds to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.market_escrow_holds to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.market_escrow_holds to service_role;

-- table public.market_listings  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.market_listings from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.market_listings to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.market_listings to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.market_listings to service_role;

-- table public.market_strategy_states  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.market_strategy_states from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.market_strategy_states to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.market_strategy_states to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.market_strategy_states to service_role;

-- table public.membership_tickets  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.membership_tickets from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.membership_tickets to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.membership_tickets to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.membership_tickets to service_role;

-- table public.mentoring_feedback  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.mentoring_feedback from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_feedback to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_feedback to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_feedback to service_role;

-- table public.mentoring_posts  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.mentoring_posts from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_posts to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_posts to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_posts to service_role;

-- table public.mentoring_purchases  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.mentoring_purchases from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_purchases to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_purchases to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_purchases to service_role;

-- table public.mentoring_requests  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.mentoring_requests from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_requests to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_requests to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.mentoring_requests to service_role;

-- table public.photo_sets  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.photo_sets from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.photo_sets to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.photo_sets to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.photo_sets to service_role;

-- table public.point_shop_items  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.point_shop_items from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.point_shop_items to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.point_shop_items to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.point_shop_items to service_role;

-- table public.point_transactions  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.point_transactions from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.point_transactions to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.point_transactions to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.point_transactions to service_role;

-- table public.post_media  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.post_media from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.post_media to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.post_media to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.post_media to service_role;

-- table public.post_tags  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.post_tags from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.post_tags to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.post_tags to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.post_tags to service_role;

-- table public.post_unlocks  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.post_unlocks from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.post_unlocks to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.post_unlocks to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.post_unlocks to service_role;

-- table public.profiles  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.profiles from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.profiles to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.profiles to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.profiles to service_role;

-- table public.program_categories  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.program_categories from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_categories to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_categories to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_categories to service_role;

-- table public.program_customer_coupons  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.program_customer_coupons from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_customer_coupons to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_customer_coupons to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_customer_coupons to service_role;

-- table public.program_memberships  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.program_memberships from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_memberships to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_memberships to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_memberships to service_role;

-- table public.program_package_lines  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.program_package_lines from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_package_lines to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_package_lines to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_package_lines to service_role;

-- table public.program_packages  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.program_packages from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_packages to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_packages to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_packages to service_role;

-- table public.program_promotions  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.program_promotions from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_promotions to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_promotions to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_promotions to service_role;

-- table public.program_quote_payments  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.program_quote_payments from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_quote_payments to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_quote_payments to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_quote_payments to service_role;

-- table public.program_quote_promos  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.program_quote_promos from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_quote_promos to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_quote_promos to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_quote_promos to service_role;

-- table public.program_quotes  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.program_quotes from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_quotes to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_quotes to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.program_quotes to service_role;

-- table public.region_content_bookmarks  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.region_content_bookmarks from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.region_content_bookmarks to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.region_content_bookmarks to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.region_content_bookmarks to service_role;

-- table public.review_replies  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.review_replies from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.review_replies to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.review_replies to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.review_replies to service_role;

-- table public.review_request_events  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.review_request_events from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.review_request_events to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.review_request_events to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.review_request_events to service_role;

-- table public.seminar_applications  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.seminar_applications from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_applications to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_applications to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_applications to service_role;

-- table public.seminar_classes  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.seminar_classes from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_classes to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_classes to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_classes to service_role;

-- table public.seminar_enrollment_reviews  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.seminar_enrollment_reviews from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_enrollment_reviews to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_enrollment_reviews to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_enrollment_reviews to service_role;

-- table public.seminar_enrollments  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.seminar_enrollments from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_enrollments to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_enrollments to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_enrollments to service_role;

-- table public.seminar_feedback_reports  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.seminar_feedback_reports from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_feedback_reports to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_feedback_reports to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_feedback_reports to service_role;

-- table public.seminar_requests  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.seminar_requests from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_requests to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_requests to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminar_requests to service_role;

-- view public.seminars  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres,=r/postgres}
revoke all on public.seminars from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminars to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminars to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.seminars to service_role;
grant SELECT on public.seminars to PUBLIC;

-- table public.settlement_transactions  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.settlement_transactions from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.settlement_transactions to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.settlement_transactions to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.settlement_transactions to service_role;

-- view public.shop_assets  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_assets from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_assets to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_assets to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_assets to service_role;

-- table public.shop_clinical_trend_snapshots  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_clinical_trend_snapshots from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_clinical_trend_snapshots to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_clinical_trend_snapshots to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_clinical_trend_snapshots to service_role;

-- table public.shop_daily_context  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_daily_context from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_daily_context to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_daily_context to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_daily_context to service_role;

-- table public.shop_entitlements  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_entitlements from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_entitlements to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_entitlements to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_entitlements to service_role;

-- table public.shop_followers  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_followers from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_followers to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_followers to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_followers to service_role;

-- table public.shop_gallery_items  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_gallery_items from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_gallery_items to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_gallery_items to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_gallery_items to service_role;

-- table public.shop_highlights  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_highlights from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_highlights to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_highlights to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_highlights to service_role;

-- table public.shop_hourly_climate  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_hourly_climate from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_hourly_climate to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_hourly_climate to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_hourly_climate to service_role;

-- table public.shop_memberships  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_memberships from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_memberships to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_memberships to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_memberships to service_role;

-- table public.shop_menus  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_menus from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_menus to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_menus to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_menus to service_role;

-- table public.shop_notifications  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_notifications from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_notifications to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_notifications to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_notifications to service_role;

-- table public.shop_posts  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_posts from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_posts to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_posts to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_posts to service_role;

-- table public.shop_promo_credits  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_promo_credits from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_promo_credits to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_promo_credits to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_promo_credits to service_role;

-- table public.shop_verifications  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shop_verifications from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_verifications to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_verifications to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shop_verifications to service_role;

-- table public.shops  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.shops from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shops to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shops to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.shops to service_role;

-- table public.sos_keyword_rules  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.sos_keyword_rules from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.sos_keyword_rules to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.sos_keyword_rules to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.sos_keyword_rules to service_role;

-- table public.staff_roles  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.staff_roles from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.staff_roles to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.staff_roles to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.staff_roles to service_role;

-- table public.subscriptions  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.subscriptions from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.subscriptions to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.subscriptions to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.subscriptions to service_role;

-- table public.tier_upgrade_rewards_log  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.tier_upgrade_rewards_log from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.tier_upgrade_rewards_log to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.tier_upgrade_rewards_log to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.tier_upgrade_rewards_log to service_role;

-- view public.unified_feed_items_v1  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.unified_feed_items_v1 from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.unified_feed_items_v1 to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.unified_feed_items_v1 to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.unified_feed_items_v1 to service_role;

-- table public.visit_operation_events  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.visit_operation_events from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.visit_operation_events to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.visit_operation_events to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.visit_operation_events to service_role;

-- table public.visit_operation_timers  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.visit_operation_timers from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.visit_operation_timers to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.visit_operation_timers to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.visit_operation_timers to service_role;

-- table public.visit_sessions  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.visit_sessions from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.visit_sessions to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.visit_sessions to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.visit_sessions to service_role;

-- table public.wallets  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.wallets from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.wallets to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.wallets to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.wallets to service_role;

-- table public.whisper_audience_presets  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.whisper_audience_presets from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.whisper_audience_presets to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.whisper_audience_presets to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.whisper_audience_presets to service_role;

-- table public.whisper_recipients  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.whisper_recipients from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.whisper_recipients to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.whisper_recipients to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.whisper_recipients to service_role;

-- table public.whispers  acl={postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres}
revoke all on public.whispers from PUBLIC, anon, authenticated, service_role;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.whispers to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.whispers to authenticated;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN on public.whispers to service_role;

commit;
