-- SORI security snapshot: view definitions (4)
-- project: tieojdbzmqcmlwyqltrk / captured at 2026-10-02 22:30:45.429761+00 (UTC) = 2026-10-03 KST
-- server: PostgreSQL 17.6 on aarch64-unknown-linux-gnu, compiled by gcc (GCC) 15.2.0, 64-bit
-- Generated read-only from catalog queries (pg_policies, pg_class.relacl, pg_proc, pg_views, storage.buckets).
-- See README.md in this folder before running anything.

-- security_invoker is restored from pg_class.reloptions (absent = SECURITY DEFINER-style view owned by postgres).
begin;

-- view public.community_shared_cases reloptions=['security_invoker=true']
create or replace view public.community_shared_cases with (security_invoker=true) as
 SELECT c.id AS chart_id,
    c.shop_id,
    c.visit_number,
    c.care_name,
    c.treatment_summary,
    c.concern_chips,
        CASE
            WHEN c.care_tags IS NOT NULL AND jsonb_typeof(c.care_tags) = 'array'::text AND jsonb_array_length(c.care_tags) > 0 THEN c.care_tags
            ELSE COALESCE(c.concern_chips, '[]'::jsonb)
        END AS care_tags,
    c.before_image_url,
    c.after_image_url,
    c.is_case_shared,
    c.created_at,
    c.device_info,
    COALESCE(c.skin_sensitivity, ''::text) AS skin_sensitivity,
        CASE
            WHEN NULLIF(TRIM(BOTH FROM cu.birth_date), ''::text) IS NULL THEN NULL::integer
            WHEN NULLIF(TRIM(BOTH FROM cu.birth_date), ''::text) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'::text THEN NULL::integer
            ELSE EXTRACT(year FROM age(CURRENT_DATE::timestamp with time zone, NULLIF(TRIM(BOTH FROM cu.birth_date), ''::text)::date::timestamp with time zone))::integer
        END AS customer_age,
        CASE cu.gender
            WHEN 'female'::text THEN '여성'::text
            WHEN 'male'::text THEN '남성'::text
            ELSE NULL::text
        END AS customer_gender_label,
    s.owner_user_id AS shop_owner_user_id,
    s.name AS shop_name,
    s.owner_name AS shop_owner_name,
    s.profile_image_url AS shop_profile_image_url,
    s.naver_place_url AS shop_naver_place_url,
    COALESCE(s.naver_booking_url, ''::text) AS shop_naver_booking_url,
    COALESCE(s.tier_badge::text, 'none'::text) AS shop_tier_badge,
    COALESCE(s.is_official, false) AS shop_is_official,
    COALESCE(s.slug, ''::text) AS shop_slug,
    COALESCE(c.author_user_id, s.owner_user_id) AS author_user_id,
    COALESCE(NULLIF(TRIM(BOTH FROM c.author_nickname_snap), ''::text), NULLIF(TRIM(BOTH FROM ap.nickname), ''::text), NULLIF(TRIM(BOTH FROM ap.name), ''::text), NULLIF(TRIM(BOTH FROM s.owner_name), ''::text), NULLIF(TRIM(BOTH FROM s.name), ''::text), 'SORI'::text) AS author_nickname,
    COALESCE(NULLIF(TRIM(BOTH FROM ap.avatar_url), ''::text), ''::text) AS author_avatar_url,
    r.id AS review_id,
    r.original_text AS review_original_text,
    r.edited_text AS review_edited_text,
    COALESCE(NULLIF(TRIM(BOTH FROM COALESCE(r.edited_text, ''::text)), ''::text), NULLIF(TRIM(BOTH FROM COALESCE(r.original_text, ''::text)), ''::text)) AS customer_review_text,
    r.director_reply,
    r.director_replied_at,
    r.rating AS review_rating,
    r.status AS review_status,
    r.accepted_at AS review_accepted_at,
    r.created_at AS review_created_at
   FROM customer_charts c
     JOIN shops s ON s.id = c.shop_id
     LEFT JOIN customers cu ON cu.id = c.customer_id
     LEFT JOIN profiles ap ON ap.id = COALESCE(c.author_user_id, s.owner_user_id)
     LEFT JOIN LATERAL ( SELECT rv.id,
            rv.chart_id,
            rv.puzzle_selections,
            rv.original_text,
            rv.edited_text,
            rv.status,
            rv.naver_registered,
            rv.naver_registered_at,
            rv.created_at,
            rv.customer_id,
            rv.content,
            rv.rating,
            rv.shop_id,
            rv.request_ai_reply,
            rv.accepted_at,
            rv.updated_at,
            rv.director_reply,
            rv.director_replied_at
           FROM customer_reviews rv
          WHERE rv.chart_id = c.id AND COALESCE(rv.original_text, ''::text) <> ''::text
          ORDER BY (COALESCE(rv.accepted_at, rv.created_at)) DESC NULLS LAST
         LIMIT 1) r ON true
  WHERE c.is_case_shared = true AND (COALESCE(c.signature_url, ''::text) <> ''::text OR COALESCE(c.consent_pdf_url, ''::text) <> ''::text) AND (COALESCE(c.before_image_url, ''::text) <> ''::text OR COALESCE(c.after_image_url, ''::text) <> ''::text);

-- view public.seminars reloptions=None
create or replace view public.seminars as
 SELECT id,
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
   FROM seminar_classes;
alter view public.seminars reset (security_invoker);

-- view public.shop_assets reloptions=None
create or replace view public.shop_assets as
 SELECT id AS shop_id,
    ( SELECT count(*)::integer AS count
           FROM customer_charts cc
          WHERE cc.shop_id = s.id) AS chart_count_total,
    ( SELECT count(*)::integer AS count
           FROM customer_charts cc
          WHERE cc.shop_id = s.id AND COALESCE(cc.is_case_shared, cc.case_shared, false) = true) AS ba_published_count,
    ( SELECT count(*)::integer AS count
           FROM chart_view_events cve
          WHERE cve.shop_id = s.id) AS ba_view_total,
    ( SELECT count(*)::integer AS count
           FROM case_bookmarks cb
             JOIN customer_charts cc ON cc.id = cb.chart_id
          WHERE cc.shop_id = s.id) AS bookmark_total,
    ( SELECT count(*)::integer AS count
           FROM seminar_classes sc
          WHERE sc.director_shop_id = s.id AND (sc.status = ANY (ARRAY['open'::text, 'held'::text, 'completed'::text]))) AS seminar_hosted_count,
    ( SELECT count(*)::integer AS count
           FROM seminar_requests sr
             JOIN customer_charts cc ON cc.id = sr.case_id
          WHERE cc.shop_id = s.id) AS seminar_request_received_count,
    ( SELECT count(*)::integer AS count
           FROM seminar_requests sr
          WHERE sr.requestor_shop_id = s.id) AS seminar_request_sent_count,
    COALESCE(follower_count, 0) AS follower_count,
    ( SELECT count(DISTINCT fg.fan_customer_id)::integer AS count
           FROM fan_gifts fg
          WHERE fg.beneficiary_shop_id = s.id AND fg.status = 'completed'::text) AS supporter_count,
    COALESCE(( SELECT sum(mp.revenue_echo_total)::integer AS sum
           FROM mentoring_posts mp
          WHERE mp.author_shop_id = s.id AND (mp.status = ANY (ARRAY['active'::text, 'enhancement_required'::text, 'purchase_disabled'::text]))), 0) AS mentoring_revenue_echo_total
   FROM shops s;
alter view public.shop_assets reset (security_invoker);

-- view public.unified_feed_items_v1 reloptions=None
create or replace view public.unified_feed_items_v1 as
 SELECT p.id::text AS feed_id,
        CASE
            WHEN p.post_type = 'whisper'::text OR COALESCE(p.is_whisper, false) THEN 'whisper'::text
            ELSE p.post_type
        END AS feed_kind,
    p.shop_id,
    p.author_user_id,
    p.created_at AS sort_at,
    p.id AS source_post_id,
    NULL::uuid AS source_chart_id,
    NULL::uuid AS source_seminar_id,
    COALESCE(p.feed_metadata, '{}'::jsonb) AS feed_metadata,
    p.visibility,
    COALESCE(p.is_whisper, false) AS is_whisper
   FROM community_posts p
  WHERE p.status = 'published'::text AND (COALESCE(p.is_whisper, false) = false OR can_view_whisper_post(p.id))
UNION ALL
 SELECT sc.id::text AS feed_id,
    'seminar'::text AS feed_kind,
    sc.director_shop_id AS shop_id,
    NULL::uuid AS author_user_id,
    COALESCE(sc.created_at, sc.event_date, now()) AS sort_at,
    NULL::uuid AS source_post_id,
    NULL::uuid AS source_chart_id,
    sc.id AS source_seminar_id,
    jsonb_build_object('title', sc.title, 'status', sc.status) AS feed_metadata,
    'public'::text AS visibility,
    false AS is_whisper
   FROM seminar_classes sc
  WHERE sc.status = ANY (ARRAY['open'::text, 'held'::text])
UNION ALL
 SELECT c.id::text AS feed_id,
    'ba'::text AS feed_kind,
    c.shop_id,
    s.owner_user_id AS author_user_id,
    c.created_at AS sort_at,
    NULL::uuid AS source_post_id,
    c.id AS source_chart_id,
    NULL::uuid AS source_seminar_id,
    '{}'::jsonb AS feed_metadata,
    'public'::text AS visibility,
    false AS is_whisper
   FROM customer_charts c
     JOIN shops s ON s.id = c.shop_id
  WHERE COALESCE(c.is_case_shared, false) = true;
alter view public.unified_feed_items_v1 reset (security_invoker);

commit;
