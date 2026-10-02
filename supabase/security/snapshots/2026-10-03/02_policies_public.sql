-- SORI security snapshot: public schema RLS policies (154 policies on 93 tables)
-- project: tieojdbzmqcmlwyqltrk / captured at 2026-10-02 22:30:45.429761+00 (UTC) = 2026-10-03 KST
-- server: PostgreSQL 17.6 on aarch64-unknown-linux-gnu, compiled by gcc (GCC) 15.2.0, 64-bit
-- Generated read-only from catalog queries (pg_policies, pg_class.relacl, pg_proc, pg_views, storage.buckets).
-- See README.md in this folder before running anything.

-- Restore = (1) drop policies created after the snapshot, (2) drop+recreate every snapshot policy.
begin;

-- Drop every public policy that did NOT exist at snapshot time (e.g. policies added by later P0 migrations).
do $$
declare p record;
begin
  for p in select tablename, policyname from pg_policies where schemaname = 'public' 
    and (tablename::text, policyname::text) not in (values
    ('affiliate_clicks','mvp_affiliate_clicks_all'),
    ('affiliate_commissions','mvp_affiliate_commissions_all'),
    ('affiliate_conversions','mvp_affiliate_conversions_all'),
    ('affiliate_links','mvp_affiliate_links_all'),
    ('ai_replies','mvp_ai_replies_insert'),
    ('ai_replies','mvp_ai_replies_select'),
    ('ai_replies','mvp_ai_replies_update'),
    ('ai_tool_jobs','mvp_ai_tool_jobs_all'),
    ('ai_tool_quota','mvp_ai_tool_quota_all'),
    ('b2b_partners','mvp_b2b_partners_select'),
    ('b2b_partners','mvp_b2b_partners_write'),
    ('ba_capture_sessions','ba_sessions_shop_read'),
    ('ba_capture_sessions','ba_sessions_shop_write'),
    ('boost_placements','mvp_boost_placements_all'),
    ('boost_premium_overlays','mvp_boost_premium_overlays_all'),
    ('care_program_templates','care_program_templates_shop_rw'),
    ('care_schedule_entries','care_schedule_lead_insert'),
    ('care_schedule_entries','care_schedule_shop_read'),
    ('care_schedule_entries','care_schedule_shop_write'),
    ('case_bookmarks','mvp_case_bookmarks_all'),
    ('chart_likes','mvp_chart_likes_all'),
    ('chart_photo_records','mvp_chart_photo_records_insert'),
    ('chart_photo_records','mvp_chart_photo_records_select'),
    ('chart_photo_records','mvp_chart_photo_records_update'),
    ('chart_records','Customer can view consented family charts'),
    ('chart_records','Director can manage own shop charts'),
    ('chart_records','Users and consented family can view charts'),
    ('chart_view_events','mvp_chart_view_events_all'),
    ('clinical_environment_rules','clinical_environment_rules_shop_read'),
    ('clinical_environment_rules','clinical_environment_rules_shop_write'),
    ('clinical_trend_keywords','clinical_trend_keywords_read'),
    ('clinical_trend_scripts','clinical_trend_scripts_read'),
    ('community_comments','mvp_community_comments_all'),
    ('community_posts','community_posts_select_visible'),
    ('community_posts','mvp_community_posts_delete'),
    ('community_posts','mvp_community_posts_insert'),
    ('community_posts','mvp_community_posts_update'),
    ('community_whisper_recipients','community_whisper_recipients_select'),
    ('customer_charts','mvp_charts_insert'),
    ('customer_charts','mvp_charts_select'),
    ('customer_charts','mvp_charts_update'),
    ('customer_diaries','Customer can manage own diaries'),
    ('customer_diaries','Users can manage their own diaries'),
    ('customer_merge_events','mvp_customer_merge_events_select'),
    ('customer_reviews','mvp_reviews_insert'),
    ('customer_reviews','mvp_reviews_select'),
    ('customer_reviews','mvp_reviews_update'),
    ('customers','mvp_customers_insert'),
    ('customers','mvp_customers_select'),
    ('customers','mvp_customers_update'),
    ('device_reviews','mvp_device_reviews_all'),
    ('echo_earn_quota','mvp_echo_earn_quota_all'),
    ('echo_earn_quota_customer','mvp_echo_earn_quota_customer_all'),
    ('fan_gifts','mvp_fan_gifts_all'),
    ('listing_inquiries','mvp_listing_inquiries_all'),
    ('market_escrow_holds','mvp_market_escrow_holds_all'),
    ('market_listings','mvp_market_listings_all'),
    ('market_strategy_states','market_strategy_states_owner'),
    ('membership_tickets','Users can view their own membership tickets'),
    ('membership_tickets','mvp_membership_tickets_delete'),
    ('membership_tickets','mvp_membership_tickets_insert'),
    ('membership_tickets','mvp_membership_tickets_select'),
    ('membership_tickets','mvp_membership_tickets_update'),
    ('mentoring_feedback','mvp_mentoring_feedback_all'),
    ('mentoring_posts','mvp_mentoring_posts_all'),
    ('mentoring_purchases','mvp_mentoring_purchases_all'),
    ('mentoring_requests','mvp_mentoring_requests_all'),
    ('photo_sets','mvp_photo_sets_insert'),
    ('photo_sets','mvp_photo_sets_select'),
    ('point_shop_items','mvp_point_shop_items_all'),
    ('point_transactions','mvp_point_transactions_all'),
    ('post_media','post_media_select_unlocked'),
    ('post_media','post_media_write_mvp'),
    ('post_tags','mvp_post_tags_all'),
    ('post_unlocks','mvp_post_unlocks_all'),
    ('profiles','mvp_profiles_select'),
    ('profiles','profiles_insert_own'),
    ('program_categories','program_categories_director'),
    ('program_customer_coupons','program_customer_coupons_director'),
    ('program_memberships','program_memberships_director'),
    ('program_package_lines','program_package_lines_director'),
    ('program_packages','program_packages_director'),
    ('program_promotions','program_promotions_director'),
    ('program_quote_payments','program_quote_payments_director'),
    ('program_quote_promos','program_quote_promos_director'),
    ('program_quotes','program_quotes_director'),
    ('region_content_bookmarks','mvp_region_content_bookmarks_all'),
    ('review_replies','mvp_review_replies_insert'),
    ('review_replies','mvp_review_replies_select'),
    ('review_replies','mvp_review_replies_update'),
    ('review_request_events','review_request_events_shop_select'),
    ('seminar_applications','mvp_seminar_applications_insert'),
    ('seminar_applications','mvp_seminar_applications_select'),
    ('seminar_applications','mvp_seminar_applications_update'),
    ('seminar_classes','mvp_seminar_classes_insert'),
    ('seminar_classes','mvp_seminar_classes_select'),
    ('seminar_classes','mvp_seminar_classes_update'),
    ('seminar_enrollment_reviews','mvp_seminar_enrollment_reviews_all'),
    ('seminar_enrollments','mvp_seminar_enrollments_insert'),
    ('seminar_enrollments','mvp_seminar_enrollments_select'),
    ('seminar_enrollments','mvp_seminar_enrollments_update'),
    ('seminar_feedback_reports','mvp_seminar_feedback_reports_all'),
    ('seminar_requests','mvp_seminar_requests_insert'),
    ('seminar_requests','mvp_seminar_requests_select'),
    ('seminar_requests','mvp_seminar_requests_update'),
    ('settlement_transactions','mvp_settlement_transactions_all'),
    ('shop_clinical_trend_snapshots','shop_clinical_trend_snapshots_read'),
    ('shop_clinical_trend_snapshots','shop_clinical_trend_snapshots_write'),
    ('shop_daily_context','shop_daily_context_shop_read'),
    ('shop_daily_context','shop_daily_context_shop_write'),
    ('shop_entitlements','mvp_shop_entitlements_all'),
    ('shop_followers','mvp_shop_followers_delete'),
    ('shop_followers','mvp_shop_followers_insert'),
    ('shop_followers','mvp_shop_followers_select'),
    ('shop_gallery_items','mvp_shop_gallery_delete'),
    ('shop_gallery_items','mvp_shop_gallery_insert'),
    ('shop_gallery_items','mvp_shop_gallery_select'),
    ('shop_gallery_items','mvp_shop_gallery_update'),
    ('shop_highlights','mvp_shop_highlights_delete'),
    ('shop_highlights','mvp_shop_highlights_insert'),
    ('shop_highlights','mvp_shop_highlights_select'),
    ('shop_highlights','mvp_shop_highlights_update'),
    ('shop_hourly_climate','shop_hourly_climate_shop_read'),
    ('shop_hourly_climate','shop_hourly_climate_shop_write'),
    ('shop_memberships','shop_memberships_owner_write'),
    ('shop_memberships','shop_memberships_select_public'),
    ('shop_menus','shop_menus_select_public'),
    ('shop_menus','shop_menus_write_owner'),
    ('shop_notifications','mvp_shop_notifications_all'),
    ('shop_posts','mvp_shop_posts_delete'),
    ('shop_posts','mvp_shop_posts_insert'),
    ('shop_posts','mvp_shop_posts_select'),
    ('shop_posts','mvp_shop_posts_update'),
    ('shop_promo_credits','mvp_shop_promo_credits_all'),
    ('shop_verifications','mvp_shop_verifications_select'),
    ('shop_verifications','mvp_shop_verifications_write'),
    ('shops','mvp_shops_insert'),
    ('shops','mvp_shops_select'),
    ('shops','mvp_shops_update'),
    ('sos_keyword_rules','sos_keyword_rules_shop_read'),
    ('sos_keyword_rules','sos_keyword_rules_shop_write'),
    ('staff_roles','staff_roles_select_own'),
    ('subscriptions','subscriptions_delete_own'),
    ('subscriptions','subscriptions_insert_own'),
    ('subscriptions','subscriptions_select_own'),
    ('tier_upgrade_rewards_log','mvp_tier_upgrade_rewards_log_all'),
    ('visit_operation_events','visit_operation_events_shop_rw'),
    ('visit_operation_timers','visit_operation_timers_shop_rw'),
    ('visit_sessions','visit_sessions_shop_read'),
    ('visit_sessions','visit_sessions_shop_write'),
    ('wallets','mvp_wallets_all'),
    ('whisper_audience_presets','whisper_presets_owner_all'),
    ('whisper_recipients','whisper_recipients_select_own'),
    ('whispers','whispers_select_participant')) loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;


-- ===== public.affiliate_clicks =====
drop policy if exists mvp_affiliate_clicks_all on public.affiliate_clicks;
create policy mvp_affiliate_clicks_all on public.affiliate_clicks as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.affiliate_commissions =====
drop policy if exists mvp_affiliate_commissions_all on public.affiliate_commissions;
create policy mvp_affiliate_commissions_all on public.affiliate_commissions as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.affiliate_conversions =====
drop policy if exists mvp_affiliate_conversions_all on public.affiliate_conversions;
create policy mvp_affiliate_conversions_all on public.affiliate_conversions as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.affiliate_links =====
drop policy if exists mvp_affiliate_links_all on public.affiliate_links;
create policy mvp_affiliate_links_all on public.affiliate_links as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.ai_replies =====
drop policy if exists mvp_ai_replies_insert on public.ai_replies;
create policy mvp_ai_replies_insert on public.ai_replies as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_ai_replies_select on public.ai_replies;
create policy mvp_ai_replies_select on public.ai_replies as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_ai_replies_update on public.ai_replies;
create policy mvp_ai_replies_update on public.ai_replies as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.ai_tool_jobs =====
drop policy if exists mvp_ai_tool_jobs_all on public.ai_tool_jobs;
create policy mvp_ai_tool_jobs_all on public.ai_tool_jobs as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.ai_tool_quota =====
drop policy if exists mvp_ai_tool_quota_all on public.ai_tool_quota;
create policy mvp_ai_tool_quota_all on public.ai_tool_quota as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.b2b_partners =====
drop policy if exists mvp_b2b_partners_select on public.b2b_partners;
create policy mvp_b2b_partners_select on public.b2b_partners as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_b2b_partners_write on public.b2b_partners;
create policy mvp_b2b_partners_write on public.b2b_partners as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.ba_capture_sessions =====
drop policy if exists ba_sessions_shop_read on public.ba_capture_sessions;
create policy ba_sessions_shop_read on public.ba_capture_sessions as PERMISSIVE for SELECT to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE (sm.user_id = auth.uid()))));
drop policy if exists ba_sessions_shop_write on public.ba_capture_sessions;
create policy ba_sessions_shop_write on public.ba_capture_sessions as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.boost_placements =====
drop policy if exists mvp_boost_placements_all on public.boost_placements;
create policy mvp_boost_placements_all on public.boost_placements as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.boost_premium_overlays =====
drop policy if exists mvp_boost_premium_overlays_all on public.boost_premium_overlays;
create policy mvp_boost_premium_overlays_all on public.boost_premium_overlays as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.care_program_templates =====
drop policy if exists care_program_templates_shop_rw on public.care_program_templates;
create policy care_program_templates_shop_rw on public.care_program_templates as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.care_schedule_entries =====
drop policy if exists care_schedule_lead_insert on public.care_schedule_entries;
create policy care_schedule_lead_insert on public.care_schedule_entries as PERMISSIVE for INSERT to PUBLIC
  with check ((source = 'customerLead'::text));
drop policy if exists care_schedule_shop_read on public.care_schedule_entries;
create policy care_schedule_shop_read on public.care_schedule_entries as PERMISSIVE for SELECT to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE (sm.user_id = auth.uid()))));
drop policy if exists care_schedule_shop_write on public.care_schedule_entries;
create policy care_schedule_shop_write on public.care_schedule_entries as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.case_bookmarks =====
drop policy if exists mvp_case_bookmarks_all on public.case_bookmarks;
create policy mvp_case_bookmarks_all on public.case_bookmarks as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.chart_likes =====
drop policy if exists mvp_chart_likes_all on public.chart_likes;
create policy mvp_chart_likes_all on public.chart_likes as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.chart_photo_records =====
drop policy if exists mvp_chart_photo_records_insert on public.chart_photo_records;
create policy mvp_chart_photo_records_insert on public.chart_photo_records as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_chart_photo_records_select on public.chart_photo_records;
create policy mvp_chart_photo_records_select on public.chart_photo_records as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_chart_photo_records_update on public.chart_photo_records;
create policy mvp_chart_photo_records_update on public.chart_photo_records as PERMISSIVE for UPDATE to PUBLIC
  using (true)
  with check (true);

-- ===== public.chart_records =====
drop policy if exists "Customer can view consented family charts" on public.chart_records;
create policy "Customer can view consented family charts" on public.chart_records as PERMISSIVE for SELECT to PUBLIC
  using (((is_consent_signed = true) AND (guardian_phone = ((current_setting('request.jwt.claims'::text))::json ->> 'phone'::text))));
drop policy if exists "Director can manage own shop charts" on public.chart_records;
create policy "Director can manage own shop charts" on public.chart_records as PERMISSIVE for ALL to PUBLIC
  using ((auth.uid() = shop_id));
drop policy if exists "Users and consented family can view charts" on public.chart_records;
create policy "Users and consented family can view charts" on public.chart_records as PERMISSIVE for SELECT to PUBLIC
  using (((customer_phone = ((current_setting('request.jwt.claims'::text, true))::json ->> 'phone'::text)) OR ((is_consent_signed = true) AND (guardian_phone = ((current_setting('request.jwt.claims'::text, true))::json ->> 'phone'::text)))));

-- ===== public.chart_view_events =====
drop policy if exists mvp_chart_view_events_all on public.chart_view_events;
create policy mvp_chart_view_events_all on public.chart_view_events as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.clinical_environment_rules =====
drop policy if exists clinical_environment_rules_shop_read on public.clinical_environment_rules;
create policy clinical_environment_rules_shop_read on public.clinical_environment_rules as PERMISSIVE for SELECT to PUBLIC
  using (((shop_id IS NULL) OR (shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE (sm.user_id = auth.uid())))));
drop policy if exists clinical_environment_rules_shop_write on public.clinical_environment_rules;
create policy clinical_environment_rules_shop_write on public.clinical_environment_rules as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.clinical_trend_keywords =====
drop policy if exists clinical_trend_keywords_read on public.clinical_trend_keywords;
create policy clinical_trend_keywords_read on public.clinical_trend_keywords as PERMISSIVE for SELECT to PUBLIC
  using (((is_global = true) OR (shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE (sm.user_id = auth.uid())))));

-- ===== public.clinical_trend_scripts =====
drop policy if exists clinical_trend_scripts_read on public.clinical_trend_scripts;
create policy clinical_trend_scripts_read on public.clinical_trend_scripts as PERMISSIVE for SELECT to PUBLIC
  using (true);

-- ===== public.community_comments =====
drop policy if exists mvp_community_comments_all on public.community_comments;
create policy mvp_community_comments_all on public.community_comments as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.community_posts =====
drop policy if exists community_posts_select_visible on public.community_posts;
create policy community_posts_select_visible on public.community_posts as PERMISSIVE for SELECT to PUBLIC
  using (can_view_community_post_full(visibility, shop_id, author_user_id, id));
drop policy if exists mvp_community_posts_delete on public.community_posts;
create policy mvp_community_posts_delete on public.community_posts as PERMISSIVE for DELETE to PUBLIC
  using (true);
drop policy if exists mvp_community_posts_insert on public.community_posts;
create policy mvp_community_posts_insert on public.community_posts as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_community_posts_update on public.community_posts;
create policy mvp_community_posts_update on public.community_posts as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.community_whisper_recipients =====
drop policy if exists community_whisper_recipients_select on public.community_whisper_recipients;
create policy community_whisper_recipients_select on public.community_whisper_recipients as PERMISSIVE for SELECT to PUBLIC
  using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM community_posts p
  WHERE ((p.id = community_whisper_recipients.post_id) AND (p.author_user_id = auth.uid()))))));

-- ===== public.customer_charts =====
drop policy if exists mvp_charts_insert on public.customer_charts;
create policy mvp_charts_insert on public.customer_charts as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_charts_select on public.customer_charts;
create policy mvp_charts_select on public.customer_charts as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_charts_update on public.customer_charts;
create policy mvp_charts_update on public.customer_charts as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.customer_diaries =====
drop policy if exists "Customer can manage own diaries" on public.customer_diaries;
create policy "Customer can manage own diaries" on public.customer_diaries as PERMISSIVE for ALL to PUBLIC
  using ((user_phone = ((current_setting('request.jwt.claims'::text))::json ->> 'phone'::text)));
drop policy if exists "Users can manage their own diaries" on public.customer_diaries;
create policy "Users can manage their own diaries" on public.customer_diaries as PERMISSIVE for ALL to PUBLIC
  using ((user_phone = ((current_setting('request.jwt.claims'::text, true))::json ->> 'phone'::text)));

-- ===== public.customer_merge_events =====
drop policy if exists mvp_customer_merge_events_select on public.customer_merge_events;
create policy mvp_customer_merge_events_select on public.customer_merge_events as PERMISSIVE for SELECT to PUBLIC
  using (true);

-- ===== public.customer_reviews =====
drop policy if exists mvp_reviews_insert on public.customer_reviews;
create policy mvp_reviews_insert on public.customer_reviews as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_reviews_select on public.customer_reviews;
create policy mvp_reviews_select on public.customer_reviews as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_reviews_update on public.customer_reviews;
create policy mvp_reviews_update on public.customer_reviews as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.customers =====
drop policy if exists mvp_customers_insert on public.customers;
create policy mvp_customers_insert on public.customers as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_customers_select on public.customers;
create policy mvp_customers_select on public.customers as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_customers_update on public.customers;
create policy mvp_customers_update on public.customers as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.device_reviews =====
drop policy if exists mvp_device_reviews_all on public.device_reviews;
create policy mvp_device_reviews_all on public.device_reviews as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.echo_earn_quota =====
drop policy if exists mvp_echo_earn_quota_all on public.echo_earn_quota;
create policy mvp_echo_earn_quota_all on public.echo_earn_quota as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.echo_earn_quota_customer =====
drop policy if exists mvp_echo_earn_quota_customer_all on public.echo_earn_quota_customer;
create policy mvp_echo_earn_quota_customer_all on public.echo_earn_quota_customer as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.fan_gifts =====
drop policy if exists mvp_fan_gifts_all on public.fan_gifts;
create policy mvp_fan_gifts_all on public.fan_gifts as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.listing_inquiries =====
drop policy if exists mvp_listing_inquiries_all on public.listing_inquiries;
create policy mvp_listing_inquiries_all on public.listing_inquiries as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.market_escrow_holds =====
drop policy if exists mvp_market_escrow_holds_all on public.market_escrow_holds;
create policy mvp_market_escrow_holds_all on public.market_escrow_holds as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.market_listings =====
drop policy if exists mvp_market_listings_all on public.market_listings;
create policy mvp_market_listings_all on public.market_listings as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.market_strategy_states =====
drop policy if exists market_strategy_states_owner on public.market_strategy_states;
create policy market_strategy_states_owner on public.market_strategy_states as PERMISSIVE for ALL to PUBLIC
  using (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM shops s
  WHERE ((s.id = market_strategy_states.shop_id) AND (s.owner_user_id = auth.uid()))))))
  with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM shops s
  WHERE ((s.id = market_strategy_states.shop_id) AND (s.owner_user_id = auth.uid()))))));

-- ===== public.membership_tickets =====
drop policy if exists "Users can view their own membership tickets" on public.membership_tickets;
create policy "Users can view their own membership tickets" on public.membership_tickets as PERMISSIVE for SELECT to PUBLIC
  using ((user_phone = ((current_setting('request.jwt.claims'::text, true))::json ->> 'phone'::text)));
drop policy if exists mvp_membership_tickets_delete on public.membership_tickets;
create policy mvp_membership_tickets_delete on public.membership_tickets as PERMISSIVE for DELETE to PUBLIC
  using (true);
drop policy if exists mvp_membership_tickets_insert on public.membership_tickets;
create policy mvp_membership_tickets_insert on public.membership_tickets as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_membership_tickets_select on public.membership_tickets;
create policy mvp_membership_tickets_select on public.membership_tickets as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_membership_tickets_update on public.membership_tickets;
create policy mvp_membership_tickets_update on public.membership_tickets as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.mentoring_feedback =====
drop policy if exists mvp_mentoring_feedback_all on public.mentoring_feedback;
create policy mvp_mentoring_feedback_all on public.mentoring_feedback as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.mentoring_posts =====
drop policy if exists mvp_mentoring_posts_all on public.mentoring_posts;
create policy mvp_mentoring_posts_all on public.mentoring_posts as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.mentoring_purchases =====
drop policy if exists mvp_mentoring_purchases_all on public.mentoring_purchases;
create policy mvp_mentoring_purchases_all on public.mentoring_purchases as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.mentoring_requests =====
drop policy if exists mvp_mentoring_requests_all on public.mentoring_requests;
create policy mvp_mentoring_requests_all on public.mentoring_requests as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.photo_sets =====
drop policy if exists mvp_photo_sets_insert on public.photo_sets;
create policy mvp_photo_sets_insert on public.photo_sets as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_photo_sets_select on public.photo_sets;
create policy mvp_photo_sets_select on public.photo_sets as PERMISSIVE for SELECT to PUBLIC
  using (true);

-- ===== public.point_shop_items =====
drop policy if exists mvp_point_shop_items_all on public.point_shop_items;
create policy mvp_point_shop_items_all on public.point_shop_items as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.point_transactions =====
drop policy if exists mvp_point_transactions_all on public.point_transactions;
create policy mvp_point_transactions_all on public.point_transactions as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.post_media =====
drop policy if exists post_media_select_unlocked on public.post_media;
create policy post_media_select_unlocked on public.post_media as PERMISSIVE for SELECT to PUBLIC
  using ((EXISTS ( SELECT 1
   FROM community_posts p
  WHERE ((p.id = post_media.post_id) AND can_view_community_post_full(p.visibility, p.shop_id, p.author_user_id, p.id)))));
drop policy if exists post_media_write_mvp on public.post_media;
create policy post_media_write_mvp on public.post_media as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.post_tags =====
drop policy if exists mvp_post_tags_all on public.post_tags;
create policy mvp_post_tags_all on public.post_tags as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.post_unlocks =====
drop policy if exists mvp_post_unlocks_all on public.post_unlocks;
create policy mvp_post_unlocks_all on public.post_unlocks as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.profiles =====
drop policy if exists mvp_profiles_select on public.profiles;
create policy mvp_profiles_select on public.profiles as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles as PERMISSIVE for INSERT to PUBLIC
  with check ((auth.uid() = id));

-- ===== public.program_categories =====
drop policy if exists program_categories_director on public.program_categories;
create policy program_categories_director on public.program_categories as PERMISSIVE for ALL to PUBLIC
  using (program_shop_is_director(shop_id))
  with check (program_shop_is_director(shop_id));

-- ===== public.program_customer_coupons =====
drop policy if exists program_customer_coupons_director on public.program_customer_coupons;
create policy program_customer_coupons_director on public.program_customer_coupons as PERMISSIVE for ALL to PUBLIC
  using (program_shop_is_director(shop_id))
  with check (program_shop_is_director(shop_id));

-- ===== public.program_memberships =====
drop policy if exists program_memberships_director on public.program_memberships;
create policy program_memberships_director on public.program_memberships as PERMISSIVE for ALL to PUBLIC
  using (program_shop_is_director(shop_id))
  with check (program_shop_is_director(shop_id));

-- ===== public.program_package_lines =====
drop policy if exists program_package_lines_director on public.program_package_lines;
create policy program_package_lines_director on public.program_package_lines as PERMISSIVE for ALL to PUBLIC
  using ((EXISTS ( SELECT 1
   FROM program_packages p
  WHERE ((p.id = program_package_lines.package_id) AND program_shop_is_director(p.shop_id)))))
  with check ((EXISTS ( SELECT 1
   FROM program_packages p
  WHERE ((p.id = program_package_lines.package_id) AND program_shop_is_director(p.shop_id)))));

-- ===== public.program_packages =====
drop policy if exists program_packages_director on public.program_packages;
create policy program_packages_director on public.program_packages as PERMISSIVE for ALL to PUBLIC
  using (program_shop_is_director(shop_id))
  with check (program_shop_is_director(shop_id));

-- ===== public.program_promotions =====
drop policy if exists program_promotions_director on public.program_promotions;
create policy program_promotions_director on public.program_promotions as PERMISSIVE for ALL to PUBLIC
  using (program_shop_is_director(shop_id))
  with check (program_shop_is_director(shop_id));

-- ===== public.program_quote_payments =====
drop policy if exists program_quote_payments_director on public.program_quote_payments;
create policy program_quote_payments_director on public.program_quote_payments as PERMISSIVE for ALL to PUBLIC
  using ((EXISTS ( SELECT 1
   FROM program_quotes q
  WHERE ((q.id = program_quote_payments.quote_id) AND program_shop_is_director(q.shop_id)))))
  with check ((EXISTS ( SELECT 1
   FROM program_quotes q
  WHERE ((q.id = program_quote_payments.quote_id) AND program_shop_is_director(q.shop_id)))));

-- ===== public.program_quote_promos =====
drop policy if exists program_quote_promos_director on public.program_quote_promos;
create policy program_quote_promos_director on public.program_quote_promos as PERMISSIVE for ALL to PUBLIC
  using ((EXISTS ( SELECT 1
   FROM program_quotes q
  WHERE ((q.id = program_quote_promos.quote_id) AND program_shop_is_director(q.shop_id)))))
  with check ((EXISTS ( SELECT 1
   FROM program_quotes q
  WHERE ((q.id = program_quote_promos.quote_id) AND program_shop_is_director(q.shop_id)))));

-- ===== public.program_quotes =====
drop policy if exists program_quotes_director on public.program_quotes;
create policy program_quotes_director on public.program_quotes as PERMISSIVE for ALL to PUBLIC
  using (program_shop_is_director(shop_id))
  with check (program_shop_is_director(shop_id));

-- ===== public.region_content_bookmarks =====
drop policy if exists mvp_region_content_bookmarks_all on public.region_content_bookmarks;
create policy mvp_region_content_bookmarks_all on public.region_content_bookmarks as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.review_replies =====
drop policy if exists mvp_review_replies_insert on public.review_replies;
create policy mvp_review_replies_insert on public.review_replies as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_review_replies_select on public.review_replies;
create policy mvp_review_replies_select on public.review_replies as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_review_replies_update on public.review_replies;
create policy mvp_review_replies_update on public.review_replies as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.review_request_events =====
drop policy if exists review_request_events_shop_select on public.review_request_events;
create policy review_request_events_shop_select on public.review_request_events as PERMISSIVE for SELECT to PUBLIC
  using ((EXISTS ( SELECT 1
   FROM shops s
  WHERE ((s.id = review_request_events.shop_id) AND ((s.owner_user_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM shop_memberships m
          WHERE ((m.shop_id = s.id) AND (m.user_id = auth.uid())))))))));

-- ===== public.seminar_applications =====
drop policy if exists mvp_seminar_applications_insert on public.seminar_applications;
create policy mvp_seminar_applications_insert on public.seminar_applications as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_seminar_applications_select on public.seminar_applications;
create policy mvp_seminar_applications_select on public.seminar_applications as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_seminar_applications_update on public.seminar_applications;
create policy mvp_seminar_applications_update on public.seminar_applications as PERMISSIVE for UPDATE to PUBLIC
  using (true)
  with check (true);

-- ===== public.seminar_classes =====
drop policy if exists mvp_seminar_classes_insert on public.seminar_classes;
create policy mvp_seminar_classes_insert on public.seminar_classes as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_seminar_classes_select on public.seminar_classes;
create policy mvp_seminar_classes_select on public.seminar_classes as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_seminar_classes_update on public.seminar_classes;
create policy mvp_seminar_classes_update on public.seminar_classes as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.seminar_enrollment_reviews =====
drop policy if exists mvp_seminar_enrollment_reviews_all on public.seminar_enrollment_reviews;
create policy mvp_seminar_enrollment_reviews_all on public.seminar_enrollment_reviews as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.seminar_enrollments =====
drop policy if exists mvp_seminar_enrollments_insert on public.seminar_enrollments;
create policy mvp_seminar_enrollments_insert on public.seminar_enrollments as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_seminar_enrollments_select on public.seminar_enrollments;
create policy mvp_seminar_enrollments_select on public.seminar_enrollments as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_seminar_enrollments_update on public.seminar_enrollments;
create policy mvp_seminar_enrollments_update on public.seminar_enrollments as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.seminar_feedback_reports =====
drop policy if exists mvp_seminar_feedback_reports_all on public.seminar_feedback_reports;
create policy mvp_seminar_feedback_reports_all on public.seminar_feedback_reports as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.seminar_requests =====
drop policy if exists mvp_seminar_requests_insert on public.seminar_requests;
create policy mvp_seminar_requests_insert on public.seminar_requests as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_seminar_requests_select on public.seminar_requests;
create policy mvp_seminar_requests_select on public.seminar_requests as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_seminar_requests_update on public.seminar_requests;
create policy mvp_seminar_requests_update on public.seminar_requests as PERMISSIVE for UPDATE to PUBLIC
  using (true)
  with check (true);

-- ===== public.settlement_transactions =====
drop policy if exists mvp_settlement_transactions_all on public.settlement_transactions;
create policy mvp_settlement_transactions_all on public.settlement_transactions as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.shop_clinical_trend_snapshots =====
drop policy if exists shop_clinical_trend_snapshots_read on public.shop_clinical_trend_snapshots;
create policy shop_clinical_trend_snapshots_read on public.shop_clinical_trend_snapshots as PERMISSIVE for SELECT to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE (sm.user_id = auth.uid()))));
drop policy if exists shop_clinical_trend_snapshots_write on public.shop_clinical_trend_snapshots;
create policy shop_clinical_trend_snapshots_write on public.shop_clinical_trend_snapshots as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.shop_daily_context =====
drop policy if exists shop_daily_context_shop_read on public.shop_daily_context;
create policy shop_daily_context_shop_read on public.shop_daily_context as PERMISSIVE for SELECT to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE (sm.user_id = auth.uid()))));
drop policy if exists shop_daily_context_shop_write on public.shop_daily_context;
create policy shop_daily_context_shop_write on public.shop_daily_context as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.shop_entitlements =====
drop policy if exists mvp_shop_entitlements_all on public.shop_entitlements;
create policy mvp_shop_entitlements_all on public.shop_entitlements as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.shop_followers =====
drop policy if exists mvp_shop_followers_delete on public.shop_followers;
create policy mvp_shop_followers_delete on public.shop_followers as PERMISSIVE for DELETE to PUBLIC
  using (true);
drop policy if exists mvp_shop_followers_insert on public.shop_followers;
create policy mvp_shop_followers_insert on public.shop_followers as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_shop_followers_select on public.shop_followers;
create policy mvp_shop_followers_select on public.shop_followers as PERMISSIVE for SELECT to PUBLIC
  using (true);

-- ===== public.shop_gallery_items =====
drop policy if exists mvp_shop_gallery_delete on public.shop_gallery_items;
create policy mvp_shop_gallery_delete on public.shop_gallery_items as PERMISSIVE for DELETE to PUBLIC
  using (true);
drop policy if exists mvp_shop_gallery_insert on public.shop_gallery_items;
create policy mvp_shop_gallery_insert on public.shop_gallery_items as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_shop_gallery_select on public.shop_gallery_items;
create policy mvp_shop_gallery_select on public.shop_gallery_items as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_shop_gallery_update on public.shop_gallery_items;
create policy mvp_shop_gallery_update on public.shop_gallery_items as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.shop_highlights =====
drop policy if exists mvp_shop_highlights_delete on public.shop_highlights;
create policy mvp_shop_highlights_delete on public.shop_highlights as PERMISSIVE for DELETE to PUBLIC
  using (true);
drop policy if exists mvp_shop_highlights_insert on public.shop_highlights;
create policy mvp_shop_highlights_insert on public.shop_highlights as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_shop_highlights_select on public.shop_highlights;
create policy mvp_shop_highlights_select on public.shop_highlights as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_shop_highlights_update on public.shop_highlights;
create policy mvp_shop_highlights_update on public.shop_highlights as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.shop_hourly_climate =====
drop policy if exists shop_hourly_climate_shop_read on public.shop_hourly_climate;
create policy shop_hourly_climate_shop_read on public.shop_hourly_climate as PERMISSIVE for SELECT to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE (sm.user_id = auth.uid()))));
drop policy if exists shop_hourly_climate_shop_write on public.shop_hourly_climate;
create policy shop_hourly_climate_shop_write on public.shop_hourly_climate as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.shop_memberships =====
drop policy if exists shop_memberships_owner_write on public.shop_memberships;
create policy shop_memberships_owner_write on public.shop_memberships as PERMISSIVE for ALL to PUBLIC
  using (((EXISTS ( SELECT 1
   FROM shops s
  WHERE ((s.id = shop_memberships.shop_id) AND (s.owner_user_id = auth.uid())))) OR (user_id = auth.uid())))
  with check (((EXISTS ( SELECT 1
   FROM shops s
  WHERE ((s.id = shop_memberships.shop_id) AND (s.owner_user_id = auth.uid())))) OR (user_id = auth.uid())));
drop policy if exists shop_memberships_select_public on public.shop_memberships;
create policy shop_memberships_select_public on public.shop_memberships as PERMISSIVE for SELECT to PUBLIC
  using (((is_public = true) OR (user_id = auth.uid())));

-- ===== public.shop_menus =====
drop policy if exists shop_menus_select_public on public.shop_menus;
create policy shop_menus_select_public on public.shop_menus as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists shop_menus_write_owner on public.shop_menus;
create policy shop_menus_write_owner on public.shop_menus as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT shops.id
   FROM shops
  WHERE (shops.owner_user_id = auth.uid()))))
  with check ((shop_id IN ( SELECT shops.id
   FROM shops
  WHERE (shops.owner_user_id = auth.uid()))));

-- ===== public.shop_notifications =====
drop policy if exists mvp_shop_notifications_all on public.shop_notifications;
create policy mvp_shop_notifications_all on public.shop_notifications as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.shop_posts =====
drop policy if exists mvp_shop_posts_delete on public.shop_posts;
create policy mvp_shop_posts_delete on public.shop_posts as PERMISSIVE for DELETE to PUBLIC
  using (true);
drop policy if exists mvp_shop_posts_insert on public.shop_posts;
create policy mvp_shop_posts_insert on public.shop_posts as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_shop_posts_select on public.shop_posts;
create policy mvp_shop_posts_select on public.shop_posts as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_shop_posts_update on public.shop_posts;
create policy mvp_shop_posts_update on public.shop_posts as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.shop_promo_credits =====
drop policy if exists mvp_shop_promo_credits_all on public.shop_promo_credits;
create policy mvp_shop_promo_credits_all on public.shop_promo_credits as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.shop_verifications =====
drop policy if exists mvp_shop_verifications_select on public.shop_verifications;
create policy mvp_shop_verifications_select on public.shop_verifications as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_shop_verifications_write on public.shop_verifications;
create policy mvp_shop_verifications_write on public.shop_verifications as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.shops =====
drop policy if exists mvp_shops_insert on public.shops;
create policy mvp_shops_insert on public.shops as PERMISSIVE for INSERT to PUBLIC
  with check (true);
drop policy if exists mvp_shops_select on public.shops;
create policy mvp_shops_select on public.shops as PERMISSIVE for SELECT to PUBLIC
  using (true);
drop policy if exists mvp_shops_update on public.shops;
create policy mvp_shops_update on public.shops as PERMISSIVE for UPDATE to PUBLIC
  using (true);

-- ===== public.sos_keyword_rules =====
drop policy if exists sos_keyword_rules_shop_read on public.sos_keyword_rules;
create policy sos_keyword_rules_shop_read on public.sos_keyword_rules as PERMISSIVE for SELECT to PUBLIC
  using (((shop_id IS NULL) OR (shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE (sm.user_id = auth.uid())))));
drop policy if exists sos_keyword_rules_shop_write on public.sos_keyword_rules;
create policy sos_keyword_rules_shop_write on public.sos_keyword_rules as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.staff_roles =====
drop policy if exists staff_roles_select_own on public.staff_roles;
create policy staff_roles_select_own on public.staff_roles as PERMISSIVE for SELECT to authenticated
  using ((user_id = auth.uid()));

-- ===== public.subscriptions =====
drop policy if exists subscriptions_delete_own on public.subscriptions;
create policy subscriptions_delete_own on public.subscriptions as PERMISSIVE for DELETE to PUBLIC
  using ((follower_user_id = auth.uid()));
drop policy if exists subscriptions_insert_own on public.subscriptions;
create policy subscriptions_insert_own on public.subscriptions as PERMISSIVE for INSERT to PUBLIC
  with check ((follower_user_id = auth.uid()));
drop policy if exists subscriptions_select_own on public.subscriptions;
create policy subscriptions_select_own on public.subscriptions as PERMISSIVE for SELECT to PUBLIC
  using (((follower_user_id = auth.uid()) OR (target_user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM shops s
  WHERE ((s.id = subscriptions.target_shop_id) AND (s.owner_user_id = auth.uid()))))));

-- ===== public.tier_upgrade_rewards_log =====
drop policy if exists mvp_tier_upgrade_rewards_log_all on public.tier_upgrade_rewards_log;
create policy mvp_tier_upgrade_rewards_log_all on public.tier_upgrade_rewards_log as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.visit_operation_events =====
drop policy if exists visit_operation_events_shop_rw on public.visit_operation_events;
create policy visit_operation_events_shop_rw on public.visit_operation_events as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.visit_operation_timers =====
drop policy if exists visit_operation_timers_shop_rw on public.visit_operation_timers;
create policy visit_operation_timers_shop_rw on public.visit_operation_timers as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.visit_sessions =====
drop policy if exists visit_sessions_shop_read on public.visit_sessions;
create policy visit_sessions_shop_read on public.visit_sessions as PERMISSIVE for SELECT to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE (sm.user_id = auth.uid()))));
drop policy if exists visit_sessions_shop_write on public.visit_sessions;
create policy visit_sessions_shop_write on public.visit_sessions as PERMISSIVE for ALL to PUBLIC
  using ((shop_id IN ( SELECT sm.shop_id
   FROM shop_memberships sm
  WHERE ((sm.user_id = auth.uid()) AND (sm.role = ANY (ARRAY['owner'::text, 'director'::text]))))));

-- ===== public.wallets =====
drop policy if exists mvp_wallets_all on public.wallets;
create policy mvp_wallets_all on public.wallets as PERMISSIVE for ALL to PUBLIC
  using (true)
  with check (true);

-- ===== public.whisper_audience_presets =====
drop policy if exists whisper_presets_owner_all on public.whisper_audience_presets;
create policy whisper_presets_owner_all on public.whisper_audience_presets as PERMISSIVE for ALL to PUBLIC
  using ((owner_user_id = auth.uid()))
  with check ((owner_user_id = auth.uid()));

-- ===== public.whisper_recipients =====
drop policy if exists whisper_recipients_select_own on public.whisper_recipients;
create policy whisper_recipients_select_own on public.whisper_recipients as PERMISSIVE for SELECT to PUBLIC
  using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM whispers w
  WHERE ((w.id = whisper_recipients.whisper_id) AND (w.sender_user_id = auth.uid()))))));

-- ===== public.whispers =====
drop policy if exists whispers_select_participant on public.whispers;
create policy whispers_select_participant on public.whispers as PERMISSIVE for SELECT to PUBLIC
  using (((status = 'sent'::text) AND ((sender_user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM whisper_recipients r
  WHERE ((r.whisper_id = r.id) AND (r.user_id = auth.uid())))))));

commit;
