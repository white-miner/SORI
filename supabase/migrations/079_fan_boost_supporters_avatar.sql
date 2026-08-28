-- 079_fan_boost_supporters_avatar.sql
-- Facepile: join profiles.avatar_url for fan supporters.

drop function if exists public.list_fan_boost_supporters(text, uuid, int);
drop function if exists public.list_fan_boost_supporters_batch(text, uuid[], int);

create or replace function public.list_fan_boost_supporters(
  p_target_type text default 'chart',
  p_target_id uuid default null,
  p_limit int default 200
)
returns table (
  target_id uuid,
  paid_by_customer_id uuid,
  paid_by_wallet_id uuid,
  fan_display_name text,
  avatar_url text,
  echo_spent int,
  boost_count int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
begin
  if p_target_id is null then
    raise exception 'target_id required';
  end if;
  if v_type not in ('chart', 'community_post') then
    raise exception 'invalid target_type';
  end if;

  return query
  with agg as (
    select
      bp.paid_by_wallet_id as wid,
      (
        array_agg(bp.paid_by_customer_id order by bp.created_at desc)
          filter (where bp.paid_by_customer_id is not null)
      )[1] as cid,
      coalesce(
        nullif(
          trim((
            array_agg(bp.fan_display_name order by bp.created_at desc)
              filter (where nullif(trim(bp.fan_display_name), '') is not null)
          )[1]),
          ''
        ),
        '팬'
      ) as fname,
      sum(bp.points_spent)::int as spent,
      count(*)::int as cnt
    from public.boost_placements bp
    where bp.source = 'fan_boost'
      and bp.target_type = v_type
      and bp.target_id = p_target_id
      and bp.paid_by_wallet_id is not null
    group by bp.paid_by_wallet_id
  )
  select
    p_target_id,
    a.cid,
    a.wid,
    a.fname,
    coalesce(nullif(trim(p.avatar_url), ''), ''),
    a.spent,
    a.cnt
  from agg a
  left join public.customers c on c.id = a.cid
  left join public.profiles p on p.id = c.user_id
  order by a.spent desc, a.fname asc
  limit v_limit;
end;
$$;

comment on function public.list_fan_boost_supporters(text, uuid, int) is
  'Fan-Boost supporters for one chart/post, ranked by cumulative Echo spent.';

grant execute on function public.list_fan_boost_supporters(text, uuid, int)
  to anon, authenticated, service_role;

create or replace function public.list_fan_boost_supporters_batch(
  p_target_type text default 'chart',
  p_target_ids uuid[] default '{}',
  p_limit_per_target int default 50
)
returns table (
  target_id uuid,
  paid_by_customer_id uuid,
  paid_by_wallet_id uuid,
  fan_display_name text,
  avatar_url text,
  echo_spent int,
  boost_count int,
  rank_in_target int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := lower(trim(coalesce(p_target_type, 'chart')));
  v_per int := greatest(1, least(coalesce(p_limit_per_target, 50), 200));
begin
  if p_target_ids is null or cardinality(p_target_ids) = 0 then
    return;
  end if;
  if v_type not in ('chart', 'community_post') then
    raise exception 'invalid target_type';
  end if;

  return query
  with agg as (
    select
      bp.target_id as tid,
      bp.paid_by_wallet_id as wid,
      (
        array_agg(bp.paid_by_customer_id order by bp.created_at desc)
          filter (where bp.paid_by_customer_id is not null)
      )[1] as cid,
      coalesce(
        nullif(
          trim((
            array_agg(bp.fan_display_name order by bp.created_at desc)
              filter (where nullif(trim(bp.fan_display_name), '') is not null)
          )[1]),
          ''
        ),
        '팬'
      ) as fname,
      sum(bp.points_spent)::int as spent,
      count(*)::int as cnt
    from public.boost_placements bp
    where bp.source = 'fan_boost'
      and bp.target_type = v_type
      and bp.target_id = any (p_target_ids)
      and bp.paid_by_wallet_id is not null
    group by bp.target_id, bp.paid_by_wallet_id
  ),
  ranked as (
    select
      a.tid,
      a.cid,
      a.wid,
      a.fname,
      coalesce(nullif(trim(p.avatar_url), ''), '') as av,
      a.spent,
      a.cnt,
      row_number() over (
        partition by a.tid
        order by a.spent desc, a.fname asc
      )::int as rnk
    from agg a
    left join public.customers c on c.id = a.cid
    left join public.profiles p on p.id = c.user_id
  )
  select
    r.tid,
    r.cid,
    r.wid,
    r.fname,
    r.av,
    r.spent,
    r.cnt,
    r.rnk
  from ranked r
  where r.rnk <= v_per
  order by r.tid, r.rnk;
end;
$$;

comment on function public.list_fan_boost_supporters_batch(text, uuid[], int) is
  'Batch Fan-Boost supporter rankings for Home feed Facepile annotation.';

grant execute on function public.list_fan_boost_supporters_batch(text, uuid[], int)
  to anon, authenticated, service_role;
