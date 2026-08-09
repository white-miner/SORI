-- 샵 운영시간·SNS + 서비스 메뉴 설명(jsonb 객체) 지원
alter table public.shops
  add column if not exists operating_hours text not null default '',
  add column if not exists sns_blog_url text not null default '',
  add column if not exists sns_instagram_url text not null default '';

comment on column public.shops.operating_hours is '휴무일 및 운영시간 안내 텍스트';
comment on column public.shops.sns_blog_url is '블로그 링크';
comment on column public.shops.sns_instagram_url is '인스타그램 링크';
comment on column public.shops.service_menu is
  '서비스 메뉴 [{name, description}] — 레거시 string 배열도 앱에서 파싱';

-- 레거시 string[] → 객체 배열로 정규화 (이미 객체면 유지)
update public.shops
set service_menu = (
  select coalesce(
    jsonb_agg(
      case
        when jsonb_typeof(elem) = 'string' then jsonb_build_object(
          'name', elem #>> '{}',
          'description', ''
        )
        when jsonb_typeof(elem) = 'object' then elem
        else jsonb_build_object('name', elem::text, 'description', '')
      end
    ),
    '[]'::jsonb
  )
  from jsonb_array_elements(service_menu) as elem
)
where service_menu is not null
  and jsonb_typeof(service_menu) = 'array'
  and exists (
    select 1
    from jsonb_array_elements(service_menu) e
    where jsonb_typeof(e) = 'string'
  );
