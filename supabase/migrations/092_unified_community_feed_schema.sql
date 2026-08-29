-- 092_unified_community_feed_schema.sql
-- Unified Feed S1: post_type whisper normalize + federated view SSOT.

-- 1) Optional feed metadata on community_posts (post_tags already has metadata)
alter table public.community_posts
  add column if not exists feed_metadata jsonb not null default '{}'::jsonb;

comment on column public.community_posts.feed_metadata is
  'Denormalized feed-card payload; SSOT remains satellite tables.';

-- 2) post_type enum: add whisper (PO sign-off — overwrite legacy case_share whispers)
alter table public.community_posts
  drop constraint if exists community_posts_post_type_check;

alter table public.community_posts
  add constraint community_posts_post_type_check
  check (post_type in (
    'interior', 'device_review', 'marketplace',
    'case_share', 'seminar', 'whisper'
  ));

update public.community_posts
set post_type = 'whisper'
where coalesce(is_whisper, false) = true
  and post_type <> 'whisper';

-- 3) send_whisper_post — insert post_type = whisper (not case_share)
create or replace function public.send_whisper_post(
  p_body text,
  p_op text default 'union',
  p_atoms text[] default '{}',
  p_explicit_user_ids uuid[] default '{}',
  p_explicit_shop_ids uuid[] default '{}',
  p_shop_id uuid default null,
  p_max int default 500
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_op text := lower(trim(coalesce(p_op, 'union')));
  v_body text := left(trim(coalesce(p_body, '')), 2000);
  v_max int := greatest(1, least(coalesce(p_max, 500), 500));
  v_atoms text[];
  v_post_id uuid;
  v_count int := 0;
  v_full int := 0;
  v_truncated boolean := false;
  v_day_count int;
  v_spec jsonb;
  v_has_everyone boolean;
  v_visibility text;
begin
  select coalesce(array_agg(distinct trim(a)), '{}'::text[])
  into v_atoms
  from unnest(coalesce(p_atoms, '{}'::text[])) as a
  where trim(a) <> '';

  v_has_everyone := 'everyone' = any (v_atoms);

  if v_uid is null then raise exception 'auth required'; end if;
  if length(v_body) < 1 then raise exception 'body required'; end if;
  if coalesce(array_length(v_atoms, 1), 0) < 1 then
    raise exception 'at least one audience atom required';
  end if;
  if v_op not in ('union', 'intersect') then v_op := 'union'; end if;

  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;
  if v_shop is null or not exists (
    select 1 from public.shops s
    where s.id = v_shop
      and (
        s.owner_user_id = v_uid
        or exists (
          select 1 from public.shop_memberships m
          where m.shop_id = s.id and m.user_id = v_uid
        )
      )
  ) then
    raise exception 'shop access denied';
  end if;

  select count(*)::int into v_day_count
  from public.community_posts p
  where p.author_user_id = v_uid
    and coalesce(p.is_whisper, false) = true
    and p.status = 'published'
    and p.created_at > now() - interval '1 day';
  if coalesce(v_day_count, 0) >= 20 then
    raise exception 'daily whisper limit reached';
  end if;

  select count(*)::int into v_full
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, v_op, v_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, 501
  );
  if v_full > v_max then v_truncated := true; end if;

  v_visibility := case when v_has_everyone then 'public' else 'directors_only' end;

  v_spec := jsonb_build_object(
    'op', v_op,
    'atoms', to_jsonb(v_atoms),
    'explicit_user_ids', to_jsonb(coalesce(p_explicit_user_ids, '{}'::uuid[])),
    'explicit_shop_ids', to_jsonb(coalesce(p_explicit_shop_ids, '{}'::uuid[])),
    'shop_id', v_shop,
    'is_public', v_has_everyone,
    'caps', jsonb_build_object('max_recipients', v_max)
  );

  insert into public.community_posts (
    shop_id, author_user_id, post_type, title, body,
    visibility, status, is_whisper, audience_spec, audience_op,
    whisper_recipient_count, feed_metadata
  ) values (
    v_shop, v_uid, 'whisper', '', v_body,
    v_visibility, 'published', true, v_spec, v_op,
    0, jsonb_build_object('is_public', v_has_everyone)
  )
  returning id into v_post_id;

  insert into public.community_whisper_recipients (post_id, user_id, atom_bits)
  select v_post_id, r.user_id, r.atom_bits
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, v_op, v_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, v_max
  ) r
  on conflict (post_id, user_id) do nothing;

  get diagnostics v_count = row_count;

  if v_count < 1 and not v_has_everyone then
    delete from public.community_posts where id = v_post_id;
    raise exception 'no recipients matched';
  end if;

  update public.community_posts
  set whisper_recipient_count = v_count, updated_at = now()
  where id = v_post_id;

  return jsonb_build_object(
    'ok', true,
    'post_id', v_post_id,
    'whisper_id', v_post_id,
    'recipient_count', v_count,
    'truncated', v_truncated,
    'op', v_op,
    'atoms', to_jsonb(v_atoms),
    'visibility', v_visibility,
    'is_public', v_has_everyone,
    'post_type', 'whisper'
  );
end;
$$;

-- 4) Federated read model (recency sort_at only — no like/comment score)
create or replace view public.unified_feed_items_v1 as
  select
    p.id::text as feed_id,
    case
      when p.post_type = 'whisper' or coalesce(p.is_whisper, false) then 'whisper'
      else p.post_type
    end as feed_kind,
    p.shop_id,
    p.author_user_id,
    p.created_at as sort_at,
    p.id as source_post_id,
    null::uuid as source_chart_id,
    null::uuid as source_seminar_id,
    coalesce(p.feed_metadata, '{}'::jsonb) as feed_metadata,
    p.visibility,
    coalesce(p.is_whisper, false) as is_whisper
  from public.community_posts p
  where p.status = 'published'
    and (
      coalesce(p.is_whisper, false) = false
      or public.can_view_whisper_post(p.id)
    )

  union all

  select
    sc.id::text as feed_id,
    'seminar'::text as feed_kind,
    sc.director_shop_id as shop_id,
    null::uuid as author_user_id,
    coalesce(sc.created_at, sc.event_date, now()) as sort_at,
    null::uuid as source_post_id,
    null::uuid as source_chart_id,
    sc.id as source_seminar_id,
    jsonb_build_object('title', sc.title, 'status', sc.status) as feed_metadata,
    'public'::text as visibility,
    false as is_whisper
  from public.seminar_classes sc
  where sc.status in ('open', 'held')

  union all

  select
    c.id::text as feed_id,
    'ba'::text as feed_kind,
    c.shop_id,
    s.owner_user_id as author_user_id,
    c.created_at as sort_at,
    null::uuid as source_post_id,
    c.id as source_chart_id,
    null::uuid as source_seminar_id,
    '{}'::jsonb as feed_metadata,
    'public'::text as visibility,
    false as is_whisper
  from public.customer_charts c
  join public.shops s on s.id = c.shop_id
  where coalesce(c.is_case_shared, false) = true;

comment on view public.unified_feed_items_v1 is
  'Unified community feed federated rows — community_posts + seminar + B/A.';

create index if not exists idx_community_posts_unified_recency
  on public.community_posts (created_at desc)
  where status = 'published';
