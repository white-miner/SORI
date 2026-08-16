-- 030: 커뮤니티 피드 전환율 — 예약 URL · care_tags · 후기 텍스트 별칭

alter table public.shops
  add column if not exists naver_booking_url text not null default '';

comment on column public.shops.naver_booking_url is
  '네이버 예약(또는 플레이스 예약) 직행 URL. 비어 있으면 naver_place_url / 샵 프로필 Fallback';

-- 차트 작성 시 고민 칩과 동기화되는 피드용 해시태그 배열
alter table public.customer_charts
  add column if not exists care_tags jsonb not null default '[]'::jsonb;

update public.customer_charts
set care_tags = coalesce(concern_chips, '[]'::jsonb)
where care_tags = '[]'::jsonb
  and concern_chips is not null
  and concern_chips <> '[]'::jsonb;

comment on column public.customer_charts.care_tags is
  '피드 해시태그용 태그 배열. 작성 시 concern_chips 와 동일하게 유지 권장';

create or replace view public.community_shared_cases
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
  s.name as shop_name,
  s.owner_name as shop_owner_name,
  s.profile_image_url as shop_profile_image_url,
  s.naver_place_url as shop_naver_place_url,
  coalesce(s.naver_booking_url, '') as shop_naver_booking_url,
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
  '오픈 피드용 공유 케이스 — PII 미포함 · care_tags/customer_review_text/director_reply/예약 URL 포함';

grant select on public.community_shared_cases to anon, authenticated, public;
