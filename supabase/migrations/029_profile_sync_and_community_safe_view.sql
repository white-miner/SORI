-- 029: 프로필 아바타 동기화 + 공유 케이스 공개 투영 뷰 + 리뷰 스레드 보조
-- 민감정보(PII)는 공개 뷰에서 배제합니다.

-- 1) profiles.avatar_url + 로그인 메타 동기화
alter table public.profiles
  add column if not exists avatar_url text not null default '';

comment on column public.profiles.avatar_url is
  '소셜 로그인 프로필 사진 URL (Kakao avatar_url/picture/profile_image)';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  display_name text;
  avatar text;
begin
  display_name := coalesce(
    nullif(trim(meta->>'name'), ''),
    nullif(trim(meta->>'full_name'), ''),
    nullif(trim(meta->>'nickname'), ''),
    nullif(trim(meta->>'preferred_username'), ''),
    ''
  );
  avatar := coalesce(
    nullif(trim(meta->>'avatar_url'), ''),
    nullif(trim(meta->>'picture'), ''),
    nullif(trim(meta->>'profile_image'), ''),
    nullif(trim(meta->>'profile_image_url'), ''),
    ''
  );

  insert into public.profiles (id, name, phone, avatar_url, role, active_mode)
  values (
    new.id,
    display_name,
    coalesce(meta->>'phone', ''),
    avatar,
    'guest',
    'customer'
  )
  on conflict (id) do update
    set
      name = case
        when excluded.name <> '' then excluded.name
        else public.profiles.name
      end,
      avatar_url = case
        when excluded.avatar_url <> '' then excluded.avatar_url
        else public.profiles.avatar_url
      end,
      updated_at = now();

  return new;
end;
$$;

-- Auth 메타 갱신 시 프로필 재동기화
create or replace function public.sync_profile_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  display_name text;
  avatar text;
begin
  display_name := coalesce(
    nullif(trim(meta->>'name'), ''),
    nullif(trim(meta->>'full_name'), ''),
    nullif(trim(meta->>'nickname'), ''),
    nullif(trim(meta->>'preferred_username'), ''),
    ''
  );
  avatar := coalesce(
    nullif(trim(meta->>'avatar_url'), ''),
    nullif(trim(meta->>'picture'), ''),
    nullif(trim(meta->>'profile_image'), ''),
    nullif(trim(meta->>'profile_image_url'), ''),
    ''
  );

  insert into public.profiles (id, name, phone, avatar_url, role, active_mode)
  values (
    new.id,
    display_name,
    coalesce(meta->>'phone', ''),
    avatar,
    'guest',
    'customer'
  )
  on conflict (id) do update
    set
      name = case
        when excluded.name <> '' then excluded.name
        else public.profiles.name
      end,
      phone = case
        when coalesce(excluded.phone, '') <> '' then excluded.phone
        else public.profiles.phone
      end,
      avatar_url = case
        when excluded.avatar_url <> '' then excluded.avatar_url
        else public.profiles.avatar_url
      end,
      updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_updated_sync_profile on auth.users;
create trigger on_auth_user_updated_sync_profile
  after update of raw_user_meta_data on auth.users
  for each row execute function public.sync_profile_from_auth_user();

-- App에서 호출 가능한 upsert (로그인 후처리)
create or replace function public.upsert_my_profile(
  p_name text default null,
  p_avatar_url text default null,
  p_phone text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  row public.profiles;
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  insert into public.profiles (id, name, phone, avatar_url, role, active_mode)
  values (
    uid,
    coalesce(nullif(trim(p_name), ''), ''),
    coalesce(nullif(trim(p_phone), ''), ''),
    coalesce(nullif(trim(p_avatar_url), ''), ''),
    'guest',
    'customer'
  )
  on conflict (id) do update
    set
      name = case
        when coalesce(nullif(trim(excluded.name), ''), '') <> '' then excluded.name
        else public.profiles.name
      end,
      phone = case
        when coalesce(nullif(trim(excluded.phone), ''), '') <> '' then excluded.phone
        else public.profiles.phone
      end,
      avatar_url = case
        when coalesce(nullif(trim(excluded.avatar_url), ''), '') <> '' then excluded.avatar_url
        else public.profiles.avatar_url
      end,
      updated_at = now()
  returning * into row;

  return row;
end;
$$;

grant execute on function public.upsert_my_profile(text, text, text) to authenticated, anon;

-- profiles insert for self (first login upsert without trigger race)
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

-- 2) 공개 공유 케이스 안전 투영 뷰 (PII 배제)
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
  c.before_image_url,
  c.after_image_url,
  c.is_case_shared,
  c.created_at,
  s.name as shop_name,
  s.owner_name as shop_owner_name,
  s.profile_image_url as shop_profile_image_url,
  s.naver_place_url as shop_naver_place_url,
  r.id as review_id,
  r.original_text as review_original_text,
  r.edited_text as review_edited_text,
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
  '오픈 피드용 공유 케이스 — 고객 실명/연락처/customer_id/token 등 PII 미포함';

grant select on public.community_shared_cases to anon, authenticated, public;

-- 3) chart↔ review 1:1 권장 인덱스 (중복이 없을 때만 unique)
do $$
begin
  if not exists (
    select 1
    from public.customer_reviews
    group by chart_id
    having count(*) > 1
  ) then
    create unique index if not exists uq_customer_reviews_chart_id
      on public.customer_reviews (chart_id);
  else
    create index if not exists idx_customer_reviews_chart_id
      on public.customer_reviews (chart_id);
  end if;
exception
  when others then
    create index if not exists idx_customer_reviews_chart_id
      on public.customer_reviews (chart_id);
end $$;
