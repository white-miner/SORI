-- 028: 네이버 플레이스 리뷰 작성 직행 URL
-- 계산대 1분 컷 — AI 후기 복사 후 외부 브라우저로 정확한 작성창 오픈.

alter table public.shops
  add column if not exists naver_review_write_url text not null default '';

comment on column public.shops.naver_review_write_url is
  '네이버 플레이스 리뷰 작성 직행 링크 (url_launcher 대상). 비어 있으면 naver_place_url 휴리스틱 사용';
