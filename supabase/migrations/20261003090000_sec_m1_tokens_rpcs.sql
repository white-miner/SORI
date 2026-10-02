-- =============================================================================
-- SORI P0 security - M1 (step S1): customer link tokens + safe RPCs + guard triggers
-- -----------------------------------------------------------------------------
-- STATUS: NOT APPLIED. Apply only after explicit approval (see PR description).
-- Plan:   SORI P0 security plan (kept outside the repo), step S1 / migration M1; approved defaults Q1-Q14.
--
-- ADDITIVE ONLY:
--   * creates new functions / one new table / two new triggers;
--   * uses plain CREATE (no OR REPLACE, no IF NOT EXISTS), so it aborts instead of
--     silently replacing anything if a name already exists;
--   * does NOT drop, alter, revoke or re-grant any existing object. Every REVOKE /
--     GRANT below targets an object created in this file (needed because the
--     schema default privileges auto-grant new tables/functions to anon).
--
-- Behaviour changes for existing flows (both triggers, by design - see PR):
--   1) customer_charts: is_case_shared/case_shared can only be true when
--      consent_marketing = true AND a signature or consent PDF exists; otherwise
--      they are silently set to false (no error -> no failed saves). When marketing
--      consent is withdrawn, the chart's published case_share posts become 'hidden'.
--   2) shops: anon/authenticated cannot change owner_user_id unless it is currently
--      NULL (and then only to themselves, never on is_official shops) or they are
--      the current owner. Protected counters/flags (is_official, tier_badge,
--      kakao_point, sori_cash_balance, follower_count, shared_case_count) are
--      silently kept at their old value for client roles. service_role, postgres
--      and SECURITY DEFINER functions are not affected.
--
-- Error codes used by the RPCs (PostgREST maps SQLSTATE 'PTxyz' to HTTP xyz):
--   PT404 token_not_found / shop_not_found, PT410 token_expired (expired or revoked),
--   PT409 already_submitted, PT429 too_many_requests, 22023 invalid input,
--   42501 login_required / forbidden.
-- Rollback: supabase/security/rollback/20261003090000_sec_m1_tokens_rpcs.rollback.sql
-- Tests:    supabase/security/tests/m1_test.sql (all in one transaction, rolled back)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0) Helpers
-- -----------------------------------------------------------------------------

-- Lenient text -> uuid (used later by storage policies: storage.foldername(name)[1]).
create function public.try_uuid(p text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return p::uuid;
exception when others then
  return null;
end
$$;
comment on function public.try_uuid(text) is 'SORI P0 M1: text -> uuid, NULL when not a uuid.';

-- Strict owner check: shops.owner_user_id = auth.uid().
-- M1 objects use this (not memberships) because shop_memberships is still
-- self-insertable until S5 fixes shop_memberships_owner_write.
create function public.is_shop_owner(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_shop_id is not null
     and (select auth.uid()) is not null
     and exists (
       select 1
         from public.shops s
        where s.id = p_shop_id
          and s.owner_user_id = (select auth.uid())
     );
$$;
comment on function public.is_shop_owner(uuid) is 'SORI P0 M1: true when auth.uid() is shops.owner_user_id.';

-- Owner or owner/director membership (target helper for S5 policies; trustworthy
-- only after S5 locks shop_memberships writes).
create function public.is_shop_manager(p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_shop_id is not null
     and (select auth.uid()) is not null
     and (
       exists (
         select 1
           from public.shops s
          where s.id = p_shop_id
            and s.owner_user_id = (select auth.uid())
       )
       or exists (
         select 1
           from public.shop_memberships m
          where m.shop_id = p_shop_id
            and m.user_id = (select auth.uid())
            and m.role in ('owner', 'director')
       )
     );
$$;
comment on function public.is_shop_manager(uuid) is 'SORI P0 M1: owner or owner/director membership. Use for S5 policies.';

-- Decision Q4: mask the middle of a person name. 김민희 -> 김*희, 이수 -> 이*, 남궁민수 -> 남**수.
create function public.mask_person_name(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
           when p_name is null or btrim(p_name) = '' then null
           when char_length(btrim(p_name)) = 1 then '*'
           when char_length(btrim(p_name)) = 2 then left(btrim(p_name), 1) || '*'
           else left(btrim(p_name), 1)
                || repeat('*', char_length(btrim(p_name)) - 2)
                || right(btrim(p_name), 1)
         end;
$$;
comment on function public.mask_person_name(text) is 'SORI P0 M1 (Q4): 김민희 -> 김*희.';

revoke all on function public.try_uuid(text) from public, anon, authenticated, service_role;
grant execute on function public.try_uuid(text) to anon, authenticated, service_role;
revoke all on function public.is_shop_owner(uuid) from public, anon, authenticated, service_role;
grant execute on function public.is_shop_owner(uuid) to authenticated, service_role;
revoke all on function public.is_shop_manager(uuid) from public, anon, authenticated, service_role;
grant execute on function public.is_shop_manager(uuid) to authenticated, service_role;
revoke all on function public.mask_person_name(text) from public, anon, authenticated, service_role;
grant execute on function public.mask_person_name(text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 1) Customer link tokens (care report / review). Only sha256(token) is stored.
-- -----------------------------------------------------------------------------
create table public.customer_access_tokens (
  id             uuid primary key default gen_random_uuid(),
  kind           text not null,
  token_hash     bytea not null,
  chart_id       uuid not null references public.customer_charts(id) on delete cascade,
  shop_id        uuid not null references public.shops(id) on delete cascade,
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  expires_at     timestamptz not null default (now() + interval '30 days'),  -- decision Q2
  revoked_at     timestamptz,
  last_opened_at timestamptz,
  open_count     integer not null default 0,
  constraint customer_access_tokens_kind_check check (kind in ('care_report', 'review')),
  constraint customer_access_tokens_token_hash_key unique (token_hash),
  constraint customer_access_tokens_expiry_check check (expires_at > created_at)
);
comment on table public.customer_access_tokens is
  'SORI P0 M1: unguessable customer links (43-char base64url token, only sha256 stored). '
  'Created/revoked via create_customer_link / revoke_customer_links; resolved by anon RPCs.';
create index customer_access_tokens_chart_idx on public.customer_access_tokens (chart_id);
create index customer_access_tokens_shop_idx on public.customer_access_tokens (shop_id);

alter table public.customer_access_tokens enable row level security;
-- default privileges would grant ALL to anon/authenticated: take that back for this new table.
revoke all on table public.customer_access_tokens from public, anon, authenticated, service_role;
grant select on table public.customer_access_tokens to authenticated;
grant select, insert, update, delete on table public.customer_access_tokens to service_role;

create policy customer_access_tokens_owner_select
  on public.customer_access_tokens
  as permissive
  for select
  to authenticated
  using (public.is_shop_owner(shop_id));

-- -----------------------------------------------------------------------------
-- 2) Owner RPCs: create / revoke links
-- -----------------------------------------------------------------------------
create function public.create_customer_link(
  p_chart_id uuid,
  p_kind text default 'care_report',
  p_ttl_days integer default 30
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_shop  uuid;
  v_token text;
  v_exp   timestamptz;
  v_id    uuid;
begin
  if v_uid is null then
    raise exception 'login_required' using errcode = '42501';
  end if;
  if p_kind is null or p_kind not in ('care_report', 'review') then
    raise exception 'invalid_kind' using errcode = '22023';
  end if;

  select c.shop_id into v_shop from public.customer_charts c where c.id = p_chart_id;
  if v_shop is null or not public.is_shop_owner(v_shop) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- 32 random bytes -> base64url without padding (43 chars)
  v_token := rtrim(translate(replace(encode(extensions.gen_random_bytes(32), 'base64'), E'\n', ''), '+/', '-_'), '=');
  -- decision Q2: 30 days by default and at most 30 days
  v_exp := now() + make_interval(days => greatest(1, least(coalesce(p_ttl_days, 30), 30)));

  insert into public.customer_access_tokens (kind, token_hash, chart_id, shop_id, created_by, expires_at)
  values (p_kind, extensions.digest(v_token, 'sha256'), p_chart_id, v_shop, v_uid, v_exp)
  returning id into v_id;

  return jsonb_build_object(
    'id', v_id,
    'token', v_token,
    'kind', p_kind,
    'chart_id', p_chart_id,
    'expires_at', v_exp
  );
end
$$;
comment on function public.create_customer_link(uuid, text, integer) is
  'SORI P0 M1: shop owner creates a care_report/review link for a chart. Returns the raw token once.';

create function public.revoke_customer_links(p_chart_id uuid, p_kind text default null)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_shop uuid;
  v_n    integer;
begin
  if (select auth.uid()) is null then
    raise exception 'login_required' using errcode = '42501';
  end if;
  select c.shop_id into v_shop from public.customer_charts c where c.id = p_chart_id;
  if v_shop is null or not public.is_shop_owner(v_shop) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update public.customer_access_tokens t
     set revoked_at = now()
   where t.chart_id = p_chart_id
     and t.revoked_at is null
     and (p_kind is null or t.kind = p_kind);
  get diagnostics v_n = row_count;
  return v_n;
end
$$;
comment on function public.revoke_customer_links(uuid, text) is
  'SORI P0 M1: shop owner revokes all (or one kind of) active links of a chart. Returns count.';

revoke all on function public.create_customer_link(uuid, text, integer) from public, anon, authenticated, service_role;
grant execute on function public.create_customer_link(uuid, text, integer) to authenticated;
revoke all on function public.revoke_customer_links(uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.revoke_customer_links(uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) Token resolution (internal only)
-- -----------------------------------------------------------------------------
create function public._resolve_customer_token(p_token text, p_kind text)
returns public.customer_access_tokens
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  r public.customer_access_tokens;
begin
  if p_token is null or char_length(p_token) not between 20 and 128 then
    raise exception 'token_not_found' using errcode = 'PT404';
  end if;

  select * into r
    from public.customer_access_tokens t
   where t.token_hash = extensions.digest(p_token, 'sha256')
     and t.kind = p_kind;
  if not found then
    raise exception 'token_not_found' using errcode = 'PT404';
  end if;
  if r.revoked_at is not null or r.expires_at <= now() then
    raise exception 'token_expired' using errcode = 'PT410';
  end if;

  -- best effort open counter (skipped inside read-only transactions, e.g. GET /rpc)
  begin
    update public.customer_access_tokens
       set last_opened_at = now(), open_count = open_count + 1
     where id = r.id;
  exception when read_only_sql_transaction then
    null;
  end;
  return r;
end
$$;
comment on function public._resolve_customer_token(text, text) is
  'SORI P0 M1 internal: validate token (PT404 unknown, PT410 expired/revoked). Not callable by API roles.';
revoke all on function public._resolve_customer_token(text, text) from public, anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4) anon-callable RPCs (SECURITY DEFINER, fixed search_path, allow-listed columns)
-- -----------------------------------------------------------------------------

-- D1 care report. Excludes: signature_url, consent_pdf_url, allergy/side effects/
-- psychological notes, safety snapshot, dob, address, guardian phone, paid amount,
-- ai_insight, customer phone/id. Photos only with consent_photo (decision Q6).
create function public.get_care_report_by_token(p_token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  t        public.customer_access_tokens;
  c        public.customer_charts;
  s        public.shops;
  v_name   text;
  v_photos boolean;
begin
  t := public._resolve_customer_token(p_token, 'care_report');

  select * into c from public.customer_charts where id = t.chart_id;
  if not found or c.shop_id is distinct from t.shop_id then
    raise exception 'token_not_found' using errcode = 'PT404';
  end if;
  select * into s from public.shops where id = c.shop_id;
  select cu.name into v_name from public.customers cu where cu.id = c.customer_id;
  v_photos := coalesce(c.consent_photo, false);

  return jsonb_build_object(
    'kind', 'care_report',
    'expires_at', t.expires_at,
    'customer_display_name', public.mask_person_name(v_name),
    'photos_withheld', (not v_photos)
                       and (coalesce(c.before_image_url, '') <> '' or coalesce(c.after_image_url, '') <> ''),
    'shop', jsonb_build_object(
      'id', s.id,
      'name', s.name,
      'phone', s.phone,
      'address', s.address,
      'naver_place_url', s.naver_place_url,
      'naver_booking_url', s.naver_booking_url,
      'naver_review_write_url', s.naver_review_write_url,
      'profile_image_url', s.profile_image_url
    ),
    'chart', jsonb_build_object(
      'id', c.id,
      'shop_id', c.shop_id,
      'visit_number', c.visit_number,
      'visit_date', c.visit_date,
      'created_at', c.created_at,
      'care_name', c.care_name,
      'treatment_summary', c.treatment_summary,
      'director_insight', c.director_insight,
      'home_care_prescriptions', c.home_care_prescriptions,
      'care_report_json', c.care_report_json,
      'care_report_generated_at', c.care_report_generated_at,
      'before_image_url', case when v_photos then c.before_image_url end,
      'after_image_url', case when v_photos then c.after_image_url end
    )
  );
end
$$;
comment on function public.get_care_report_by_token(text) is
  'SORI P0 M1 (D1): anon care report by token. Safe columns only, name masked (Q4), photos need consent_photo (Q6).';

-- D2 review link context (anon may open the link; submitting needs login).
create function public.get_review_context(p_token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  t      public.customer_access_tokens;
  c      public.customer_charts;
  s      public.shops;
  v_name text;
  v_rev  record;
  v_has  boolean;
begin
  t := public._resolve_customer_token(p_token, 'review');

  select * into c from public.customer_charts where id = t.chart_id;
  if not found or c.shop_id is distinct from t.shop_id then
    raise exception 'token_not_found' using errcode = 'PT404';
  end if;
  select * into s from public.shops where id = c.shop_id;
  select cu.name into v_name from public.customers cu where cu.id = c.customer_id;
  select r.status, r.rating into v_rev from public.customer_reviews r where r.chart_id = c.id;
  v_has := found;

  return jsonb_build_object(
    'kind', 'review',
    'expires_at', t.expires_at,
    'customer_display_name', public.mask_person_name(v_name),
    'shop', jsonb_build_object(
      'id', s.id,
      'name', s.name,
      'naver_place_url', s.naver_place_url,
      'naver_review_write_url', s.naver_review_write_url,
      'profile_image_url', s.profile_image_url
    ),
    'chart', jsonb_build_object(
      'id', c.id,
      'shop_id', c.shop_id,
      'visit_number', c.visit_number,
      'visit_date', c.visit_date,
      'care_name', c.care_name,
      'care_tags', coalesce(c.care_tags, '[]'::jsonb)
    ),
    'review', case when not v_has then null else jsonb_build_object(
      'status', v_rev.status,
      'rating', v_rev.rating,
      'editable', coalesce(v_rev.status, 'draft') in ('draft', 'editing')
    ) end
  );
end
$$;
comment on function public.get_review_context(text) is
  'SORI P0 M1 (D2): anon review-link context. No review text, no customer PII, name masked.';

-- D2 submit (login required, any logged-in customer holding the token).
create function public.submit_review_with_token(
  p_token text,
  p_rating integer,
  p_text text,
  p_puzzle jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  t          public.customer_access_tokens;
  c          public.customer_charts;
  v_text     text := btrim(coalesce(p_text, ''));
  v_puzzle   jsonb := coalesce(p_puzzle, '[]'::jsonb);
  v_existing public.customer_reviews;
  v_id       uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'login_required' using errcode = '42501';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'invalid_rating' using errcode = '22023';
  end if;
  if char_length(v_text) = 0 or char_length(v_text) > 2000 then
    raise exception 'invalid_text' using errcode = '22023';
  end if;
  if jsonb_typeof(v_puzzle) <> 'array' or jsonb_array_length(v_puzzle) > 50 then
    raise exception 'invalid_puzzle' using errcode = '22023';
  end if;

  t := public._resolve_customer_token(p_token, 'review');
  select * into c from public.customer_charts where id = t.chart_id;
  if not found or c.shop_id is distinct from t.shop_id then
    raise exception 'token_not_found' using errcode = 'PT404';
  end if;

  select * into v_existing from public.customer_reviews r where r.chart_id = c.id for update;
  if found then
    if coalesce(v_existing.status, 'draft') not in ('draft', 'editing') then
      raise exception 'already_submitted' using errcode = 'PT409';
    end if;
    update public.customer_reviews
       set rating = p_rating,
           original_text = v_text,
           content = v_text,
           puzzle_selections = v_puzzle,
           updated_at = now()
     where id = v_existing.id
    returning id into v_id;
  else
    insert into public.customer_reviews
      (chart_id, shop_id, customer_id, rating, original_text, content, puzzle_selections, status)
    values
      (c.id, c.shop_id, c.customer_id, p_rating, v_text, v_text, v_puzzle, 'draft')
    returning id into v_id;
  end if;
  return v_id;
end
$$;
comment on function public.submit_review_with_token(text, integer, text, jsonb) is
  'SORI P0 M1 (D2): logged-in customer submits/edits a draft review via review token.';

-- D3 care request lead (anon). Input validation + simple rate limits.
create function public.submit_care_request(
  p_shop_id uuid,
  p_name text,
  p_phone text,
  p_preferred_at timestamptz,
  p_care_label text default '',
  p_note text default ''
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_digits text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_name   text := btrim(coalesce(p_name, ''));
  v_id     uuid;
begin
  if p_shop_id is null or not exists (select 1 from public.shops s where s.id = p_shop_id) then
    raise exception 'shop_not_found' using errcode = 'PT404';
  end if;
  if char_length(v_name) not between 1 and 40
     or char_length(v_digits) not between 9 and 11
     or p_preferred_at is null
     or p_preferred_at not between now() - interval '1 day' and now() + interval '180 days'
     or char_length(coalesce(p_note, '')) > 500
     or char_length(coalesce(p_care_label, '')) > 80 then
    raise exception 'invalid_input' using errcode = '22023';
  end if;
  -- same phone: max 3 requests per shop per 10 minutes; any phone: max 30 per shop per hour
  if (select count(*) from public.care_schedule_entries e
       where e.shop_id = p_shop_id
         and e.source = 'customerLead'
         and regexp_replace(coalesce(e.customer_phone, ''), '\D', '', 'g') = v_digits
         and e.created_at > now() - interval '10 minutes') >= 3
     or (select count(*) from public.care_schedule_entries e
          where e.shop_id = p_shop_id
            and e.source = 'customerLead'
            and e.created_at > now() - interval '1 hour') >= 30 then
    raise exception 'too_many_requests' using errcode = 'PT429';
  end if;

  insert into public.care_schedule_entries
    (shop_id, customer_name, customer_phone, scheduled_at, care_label, note, source, status)
  values
    (p_shop_id, v_name, v_digits, p_preferred_at, btrim(coalesce(p_care_label, '')),
     btrim(coalesce(p_note, '')), 'customerLead', 'scheduled')
  returning id into v_id;
  return v_id;
end
$$;
comment on function public.submit_care_request(uuid, text, text, timestamptz, text, text) is
  'SORI P0 M1 (D3): anon care-request lead with validation and rate limit. Returns only the new id.';

-- D6 community shared cases (decision Q1: readable without login, marketing consent only).
-- Never returns signature_url / consent_pdf_url / review text (Q9) / treatment_summary.
-- Same key names as view community_shared_cases where possible; age is a decade band.
create function public.list_community_shared_cases(p_limit integer default 40, p_offset integer default 0)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(q.item order by q.created_at desc, q.chart_id), '[]'::jsonb)
    from (
      select c.created_at,
             c.id as chart_id,
             jsonb_build_object(
               'chart_id', c.id,
               'shop_id', c.shop_id,
               'visit_number', c.visit_number,
               'care_name', c.care_name,
               'concern_chips', coalesce(c.concern_chips, '[]'::jsonb),
               'care_tags', case
                              when jsonb_typeof(c.care_tags) = 'array' and jsonb_array_length(c.care_tags) > 0
                                then c.care_tags
                              else coalesce(c.concern_chips, '[]'::jsonb)
                            end,
               'before_image_url', nullif(btrim(coalesce(c.before_image_url, '')), ''),
               'after_image_url', nullif(btrim(coalesce(c.after_image_url, '')), ''),
               'created_at', c.created_at,
               'device_info', c.device_info,
               'skin_sensitivity', coalesce(c.skin_sensitivity, ''),
               'customer_age_band', case
                                      when cu.birth_date ~ '^\s*[0-9]{4}' then
                                        case
                                          when (extract(year from current_date)::int - substring(btrim(cu.birth_date) from 1 for 4)::int)
                                               between 10 and 99
                                            then (extract(year from current_date)::int - substring(btrim(cu.birth_date) from 1 for 4)::int) / 10 * 10
                                        end
                                    end,
               'customer_gender_label', case cu.gender when 'female' then '여성' when 'male' then '남성' end,
               'shop_owner_user_id', s.owner_user_id,
               'shop_name', s.name,
               'shop_owner_name', s.owner_name,
               'shop_profile_image_url', s.profile_image_url,
               'shop_naver_place_url', s.naver_place_url,
               'shop_naver_booking_url', coalesce(s.naver_booking_url, ''),
               'shop_tier_badge', coalesce(s.tier_badge::text, 'none'),
               'shop_is_official', coalesce(s.is_official, false),
               'shop_slug', coalesce(s.slug, ''),
               'author_user_id', coalesce(c.author_user_id, s.owner_user_id),
               'author_nickname', coalesce(nullif(btrim(c.author_nickname_snap), ''), nullif(btrim(ap.nickname), ''),
                                           nullif(btrim(ap.name), ''), nullif(btrim(s.owner_name), ''),
                                           nullif(btrim(s.name), ''), 'SORI'),
               'author_avatar_url', coalesce(nullif(btrim(ap.avatar_url), ''), ''),
               'review_rating', (select r.rating from public.customer_reviews r
                                  where r.chart_id = c.id
                                  order by coalesce(r.accepted_at, r.created_at) desc nulls last
                                  limit 1)
             ) as item
        from public.customer_charts c
        join public.shops s on s.id = c.shop_id
        left join public.customers cu on cu.id = c.customer_id
        left join public.profiles ap on ap.id = coalesce(c.author_user_id, s.owner_user_id)
       where c.is_case_shared = true
         and coalesce(c.consent_marketing, false)
         and (coalesce(btrim(c.signature_url), '') <> '' or coalesce(btrim(c.consent_pdf_url), '') <> '')
         and (coalesce(btrim(c.before_image_url), '') <> '' or coalesce(btrim(c.after_image_url), '') <> '')
       order by c.created_at desc, c.id
       limit greatest(1, least(coalesce(p_limit, 40), 100))
      offset greatest(0, least(coalesce(p_offset, 0), 10000))
    ) q;
$$;
comment on function public.list_community_shared_cases(integer, integer) is
  'SORI P0 M1 (D6): community shared cases with marketing consent only. No signature/consent PDF/review text.';

revoke all on function public.get_care_report_by_token(text) from public, anon, authenticated, service_role;
grant execute on function public.get_care_report_by_token(text) to anon, authenticated, service_role;
revoke all on function public.get_review_context(text) from public, anon, authenticated, service_role;
grant execute on function public.get_review_context(text) to anon, authenticated, service_role;
revoke all on function public.submit_review_with_token(text, integer, text, jsonb) from public, anon, authenticated, service_role;
grant execute on function public.submit_review_with_token(text, integer, text, jsonb) to authenticated;
revoke all on function public.submit_care_request(uuid, text, text, timestamptz, text, text) from public, anon, authenticated, service_role;
grant execute on function public.submit_care_request(uuid, text, text, timestamptz, text, text) to anon, authenticated, service_role;
revoke all on function public.list_community_shared_cases(integer, integer) from public, anon, authenticated, service_role;
grant execute on function public.list_community_shared_cases(integer, integer) to anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 5) Consent enforcement on customer_charts (plan section 4.3)
-- -----------------------------------------------------------------------------
create function public.enforce_case_share_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_publishable boolean;
  v_coerced     boolean := false;
begin
  v_publishable := coalesce(new.consent_marketing, false)
                   and coalesce(nullif(btrim(new.signature_url), ''), nullif(btrim(new.consent_pdf_url), '')) is not null;

  if (coalesce(new.is_case_shared, false) or coalesce(new.case_shared, false)) and not v_publishable then
    -- silently un-share instead of raising, so existing client saves never fail
    new.is_case_shared := false;
    new.case_shared := false;
    v_coerced := true;
  end if;

  if tg_op = 'UPDATE'
     and (v_coerced
          or (coalesce(old.consent_marketing, false) and not coalesce(new.consent_marketing, false))) then
    update public.community_posts p
       set status = 'hidden',
           updated_at = now()
     where p.source_chart_id = new.id
       and p.post_type = 'case_share'
       and p.status = 'published';
  end if;
  return new;
end
$$;
comment on function public.enforce_case_share_consent() is
  'SORI P0 M1: sharing requires marketing consent + signature/PDF; withdrawal hides case_share posts.';
revoke all on function public.enforce_case_share_consent() from public, anon, authenticated, service_role;

create trigger trg_enforce_case_share_consent
  before insert or update of is_case_shared, case_shared, consent_marketing, signature_url, consent_pdf_url
  on public.customer_charts
  for each row
  execute function public.enforce_case_share_consent();

-- -----------------------------------------------------------------------------
-- 6) shops protected columns (SECURITY INVOKER on purpose: current_user is the
--    API role; SECURITY DEFINER functions run as postgres and pass through).
-- -----------------------------------------------------------------------------
create function public.guard_shop_protected_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if current_user not in ('anon', 'authenticated') then
    return new;  -- service_role, postgres, supabase_admin, SECURITY DEFINER functions
  end if;

  if tg_op = 'INSERT' then
    if new.owner_user_id is not null and new.owner_user_id is distinct from v_uid then
      raise exception 'shop owner must be the current user' using errcode = '42501';
    end if;
    new.is_official       := false;
    new.tier_badge        := 'none'::public.shop_tier_badge;
    new.kakao_point       := 0;
    new.sori_cash_balance := 0;
    new.follower_count    := 0;
    new.shared_case_count := 0;
    return new;
  end if;

  -- UPDATE: owner_user_id
  if new.owner_user_id is distinct from old.owner_user_id then
    if old.owner_user_id is null then
      -- current onboarding (linkShopOwner on a fresh, ownerless shop) keeps working
      if coalesce(old.is_official, false) then
        raise exception 'official shop cannot be claimed' using errcode = '42501';  -- decision Q14
      end if;
      if v_uid is null or new.owner_user_id is distinct from v_uid then
        raise exception 'an ownerless shop can only be claimed for yourself' using errcode = '42501';
      end if;
    elsif v_uid is null or old.owner_user_id <> v_uid then
      raise exception 'owner change not allowed' using errcode = '42501';
    end if;
  end if;

  -- protected counters / flags: keep old values (no error, stale client upserts keep working)
  new.is_official       := old.is_official;
  new.tier_badge        := old.tier_badge;
  new.kakao_point       := old.kakao_point;
  new.sori_cash_balance := old.sori_cash_balance;
  new.follower_count    := old.follower_count;
  new.shared_case_count := old.shared_case_count;
  return new;
end
$$;
comment on function public.guard_shop_protected_columns() is
  'SORI P0 M1: client roles cannot take over shops or edit server-owned counters/flags.';
revoke all on function public.guard_shop_protected_columns() from public, anon, authenticated, service_role;

create trigger trg_guard_shop_protected_columns
  before insert or update
  on public.shops
  for each row
  execute function public.guard_shop_protected_columns();

-- make PostgREST see the new RPCs immediately
notify pgrst, 'reload schema';
