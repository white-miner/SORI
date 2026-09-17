-- 068_whisper_everyone_atom.sql
-- Add `everyone` atom for Whisper community posts.
-- Keeps union/intersect compatibility, but UI now uses union-only chips.

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
  v_has_everyone boolean := 'everyone' = any (p_atoms);
  v_has_visited boolean := 'visited' = any (p_atoms);
  v_has_followers boolean := 'followers' = any (p_atoms);
  v_has_peers boolean := 'peer_directors' = any (p_atoms);
  v_has_super boolean := 'super_fans' = any (p_atoms);
  v_has_explicit boolean := 'explicit' = any (p_atoms);
  v_has_seminar_hosts boolean := 'seminar_hosts' = any (p_atoms);
  v_has_customer_mode boolean := 'customer_mode' = any (p_atoms);
begin
  if v_op not in ('union', 'intersect') then
    v_op := 'union';
  end if;

  return query
  with
  a0 as (
    select p.id as uid, 32 as bits
    from public.profiles p
    where v_has_everyone
      and p.id <> p_sender
      and p.role in ('director', 'customer')
  ),
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
  a6 as (
    select distinct sm.user_id as uid, 64 as bits
    from public.shop_memberships sm
    join public.seminar_classes sc on sc.director_shop_id = sm.shop_id
    where v_has_seminar_hosts
      and sm.user_id <> p_sender
      and sm.is_public = true
      and sc.status in ('open', 'held', 'completed')
  ),
  a7 as (
    select distinct p.id as uid, 128 as bits
    from public.profiles p
    where v_has_customer_mode
      and p.id <> p_sender
      and p.role = 'customer'
  ),
  atoms as (
    select * from a0
    union all select * from a1
    union all select * from a2
    union all select * from a3
    union all select * from a4
    union all select * from a5
    union all select * from a6
    union all select * from a7
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
            (not v_has_everyone or (m.bits & 32) <> 0)
            and (not v_has_visited or (m.bits & 1) <> 0)
            and (not v_has_followers or (m.bits & 2) <> 0)
            and (not v_has_peers or (m.bits & 4) <> 0)
            and (not v_has_super or (m.bits & 8) <> 0)
            and (not v_has_explicit or (m.bits & 16) <> 0)
            and (not v_has_seminar_hosts or (m.bits & 64) <> 0)
            and (not v_has_customer_mode or (m.bits & 128) <> 0)
            and (
              (v_has_everyone or v_has_visited or v_has_followers or v_has_peers
               or v_has_super or v_has_explicit or v_has_seminar_hosts or v_has_customer_mode)
            )
          )
        else true
      end
  )
  select f.uid, f.bits
  from filtered f
  order by
    (f.bits & 32) desc,
    (f.bits & 8) desc,
    (f.bits & 4) desc,
    f.uid
  limit v_max;
end;
$$;

comment on function public.resolve_whisper_audience_users(uuid, uuid, text, text[], uuid[], uuid[], int) is
  'Resolve Whisper audience atoms. Supports everyone(32), visited(1), followers(2), peer_directors(4), super_fans(8), explicit(16), seminar_hosts(64), customer_mode(128).';
