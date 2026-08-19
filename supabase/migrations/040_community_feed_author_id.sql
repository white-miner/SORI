-- 커뮤니티 피드에 샵 원장 auth id 노출 (본인 퀵 게시 검증용, PII 아님)

drop view if exists public.community_shared_cases;

create view public.community_shared_cases
with (security_invoker = true)
as
select
  c.id as chart_id,
  c.shop_id,
  c.visit_number,
  c.care_name,
  c.treatment_summary,
  c.concern_chips,
  case
    when c.care_tags is not null
      and jsonb_typeof(c.care_tags) = 'array'
      and jsonb_array_length(c.care_tags) > 0
      then c.care_tags
    else coalesce(c.concern_chips, '[]'::jsonb)
  end as care_tags,
  c.before_image_url,
  c.after_image_url,
  c.is_case_shared,
  c.created_at,
  c.device_info,
  coalesce(c.skin_sensitivity, '') as skin_sensitivity,
  case
    when cu.birth_date is null then null
    else (extract(year from age(current_date, cu.birth_date)))::int
  end as customer_age,
  case cu.gender
    when 'female' then '여성'
    when 'male' then '남성'
    else null
  end as customer_gender_label,
  s.owner_user_id as shop_owner_user_id,
  s.name as shop_name,
  s.owner_name as shop_owner_name,
  s.profile_image_url as shop_profile_image_url,
  s.naver_place_url as shop_naver_place_url,
  coalesce(s.naver_booking_url, '') as shop_naver_booking_url,
  coalesce(s.tier_badge::text, 'none') as shop_tier_badge,
  r.id as review_id,
  r.original_text as review_original_text,
  r.edited_text as review_edited_text,
  coalesce(
    nullif(trim(coalesce(r.edited_text, '')), ''),
    nullif(trim(coalesce(r.original_text, '')), '')
  ) as customer_review_text,
  r.director_reply,
  r.director_replied_at,
  r.rating as review_rating,
  r.status as review_status,
  r.accepted_at as review_accepted_at,
  r.created_at as review_created_at
from public.customer_charts c
join public.shops s on s.id = c.shop_id
left join public.customers cu on cu.id = c.customer_id
left join lateral (
  select *
  from public.customer_reviews rv
  where rv.chart_id = c.id
    and coalesce(rv.original_text, '') <> ''
  order by coalesce(rv.accepted_at, rv.created_at) desc nulls last
  limit 1
) r on true
where c.is_case_shared = true
  and (
    coalesce(c.signature_url, '') <> ''
    or coalesce(c.consent_pdf_url, '') <> ''
  )
  and (
    coalesce(c.before_image_url, '') <> ''
    or coalesce(c.after_image_url, '') <> ''
  );

comment on view public.community_shared_cases is
  'PII-safe community B/A feed + shop_owner_user_id for author-only quick post.';

grant select on public.community_shared_cases to anon, authenticated, public;
