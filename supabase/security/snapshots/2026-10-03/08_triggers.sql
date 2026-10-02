-- SORI security snapshot: non-internal triggers in public (27) - reference / restore
-- project: tieojdbzmqcmlwyqltrk / captured at 2026-10-02 22:30:45.429761+00 (UTC) = 2026-10-03 KST
-- server: PostgreSQL 17.6 on aarch64-unknown-linux-gnu, compiled by gcc (GCC) 15.2.0, 64-bit
-- Generated read-only from catalog queries (pg_policies, pg_class.relacl, pg_proc, pg_views, storage.buckets).
-- See README.md in this folder before running anything.

-- Section A drops triggers that did not exist at snapshot time on these tables (e.g. added by P0 M1).
-- Section B re-creates every snapshot trigger. All were enabled (tgenabled = 'O').
begin;

do $$
declare t record;
begin
  for t in select c.relname, tr.tgname from pg_trigger tr join pg_class c on c.oid = tr.tgrelid
            join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and not tr.tgisinternal
             and (c.relname::text, tr.tgname::text) not in (values
    ('affiliate_commissions','trg_affiliate_paid_to_settlement'),
    ('affiliate_conversions','trg_affiliate_conversion_settle'),
    ('ba_capture_sessions','trg_ba_capture_sessions_touch'),
    ('chart_likes','trg_chart_likes_tier'),
    ('community_comments','trg_bump_community_comment_count'),
    ('community_comments','trg_earn_points_community_comments'),
    ('community_posts','trg_bump_activity_community_posts'),
    ('community_posts','trg_earn_echo_customer_qa'),
    ('community_posts','trg_earn_points_community_posts'),
    ('customer_charts','trg_customer_charts_tier_badge'),
    ('customer_charts','trg_earn_echo_visit_checked'),
    ('customer_reviews','trg_earn_echo_customer_review'),
    ('device_reviews','trg_bump_activity_device_reviews'),
    ('market_listings','trg_market_listing_trust'),
    ('mentoring_feedback','trg_mentoring_feedback_counts'),
    ('mentoring_feedback','trg_mentoring_feedback_quality'),
    ('mentoring_posts','trg_mentoring_posts_body_updated'),
    ('program_quote_payments','program_quote_payments_sync'),
    ('seminar_classes','trg_seminar_class_completed_funding'),
    ('seminar_classes','trg_seminar_classes_tier'),
    ('seminar_requests','trg_seminar_requests_tier'),
    ('shop_followers','trg_shop_followers_tier'),
    ('shop_gallery_items','trg_shop_gallery_limit'),
    ('shop_posts','trg_bump_activity_shop_posts'),
    ('shops','trg_sync_shop_menus'),
    ('shops','trg_sync_shop_owner_membership'),
    ('subscriptions','trg_sync_subscription_shop_followers')) loop
    execute format('drop trigger %I on public.%I', t.tgname, t.relname);
  end loop;
end $$;

drop trigger if exists trg_affiliate_paid_to_settlement on public.affiliate_commissions;
CREATE TRIGGER trg_affiliate_paid_to_settlement AFTER UPDATE OF status ON affiliate_commissions FOR EACH ROW EXECUTE FUNCTION sync_affiliate_paid_to_settlement();
drop trigger if exists trg_affiliate_conversion_settle on public.affiliate_conversions;
CREATE TRIGGER trg_affiliate_conversion_settle BEFORE INSERT OR UPDATE OF status, commission_amount, note ON affiliate_conversions FOR EACH ROW EXECUTE FUNCTION sync_affiliate_conversion_commission();
drop trigger if exists trg_ba_capture_sessions_touch on public.ba_capture_sessions;
CREATE TRIGGER trg_ba_capture_sessions_touch BEFORE UPDATE ON ba_capture_sessions FOR EACH ROW EXECUTE FUNCTION touch_ba_capture_session();
drop trigger if exists trg_chart_likes_tier on public.chart_likes;
CREATE TRIGGER trg_chart_likes_tier AFTER INSERT OR DELETE ON chart_likes FOR EACH ROW EXECUTE FUNCTION trg_shop_tier_refresh();
drop trigger if exists trg_bump_community_comment_count on public.community_comments;
CREATE TRIGGER trg_bump_community_comment_count AFTER INSERT OR DELETE ON community_comments FOR EACH ROW EXECUTE FUNCTION bump_community_post_comment_count();
drop trigger if exists trg_earn_points_community_comments on public.community_comments;
CREATE TRIGGER trg_earn_points_community_comments AFTER INSERT ON community_comments FOR EACH ROW EXECUTE FUNCTION earn_points_on_community_content();
drop trigger if exists trg_bump_activity_community_posts on public.community_posts;
CREATE TRIGGER trg_bump_activity_community_posts AFTER INSERT ON community_posts FOR EACH ROW EXECUTE FUNCTION bump_shop_community_activity();
drop trigger if exists trg_earn_echo_customer_qa on public.community_posts;
CREATE TRIGGER trg_earn_echo_customer_qa AFTER INSERT ON community_posts FOR EACH ROW EXECUTE FUNCTION earn_echo_on_customer_qa_post();
drop trigger if exists trg_earn_points_community_posts on public.community_posts;
CREATE TRIGGER trg_earn_points_community_posts AFTER INSERT ON community_posts FOR EACH ROW EXECUTE FUNCTION earn_points_on_community_content();
drop trigger if exists trg_customer_charts_tier_badge on public.customer_charts;
CREATE TRIGGER trg_customer_charts_tier_badge AFTER INSERT OR DELETE OR UPDATE OF is_case_shared, shop_id, signature_url, consent_pdf_url ON customer_charts FOR EACH ROW EXECUTE FUNCTION trg_shop_tier_refresh();
drop trigger if exists trg_earn_echo_visit_checked on public.customer_charts;
CREATE TRIGGER trg_earn_echo_visit_checked AFTER INSERT OR UPDATE OF visit_checked ON customer_charts FOR EACH ROW EXECUTE FUNCTION earn_echo_on_visit_checked();
drop trigger if exists trg_earn_echo_customer_review on public.customer_reviews;
CREATE TRIGGER trg_earn_echo_customer_review AFTER INSERT OR UPDATE OF status ON customer_reviews FOR EACH ROW EXECUTE FUNCTION earn_echo_on_customer_review();
drop trigger if exists trg_bump_activity_device_reviews on public.device_reviews;
CREATE TRIGGER trg_bump_activity_device_reviews AFTER INSERT ON device_reviews FOR EACH ROW EXECUTE FUNCTION bump_shop_community_activity();
drop trigger if exists trg_market_listing_trust on public.market_listings;
CREATE TRIGGER trg_market_listing_trust AFTER INSERT ON market_listings FOR EACH ROW EXECUTE FUNCTION trg_market_listing_trust_refresh();
drop trigger if exists trg_mentoring_feedback_counts on public.mentoring_feedback;
CREATE TRIGGER trg_mentoring_feedback_counts AFTER INSERT OR DELETE OR UPDATE ON mentoring_feedback FOR EACH ROW EXECUTE FUNCTION trg_mentoring_feedback_counts();
drop trigger if exists trg_mentoring_feedback_quality on public.mentoring_feedback;
CREATE TRIGGER trg_mentoring_feedback_quality AFTER INSERT OR UPDATE ON mentoring_feedback FOR EACH ROW EXECUTE FUNCTION trg_mentoring_feedback_quality();
drop trigger if exists trg_mentoring_posts_body_updated on public.mentoring_posts;
CREATE TRIGGER trg_mentoring_posts_body_updated BEFORE UPDATE ON mentoring_posts FOR EACH ROW EXECUTE FUNCTION trg_mentoring_body_updated();
drop trigger if exists program_quote_payments_sync on public.program_quote_payments;
CREATE TRIGGER program_quote_payments_sync AFTER INSERT OR DELETE OR UPDATE ON program_quote_payments FOR EACH ROW EXECUTE FUNCTION program_sync_quote_paid();
drop trigger if exists trg_seminar_class_completed_funding on public.seminar_classes;
CREATE TRIGGER trg_seminar_class_completed_funding AFTER INSERT OR UPDATE OF status, current_enrollment, price ON seminar_classes FOR EACH ROW EXECUTE FUNCTION trg_seminar_class_completed_funding();
drop trigger if exists trg_seminar_classes_tier on public.seminar_classes;
CREATE TRIGGER trg_seminar_classes_tier AFTER INSERT OR DELETE OR UPDATE OF status, current_enrollment, price, director_shop_id ON seminar_classes FOR EACH ROW EXECUTE FUNCTION trg_shop_tier_refresh();
drop trigger if exists trg_seminar_requests_tier on public.seminar_requests;
CREATE TRIGGER trg_seminar_requests_tier AFTER INSERT OR DELETE ON seminar_requests FOR EACH ROW EXECUTE FUNCTION trg_shop_tier_refresh();
drop trigger if exists trg_shop_followers_tier on public.shop_followers;
CREATE TRIGGER trg_shop_followers_tier AFTER INSERT OR DELETE ON shop_followers FOR EACH ROW EXECUTE FUNCTION trg_shop_tier_refresh();
drop trigger if exists trg_shop_gallery_limit on public.shop_gallery_items;
CREATE TRIGGER trg_shop_gallery_limit BEFORE INSERT ON shop_gallery_items FOR EACH ROW EXECUTE FUNCTION enforce_shop_gallery_limit();
drop trigger if exists trg_bump_activity_shop_posts on public.shop_posts;
CREATE TRIGGER trg_bump_activity_shop_posts AFTER INSERT ON shop_posts FOR EACH ROW EXECUTE FUNCTION bump_shop_community_activity();
drop trigger if exists trg_sync_shop_menus on public.shops;
CREATE TRIGGER trg_sync_shop_menus AFTER INSERT OR UPDATE OF service_menu ON shops FOR EACH ROW EXECUTE FUNCTION sync_shop_menus_from_jsonb();
drop trigger if exists trg_sync_shop_owner_membership on public.shops;
CREATE TRIGGER trg_sync_shop_owner_membership AFTER INSERT OR UPDATE OF owner_user_id ON shops FOR EACH ROW EXECUTE FUNCTION sync_shop_owner_membership();
drop trigger if exists trg_sync_subscription_shop_followers on public.subscriptions;
CREATE TRIGGER trg_sync_subscription_shop_followers AFTER INSERT OR DELETE ON subscriptions FOR EACH ROW EXECUTE FUNCTION sync_subscription_to_shop_followers();

commit;
