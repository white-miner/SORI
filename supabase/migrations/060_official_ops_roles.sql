-- 060_official_ops_roles.sql
-- SORI Official (brand persona, NOT admin) + Ops staff_roles separation.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Official shop flags (director-scoped RLS — never admin)
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.shops
  add column if not exists is_official boolean not null default false,
  add column if not exists slug text;

-- bio may be missing on older DBs
alter table public.shops
  add column if not exists bio text not null default '';

create unique index if not exists shops_slug_uidx
  on public.shops (slug)
  where slug is not null and trim(slug) <> '';

create index if not exists shops_is_official_idx
  on public.shops (is_official)
  where is_official = true;

comment on column public.shops.is_official is
  'SORI brand persona shop. Same director RLS — never Ops/admin.';
comment on column public.shops.slug is
  'Public stable handle e.g. sori-official.';

alter table public.profiles
  add column if not exists is_official boolean not null default false;

comment on column public.profiles.is_official is
  'Linked Official account flag (display). No elevated DB privileges.';

-- Fixed UUID seed — slug remains the public id "sori-official"
insert into public.shops (
  id, name, owner_name, phone, address, bio, is_official, slug, created_at, updated_at
)
values (
  '00000000-0000-4000-8000-0000000000f1',
  'SORI',
  'SORI',
  '',
  '',
  '소통하는 리뷰 — SORI 공식 계정. 공지·가이드·플랫폼 소식을 전합니다.',
  true,
  'sori-official',
  now(),
  now()
)
on conflict (id) do update set
  name = excluded.name,
  owner_name = excluded.owner_name,
  bio = excluded.bio,
  is_official = true,
  slug = 'sori-official',
  updated_at = now();

update public.shops
set
  name = 'SORI',
  owner_name = coalesce(nullif(trim(owner_name), ''), 'SORI'),
  bio = coalesce(
    nullif(trim(bio), ''),
    '소통하는 리뷰 — SORI 공식 계정. 공지·가이드·플랫폼 소식을 전합니다.'
  ),
  is_official = true,
  slug = 'sori-official',
  updated_at = now()
where id = '00000000-0000-4000-8000-0000000000f1'
   or slug = 'sori-official';

-- (removed duplicate bio ensure DO block)

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) staff_roles — Ops matrix (does NOT pollute profiles.role)
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.staff_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null
    check (role in ('moderator', 'ops_admin', 'super_admin')),
  granted_by uuid references public.profiles (id) on delete set null,
  notes text not null default '',
  created_at timestamptz not null default now(),
  unique (user_id, role)
);

create index if not exists staff_roles_user_idx on public.staff_roles (user_id);
create index if not exists staff_roles_role_idx on public.staff_roles (role);

comment on table public.staff_roles is
  'Ops permissions. Separate from profiles.role (director/customer/guest).';

alter table public.staff_roles enable row level security;

drop policy if exists staff_roles_select_own on public.staff_roles;
create policy staff_roles_select_own
  on public.staff_roles for select
  to authenticated
  using (user_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Audit log
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles (id) on delete set null,
  action text not null,
  target_type text not null default '',
  target_id text not null default '',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_actor_idx
  on public.admin_audit_log (actor_user_id, created_at desc);

alter table public.admin_audit_log enable row level security;

-- No broad client read; staff may read own via RPC later.

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) Staff helpers
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.has_staff_role(p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.staff_roles sr
    where sr.user_id = auth.uid()
      and sr.role = any (p_roles)
  );
$$;

create or replace function public.require_staff(p_roles text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.has_staff_role(p_roles) then
    raise exception 'forbidden: requires staff role %', p_roles;
  end if;
end;
$$;

create or replace function public.write_admin_audit(
  p_action text,
  p_target_type text default '',
  p_target_id text default '',
  p_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_super_count int;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  -- Staff only; allow bootstrap when no super_admin exists yet.
  if not public.has_staff_role(
    array['moderator', 'ops_admin', 'super_admin']
  ) then
    select count(*) into v_super_count
    from public.staff_roles
    where role = 'super_admin';
    if coalesce(v_super_count, 0) > 0 then
      raise exception 'forbidden: audit write requires staff';
    end if;
  end if;
  insert into public.admin_audit_log (
    actor_user_id, action, target_type, target_id, payload
  ) values (
    auth.uid(), coalesce(p_action, ''), coalesce(p_target_type, ''),
    coalesce(p_target_id, ''), coalesce(p_payload, '{}'::jsonb)
  );
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) Ops RPCs (security definer)
-- ═══════════════════════════════════════════════════════════════════════════

-- Shop business verification — ops_admin | super_admin
create or replace function public.verify_shop(
  p_shop_id uuid,
  p_status text,
  p_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := lower(trim(coalesce(p_status, '')));
begin
  perform public.require_staff(array['ops_admin', 'super_admin']);
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;
  if v_status not in ('none', 'pending', 'business_verified', 'rejected') then
    raise exception 'invalid status';
  end if;

  insert into public.shop_verifications (
    shop_id, status, verified_at, verified_by, notes, updated_at
  ) values (
    p_shop_id,
    v_status,
    case when v_status = 'business_verified' then now() else null end,
    coalesce(auth.uid()::text, ''),
    coalesce(p_notes, ''),
    now()
  )
  on conflict (shop_id) do update set
    status = excluded.status,
    verified_at = excluded.verified_at,
    verified_by = excluded.verified_by,
    notes = excluded.notes,
    updated_at = now();

  perform public.write_admin_audit(
    'verify_shop', 'shop', p_shop_id::text,
    jsonb_build_object('status', v_status, 'notes', coalesce(p_notes, ''))
  );

  return jsonb_build_object('ok', true, 'shop_id', p_shop_id, 'status', v_status);
end;
$$;

-- Force-hide community post — moderator | ops_admin | super_admin
create or replace function public.hide_community_post(
  p_post_id uuid,
  p_reason text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  perform public.require_staff(array['moderator', 'ops_admin', 'super_admin']);
  if p_post_id is null then
    raise exception 'post_id required';
  end if;

  update public.community_posts
  set status = 'hidden',
      updated_at = now()
  where id = p_post_id
  returning id into v_id;

  if v_id is null then
    raise exception 'post not found';
  end if;

  perform public.write_admin_audit(
    'hide_community_post', 'community_post', v_id::text,
    jsonb_build_object('reason', coalesce(p_reason, ''))
  );

  return jsonb_build_object('ok', true, 'post_id', v_id, 'status', 'hidden');
end;
$$;

-- Grant staff role — super_admin only (or bootstrap when zero supers)
create or replace function public.grant_staff_role(
  p_user_id uuid,
  p_role text,
  p_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := lower(trim(coalesce(p_role, '')));
  v_super_count int;
begin
  if p_user_id is null then
    raise exception 'user_id required';
  end if;
  if v_role not in ('moderator', 'ops_admin', 'super_admin') then
    raise exception 'invalid role';
  end if;

  select count(*) into v_super_count
  from public.staff_roles where role = 'super_admin';

  if v_super_count > 0 then
    perform public.require_staff(array['super_admin']);
  elsif auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  -- If no super yet, first grant is allowed for authenticated caller (bootstrap).

  insert into public.staff_roles (user_id, role, granted_by, notes)
  values (p_user_id, v_role, auth.uid(), coalesce(p_notes, ''))
  on conflict (user_id, role) do update set
    notes = excluded.notes,
    granted_by = excluded.granted_by;

  perform public.write_admin_audit(
    'grant_staff_role', 'profile', p_user_id::text,
    jsonb_build_object('role', v_role, 'notes', coalesce(p_notes, ''))
  );

  return jsonb_build_object('ok', true, 'user_id', p_user_id, 'role', v_role);
end;
$$;

-- B2B partner verification — ops_admin | super_admin
create or replace function public.verify_b2b_partner(
  p_partner_id uuid,
  p_status text,
  p_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := lower(trim(coalesce(p_status, '')));
  v_id uuid;
begin
  perform public.require_staff(array['ops_admin', 'super_admin']);
  if p_partner_id is null then
    raise exception 'partner_id required';
  end if;
  if v_status not in ('none', 'business_verified', 'sori_partner') then
    raise exception 'invalid status';
  end if;

  update public.b2b_partners
  set verification_status = v_status,
      notes = case
        when coalesce(p_notes, '') = '' then notes
        else p_notes
      end,
      updated_at = now()
  where id = p_partner_id
  returning id into v_id;

  if v_id is null then
    raise exception 'partner not found';
  end if;

  perform public.write_admin_audit(
    'verify_b2b_partner', 'b2b_partner', v_id::text,
    jsonb_build_object('status', v_status)
  );

  return jsonb_build_object('ok', true, 'partner_id', v_id, 'status', v_status);
end;
$$;

grant execute on function public.has_staff_role(text[])
  to authenticated;
grant execute on function public.require_staff(text[])
  to authenticated;
grant execute on function public.write_admin_audit(text, text, text, jsonb)
  to authenticated;
grant execute on function public.verify_shop(uuid, text, text)
  to authenticated;
grant execute on function public.hide_community_post(uuid, text)
  to authenticated;
grant execute on function public.grant_staff_role(uuid, text, text)
  to authenticated;
grant execute on function public.verify_b2b_partner(uuid, text, text)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 6) Feed view: expose shop_is_official
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
  'PII-safe community B/A feed + shop_is_official for Official badge.';

grant select on public.community_shared_cases to anon, authenticated, public;
