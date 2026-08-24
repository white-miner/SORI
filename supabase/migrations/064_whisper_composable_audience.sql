-- 064_whisper_composable_audience.sql
-- Whisper Inbox: composable audience, materialize at send, strict RLS.
-- Independent from community_posts / Home feed.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) Tables
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.whispers (
  id uuid primary key default gen_random_uuid(),
  sender_user_id uuid not null references public.profiles (id) on delete cascade,
  shop_id uuid references public.shops (id) on delete set null,
  body text not null default '',
  audience_spec jsonb not null default '{}'::jsonb,
  audience_op text not null default 'union'
    check (audience_op in ('union', 'intersect')),
  recipient_count int not null default 0 check (recipient_count >= 0),
  truncated boolean not null default false,
  status text not null default 'sent'
    check (status in ('draft', 'sent', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists whispers_sender_created_idx
  on public.whispers (sender_user_id, created_at desc)
  where status = 'sent';

create index if not exists whispers_shop_created_idx
  on public.whispers (shop_id, created_at desc)
  where shop_id is not null and status = 'sent';

comment on table public.whispers is
  'Phase 12 Whisper Inbox — sender-first sealed messages. Not community_posts.';

create table if not exists public.whisper_recipients (
  id uuid primary key default gen_random_uuid(),
  whisper_id uuid not null references public.whispers (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  atom_bits int not null default 0,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (whisper_id, user_id)
);

create index if not exists whisper_recipients_user_unread_idx
  on public.whisper_recipients (user_id, created_at desc)
  where read_at is null;

create index if not exists whisper_recipients_whisper_idx
  on public.whisper_recipients (whisper_id);

comment on table public.whisper_recipients is
  'Materialized audience snapshot at send. atom_bits: A1=1 A2=2 A3=4 A4=8 A5=16.';

create table if not exists public.whisper_audience_presets (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles (id) on delete cascade,
  shop_id uuid references public.shops (id) on delete set null,
  name text not null default '',
  audience_spec jsonb not null default '{}'::jsonb,
  audience_op text not null default 'union'
    check (audience_op in ('union', 'intersect')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists whisper_presets_owner_idx
  on public.whisper_audience_presets (owner_user_id, updated_at desc);

comment on table public.whisper_audience_presets is
  'Saved composable audience groups for directors.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) RLS — extreme privacy
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.whispers enable row level security;
alter table public.whisper_recipients enable row level security;
alter table public.whisper_audience_presets enable row level security;

drop policy if exists whispers_select_participant on public.whispers;
create policy whispers_select_participant
  on public.whispers for select
  using (
    status = 'sent'
    and (
      sender_user_id = auth.uid()
      or exists (
        select 1 from public.whisper_recipients r
        where r.whisper_id = id and r.user_id = auth.uid()
      )
    )
  );

drop policy if exists whispers_no_direct_write on public.whispers;
-- Writes only via security definer RPCs (no insert/update/delete policies for clients)

drop policy if exists whisper_recipients_select_own on public.whisper_recipients;
create policy whisper_recipients_select_own
  on public.whisper_recipients for select
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.whispers w
      where w.id = whisper_id and w.sender_user_id = auth.uid()
    )
  );

drop policy if exists whisper_presets_owner_all on public.whisper_audience_presets;
create policy whisper_presets_owner_all
  on public.whisper_audience_presets for all
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

grant select on public.whispers to authenticated;
grant select on public.whisper_recipients to authenticated;
grant select, insert, update, delete on public.whisper_audience_presets to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) resolve audience (internal helper)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.resolve_whisper_audience_users(
  p_sender uuid,
  p_shop_id uuid,
  p_op text,
  p_atoms text[],
  p_explicit_user_ids uuid[] default '{}',
  p_explicit_shop_ids uuid[] default '{}',
  p_max int default 500
)
returns table (user_id uuid, atom_bits int)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_op text := lower(trim(coalesce(p_op, 'union')));
  v_max int := greatest(1, least(coalesce(p_max, 500), 500));
  v_has_visited boolean := 'visited' = any (p_atoms);
  v_has_followers boolean := 'followers' = any (p_atoms);
  v_has_peers boolean := 'peer_directors' = any (p_atoms);
  v_has_super boolean := 'super_fans' = any (p_atoms);
  v_has_explicit boolean := 'explicit' = any (p_atoms);
begin
  if v_op not in ('union', 'intersect') then
    v_op := 'union';
  end if;

  return query
  with
  a1 as (
    select distinct c.user_id as uid, 1 as bits
    from public.customers c
    where v_has_visited
      and p_shop_id is not null
      and c.shop_id = p_shop_id
      and c.user_id is not null
      and c.user_id <> p_sender
  ),
  a2 as (
    select distinct s.follower_user_id as uid, 2 as bits
    from public.subscriptions s
    where v_has_followers
      and s.follower_user_id <> p_sender
      and (
        (s.target_type = 'shop' and s.target_shop_id = p_shop_id)
        or (s.target_type = 'director' and s.target_user_id = p_sender)
      )
  ),
  a3 as (
    select distinct s.follower_user_id as uid, 4 as bits
    from public.subscriptions s
    join public.profiles p on p.id = s.follower_user_id
    where v_has_peers
      and s.follower_user_id <> p_sender
      and p.role = 'director'
      and (
        (s.target_type = 'shop' and s.target_shop_id = p_shop_id)
        or (s.target_type = 'director' and s.target_user_id = p_sender)
      )
  ),
  a4 as (
    select distinct c.user_id as uid, 8 as bits
    from public.boost_placements bp
    join public.customers c on c.id = bp.paid_by_customer_id
    where v_has_super
      and bp.source = 'fan_boost'
      and bp.created_at > now() - interval '90 days'
      and c.user_id is not null
      and c.user_id <> p_sender
      and (
        bp.shop_id = p_shop_id
        or exists (
          select 1 from public.customer_charts cc
          where cc.id = bp.chart_id and cc.shop_id = p_shop_id
        )
      )
  ),
  a5 as (
    select distinct x.uid, 16 as bits
    from (
      select unnest(coalesce(p_explicit_user_ids, '{}'::uuid[])) as uid
      where v_has_explicit
      union
      select m.user_id
      from public.shop_memberships m
      where v_has_explicit
        and m.is_public = true
        and m.shop_id = any (coalesce(p_explicit_shop_ids, '{}'::uuid[]))
    ) x
    where x.uid is not null and x.uid <> p_sender
  ),
  atoms as (
    select * from a1
    union all select * from a2
    union all select * from a3
    union all select * from a4
    union all select * from a5
  ),
  merged as (
    select a.uid, bit_or(a.bits)::int as bits
    from atoms a
    group by a.uid
  ),
  filtered as (
    select m.uid, m.bits
    from merged m
    where
      case
        when v_op = 'intersect' then
          (
            (not v_has_visited or (m.bits & 1) <> 0)
            and (not v_has_followers or (m.bits & 2) <> 0)
            and (not v_has_peers or (m.bits & 4) <> 0)
            and (not v_has_super or (m.bits & 8) <> 0)
            and (not v_has_explicit or (m.bits & 16) <> 0)
            and (
              (v_has_visited or v_has_followers or v_has_peers
               or v_has_super or v_has_explicit)
            )
          )
        else true
      end
  )
  select f.uid, f.bits
  from filtered f
  order by
    (f.bits & 8) desc,
    (f.bits & 4) desc,
    f.uid
  limit v_max;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) preview + send RPCs
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.preview_whisper_audience(
  p_shop_id uuid default null,
  p_op text default 'union',
  p_atoms text[] default '{}',
  p_explicit_user_ids uuid[] default '{}',
  p_explicit_shop_ids uuid[] default '{}',
  p_max int default 500
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_shop uuid := p_shop_id;
  v_count int;
  v_preview jsonb;
begin
  if v_uid is null then
    raise exception 'auth required';
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

  select count(*)::int into v_count
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, p_op, p_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, p_max
  );

  select coalesce(jsonb_agg(row_data), '[]'::jsonb) into v_preview
  from (
    select jsonb_build_object(
      'user_id', r.user_id,
      'atom_bits', r.atom_bits,
      'nickname', coalesce(
        nullif(trim(p.nickname), ''),
        nullif(trim(p.name), ''),
        'SORI'
      ),
      'avatar_url', coalesce(p.avatar_url, '')
    ) as row_data
    from public.resolve_whisper_audience_users(
      v_uid, v_shop, p_op, p_atoms,
      p_explicit_user_ids, p_explicit_shop_ids, least(12, p_max)
    ) r
    left join public.profiles p on p.id = r.user_id
  ) q;

  return jsonb_build_object(
    'ok', true,
    'count', coalesce(v_count, 0),
    'preview', coalesce(v_preview, '[]'::jsonb),
    'op', lower(trim(coalesce(p_op, 'union'))),
    'atoms', to_jsonb(coalesce(p_atoms, '{}'::text[]))
  );
end;
$$;

create or replace function public.send_whisper(
  p_body text,
  p_shop_id uuid default null,
  p_op text default 'union',
  p_atoms text[] default '{}',
  p_explicit_user_ids uuid[] default '{}',
  p_explicit_shop_ids uuid[] default '{}',
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
  v_whisper_id uuid;
  v_count int := 0;
  v_full int := 0;
  v_truncated boolean := false;
  v_day_count int;
  v_spec jsonb;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if length(v_body) < 1 then
    raise exception 'body required';
  end if;
  if coalesce(array_length(p_atoms, 1), 0) < 1 then
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
  from public.whispers w
  where w.sender_user_id = v_uid
    and w.status = 'sent'
    and w.created_at > now() - interval '1 day';
  if coalesce(v_day_count, 0) >= 20 then
    raise exception 'daily whisper limit reached';
  end if;

  select count(*)::int into v_full
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, v_op, p_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, 501
  );
  if v_full > v_max then
    v_truncated := true;
  end if;

  v_spec := jsonb_build_object(
    'op', v_op,
    'atoms', to_jsonb(p_atoms),
    'explicit_user_ids', to_jsonb(coalesce(p_explicit_user_ids, '{}'::uuid[])),
    'explicit_shop_ids', to_jsonb(coalesce(p_explicit_shop_ids, '{}'::uuid[])),
    'shop_id', v_shop,
    'caps', jsonb_build_object('max_recipients', v_max)
  );

  insert into public.whispers (
    sender_user_id, shop_id, body, audience_spec, audience_op,
    recipient_count, truncated, status
  ) values (
    v_uid, v_shop, v_body, v_spec, v_op, 0, v_truncated, 'sent'
  )
  returning id into v_whisper_id;

  insert into public.whisper_recipients (whisper_id, user_id, atom_bits)
  select v_whisper_id, r.user_id, r.atom_bits
  from public.resolve_whisper_audience_users(
    v_uid, v_shop, v_op, p_atoms,
    p_explicit_user_ids, p_explicit_shop_ids, v_max
  ) r
  on conflict (whisper_id, user_id) do nothing;

  get diagnostics v_count = row_count;

  if v_count < 1 then
    update public.whispers set status = 'deleted', updated_at = now()
    where id = v_whisper_id;
    raise exception 'no recipients matched';
  end if;

  update public.whispers
  set recipient_count = v_count, updated_at = now()
  where id = v_whisper_id;

  return jsonb_build_object(
    'ok', true,
    'whisper_id', v_whisper_id,
    'recipient_count', v_count,
    'truncated', v_truncated,
    'op', v_op,
    'atoms', to_jsonb(p_atoms)
  );
end;
$$;

create or replace function public.list_my_whispers(
  p_box text default 'inbox',
  p_limit int default 40
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_box text := lower(trim(coalesce(p_box, 'inbox')));
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;

  if v_box = 'sent' then
    return coalesce((
      select jsonb_agg(row_data order by sort_at desc)
      from (
        select
          w.created_at as sort_at,
          jsonb_build_object(
            'id', w.id,
            'body', w.body,
            'audience_spec', w.audience_spec,
            'audience_op', w.audience_op,
            'recipient_count', w.recipient_count,
            'truncated', w.truncated,
            'created_at', w.created_at,
            'box', 'sent',
            'read_at', null,
            'sender_user_id', w.sender_user_id,
            'sender_nickname', coalesce(
              nullif(trim(sp.nickname), ''),
              nullif(trim(sp.name), ''),
              '나'
            )
          ) as row_data
        from public.whispers w
        left join public.profiles sp on sp.id = w.sender_user_id
        where w.sender_user_id = v_uid and w.status = 'sent'
        order by w.created_at desc
        limit v_limit
      ) q
    ), '[]'::jsonb);
  end if;

  return coalesce((
    select jsonb_agg(row_data order by sort_at desc)
    from (
      select
        w.created_at as sort_at,
        jsonb_build_object(
          'id', w.id,
          'body', w.body,
          'audience_spec', w.audience_spec,
          'audience_op', w.audience_op,
          'recipient_count', w.recipient_count,
          'truncated', w.truncated,
          'created_at', w.created_at,
          'box', 'inbox',
          'read_at', r.read_at,
          'sender_user_id', w.sender_user_id,
          'sender_nickname', coalesce(
            nullif(trim(sp.nickname), ''),
            nullif(trim(sp.name), ''),
            '원장'
          ),
          'sender_avatar_url', coalesce(sp.avatar_url, '')
        ) as row_data
      from public.whisper_recipients r
      join public.whispers w on w.id = r.whisper_id
      left join public.profiles sp on sp.id = w.sender_user_id
      where r.user_id = v_uid and w.status = 'sent'
      order by w.created_at desc
      limit v_limit
    ) q
  ), '[]'::jsonb);
end;
$$;

create or replace function public.mark_whisper_read(p_whisper_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  update public.whisper_recipients
  set read_at = coalesce(read_at, now())
  where whisper_id = p_whisper_id and user_id = v_uid;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.count_unread_whispers()
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_n int;
begin
  if v_uid is null then
    return 0;
  end if;
  select count(*)::int into v_n
  from public.whisper_recipients r
  join public.whispers w on w.id = r.whisper_id
  where r.user_id = v_uid and r.read_at is null and w.status = 'sent';
  return coalesce(v_n, 0);
end;
$$;

grant execute on function public.resolve_whisper_audience_users(uuid, uuid, text, text[], uuid[], uuid[], int)
  to service_role;
grant execute on function public.preview_whisper_audience(uuid, text, text[], uuid[], uuid[], int)
  to authenticated;
grant execute on function public.send_whisper(text, uuid, text, text[], uuid[], uuid[], int)
  to authenticated;
grant execute on function public.list_my_whispers(text, int)
  to authenticated;
grant execute on function public.mark_whisper_read(uuid)
  to authenticated;
grant execute on function public.count_unread_whispers()
  to authenticated;
