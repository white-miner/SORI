-- 091_whisper_publish_public_zero_recipients.sql
-- Harden send_whisper_post: 전체 공개(everyone) must never fail with P0001
-- when resolve_whisper_audience_users returns 0 rows (empty roster / solo author).

create or replace function public.can_view_whisper_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select
        p.is_whisper = true
        and p.status = 'published'
        and auth.uid() is not null
        and (
          p.author_user_id = auth.uid()
          or exists (
            select 1
            from public.community_whisper_recipients r
            where r.post_id = p.id and r.user_id = auth.uid()
          )
          or (
            p.visibility = 'public'
            and coalesce(p.audience_spec -> 'atoms', '[]'::jsonb) ? 'everyone'
          )
        )
      from public.community_posts p
      where p.id = p_post_id
    ),
    false
  );
$$;

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
  -- Normalize atom ids (trim, drop blanks).
  select coalesce(array_agg(distinct trim(a)), '{}'::text[])
  into v_atoms
  from unnest(coalesce(p_atoms, '{}'::text[])) as a
  where trim(a) <> '';

  v_has_everyone := 'everyone' = any (v_atoms);

  if v_uid is null then
    raise exception 'auth required';
  end if;
  if length(v_body) < 1 then
    raise exception 'body required';
  end if;
  if coalesce(array_length(v_atoms, 1), 0) < 1 then
    raise exception 'at least one audience atom required';
  end if;
  if v_op not in ('union', 'intersect') then
    v_op := 'union';
  end if;

  if v_shop is null then
    select s.id into v_shop
    from public.shops s
    where s.owner_user_id = v_uid
    order by s.created_at asc
    limit 1;
  end if;
  if v_shop is null
     or not exists (
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
    and p.is_whisper = true
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
  if v_full > v_max then
    v_truncated := true;
  end if;

  -- 전체 공개 → public visibility (home / community feed).
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
    shop_id,
    author_user_id,
    post_type,
    title,
    body,
    visibility,
    status,
    is_whisper,
    audience_spec,
    audience_op,
    whisper_recipient_count
  ) values (
    v_shop,
    v_uid,
    'case_share',
    '',
    v_body,
    v_visibility,
    'published',
    true,
    v_spec,
    v_op,
    0
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

  -- PO: 전체 공개는 수신자 0명이어도 Insert 유지. 타겟 지정만 실패.
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
    'is_public', v_has_everyone
  );
end;
$$;

comment on function public.send_whisper_post(text, text, text[], uuid[], uuid[], uuid, int) is
  'Publish whisper; everyone atom → public visibility, zero recipients allowed.';

grant execute on function public.send_whisper_post(text, text, text[], uuid[], uuid[], uuid, int)
  to authenticated;
