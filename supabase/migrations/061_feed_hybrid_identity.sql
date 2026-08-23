-- 061_feed_hybrid_identity.sql
-- Weverse-style Person + Affiliation identity + feed author join.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) profiles.nickname (feed Line1)
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.profiles
  add column if not exists nickname text not null default '';

comment on column public.profiles.nickname is
  'Public display name for feed Line1 (Person). Separate from shop name.';

update public.profiles
set nickname = coalesce(nullif(trim(nickname), ''), nullif(trim(name), ''), 'SORI 유저')
where coalesce(trim(nickname), '') = '';

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) shop_memberships (multi-staff shops)
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.shop_memberships (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'staff'
    check (role in ('owner', 'director', 'therapist', 'staff')),
  title text not null default '',
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, user_id)
);

create index if not exists shop_memberships_shop_idx
  on public.shop_memberships (shop_id);
create index if not exists shop_memberships_user_idx
  on public.shop_memberships (user_id);
create index if not exists shop_memberships_public_idx
  on public.shop_memberships (shop_id)
  where is_public = true;

comment on table public.shop_memberships is
  'Multi-staff affiliation. shops.owner_user_id remains settlement SSOT.';

alter table public.shop_memberships enable row level security;

drop policy if exists shop_memberships_select_public on public.shop_memberships;
create policy shop_memberships_select_public
  on public.shop_memberships for select
  using (is_public = true or user_id = auth.uid());

drop policy if exists shop_memberships_owner_write on public.shop_memberships;
create policy shop_memberships_owner_write
  on public.shop_memberships for all
  using (
    exists (
      select 1 from public.shops s
      where s.id = shop_id and s.owner_user_id = auth.uid()
    )
    or user_id = auth.uid()
  )
  with check (
    exists (
      select 1 from public.shops s
      where s.id = shop_id and s.owner_user_id = auth.uid()
    )
    or user_id = auth.uid()
  );

-- Seed owners into memberships
insert into public.shop_memberships (shop_id, user_id, role, title, is_public)
select s.id, s.owner_user_id, 'owner', '원장', true
from public.shops s
where s.owner_user_id is not null
on conflict (shop_id, user_id) do update set
  role = excluded.role,
  updated_at = now();

-- Keep owner membership in sync
create or replace function public.sync_shop_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_user_id is null then
    return new;
  end if;
  insert into public.shop_memberships (shop_id, user_id, role, title, is_public)
  values (new.id, new.owner_user_id, 'owner', '원장', true)
  on conflict (shop_id, user_id) do update set
    role = 'owner',
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_sync_shop_owner_membership on public.shops;
create trigger trg_sync_shop_owner_membership
  after insert or update of owner_user_id on public.shops
  for each row
  execute function public.sync_shop_owner_membership();

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) customer_charts.author_user_id (+ optional nickname snap)
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.customer_charts
  add column if not exists author_user_id uuid
    references public.profiles (id) on delete set null,
  add column if not exists author_nickname_snap text not null default '';

create index if not exists customer_charts_author_idx
  on public.customer_charts (author_user_id)
  where author_user_id is not null;

comment on column public.customer_charts.author_user_id is
  'Person who published the case (staff member). Fallback: shop owner.';
comment on column public.customer_charts.author_nickname_snap is
  'Frozen Line1 nickname at share time.';

-- Backfill author from shop owner
update public.customer_charts c
set author_user_id = s.owner_user_id
from public.shops s
where s.id = c.shop_id
  and c.author_user_id is null
  and s.owner_user_id is not null;

update public.customer_charts c
set author_nickname_snap = coalesce(
  nullif(trim(c.author_nickname_snap), ''),
  nullif(trim(p.nickname), ''),
  nullif(trim(p.name), ''),
  nullif(trim(s.owner_name), ''),
  nullif(trim(s.name), ''),
  'SORI'
)
from public.shops s
left join public.profiles p on p.id = coalesce(c.author_user_id, s.owner_user_id)
where s.id = c.shop_id
  and coalesce(trim(c.author_nickname_snap), '') = '';

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) community_shared_cases — author + shop identity
-- ═══════════════════════════════════════════════════════════════════════════

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
    when nullif(trim(cu.birth_date::text), '') is null then null
    when nullif(trim(cu.birth_date::text), '')
      !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
      then null
    else (
      extract(
        year from age(
          current_date,
          nullif(trim(cu.birth_date::text), '')::date
        )
      )
    )::int
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
  coalesce(s.is_official, false) as shop_is_official,
  coalesce(s.slug, '') as shop_slug,
  coalesce(c.author_user_id, s.owner_user_id) as author_user_id,
  coalesce(
    nullif(trim(c.author_nickname_snap), ''),
    nullif(trim(ap.nickname), ''),
    nullif(trim(ap.name), ''),
    nullif(trim(s.owner_name), ''),
    nullif(trim(s.name), ''),
    'SORI'
  ) as author_nickname,
  coalesce(nullif(trim(ap.avatar_url), ''), '') as author_avatar_url,
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
left join public.profiles ap
  on ap.id = coalesce(c.author_user_id, s.owner_user_id)
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
  'PII-safe B/A feed with Weverse identity: author_nickname + shop_name.';

grant select on public.community_shared_cases to anon, authenticated, public;
