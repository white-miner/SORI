-- 059_feed_algorithm.sql
-- Scale-up Ad Inventory: scoring + 4:1 interleave + seeded shuffle.
-- Segments: case | interior | device_review (isolated pools).

-- ── helpers ───────────────────────────────────────────────────────────────

create or replace function public.feed_viewer_seed(
  p_viewer_id text default '',
  p_segment text default 'case',
  p_at timestamptz default now()
)
returns text
language sql
stable
as $$
  select concat_ws(
    '|',
    nullif(trim(coalesce(p_viewer_id, '')), ''),
    lower(trim(coalesce(p_segment, 'case'))),
    (floor(extract(epoch from coalesce(p_at, now())) / 3600))::text
  );
$$;

create or replace function public.boost_feed_segment(
  p_target_type text,
  p_target_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_type text := lower(trim(coalesce(p_target_type, '')));
  v_post text;
begin
  if v_type = 'chart' then
    return 'case';
  end if;
  if v_type = 'community_post' and p_target_id is not null then
    select lower(trim(post_type)) into v_post
    from public.community_posts
    where id = p_target_id;
    if v_post in ('interior', 'device_review') then
      return v_post;
    end if;
    if v_post = 'case_share' then
      return 'case';
    end if;
  end if;
  return 'case';
end;
$$;

-- Deterministic shuffle key (0..1) from seed + id
create or replace function public.feed_seed_rank(
  p_seed text,
  p_id text
)
returns double precision
language sql
immutable
as $$
  select abs(('x' || substr(md5(coalesce(p_seed, '') || ':' || coalesce(p_id, '')), 1, 8))::bit(32)::int
    / 2147483647.0::double precision);
$$;

-- ── scored candidates ─────────────────────────────────────────────────────

create or replace function public.list_boost_candidates_scored(
  p_segment text default 'case',
  p_limit int default 200
)
returns table (
  placement_id uuid,
  target_type text,
  target_id uuid,
  source text,
  points_spent int,
  starts_at timestamptz,
  ends_at timestamptz,
  fandom_echo int,
  paid_ratio numeric,
  recency numeric,
  fan_bonus numeric,
  score numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_seg text := lower(trim(coalesce(p_segment, 'case')));
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
  v_tau double precision := 12.0; -- hours
begin
  perform public.expire_stale_boost_placements();

  return query
  with active as (
    select bp.*
    from public.boost_placements bp
    where bp.status = 'active'
      and bp.ends_at > now()
      and public.boost_feed_segment(bp.target_type, bp.target_id) = v_seg
  ),
  fandom as (
    select
      bp.target_type,
      bp.target_id,
      sum(bp.points_spent)::int as echo_sum
    from public.boost_placements bp
    where bp.source = 'fan_boost'
    group by bp.target_type, bp.target_id
  )
  select
    a.id,
    a.target_type,
    a.target_id,
    a.source,
    a.points_spent,
    a.starts_at,
    a.ends_at,
    coalesce(f.echo_sum, 0)::int as fandom_echo,
    -- Paid prior: fan_boost slightly higher until ledger split is wired
    (case when a.source = 'fan_boost' then 0.85 else 0.55 end)::numeric
      as paid_ratio,
    (exp(
      - greatest(0, extract(epoch from (now() - a.starts_at)) / 3600.0) / v_tau
    ))::numeric as recency,
    (case when a.source = 'fan_boost' then 1.0 else 0.45 end)::numeric
      as fan_bonus,
    (
      0.40 * least(
        1.0,
        ln(1 + coalesce(f.echo_sum, 0)::double precision) / ln(1 + 5000)
      )
      + 0.25 * (case when a.source = 'fan_boost' then 0.85 else 0.55 end)
      + 0.20 * exp(
        - greatest(0, extract(epoch from (now() - a.starts_at)) / 3600.0) / v_tau
      )
      + 0.15 * (case when a.source = 'fan_boost' then 1.0 else 0.45 end)
    )::numeric as score
  from active a
  left join fandom f
    on f.target_type = a.target_type
   and f.target_id = a.target_id
  order by score desc, a.starts_at desc
  limit v_limit;
end;
$$;

comment on function public.list_boost_candidates_scored(text, int) is
  'Active boost candidates for a feed segment, ranked by Fandom+Paid+Recency+FanBonus.';

-- ── pick slots with seeded shuffle of top pool ────────────────────────────

create or replace function public.pick_boost_slot_targets(
  p_segment text default 'case',
  p_slot_count int default 4,
  p_viewer_seed text default '',
  p_pool_size int default 40
)
returns table (
  target_id uuid,
  placement_id uuid,
  score numeric,
  slot_rank int
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_slots int := greatest(0, least(coalesce(p_slot_count, 4), 20));
  v_pool int := greatest(1, least(coalesce(p_pool_size, 40), 200));
  v_seed text := coalesce(nullif(trim(p_viewer_seed), ''), public.feed_viewer_seed('', p_segment));
begin
  if v_slots = 0 then
    return;
  end if;

  return query
  with scored as (
    select *
    from public.list_boost_candidates_scored(p_segment, v_pool)
  ),
  shuffled as (
    select
      s.target_id,
      s.placement_id,
      s.score,
      row_number() over (
        order by public.feed_seed_rank(v_seed, s.placement_id::text),
                 s.score desc
      ) as rn
    from scored s
  )
  select
    sh.target_id,
    sh.placement_id,
    sh.score,
    sh.rn::int
  from shuffled sh
  where sh.rn <= v_slots
  order by sh.rn;
end;
$$;

-- ── interleaved id page (organic ids supplied by caller OR auto for case) ─

create or replace function public.get_interleaved_feed_ids(
  p_segment text default 'case',
  p_organic_ids uuid[] default '{}',
  p_limit int default 20,
  p_offset int default 0,
  p_viewer_seed text default '',
  p_boost_every int default 5
)
returns table (
  target_id uuid,
  is_boost boolean,
  position int,
  score numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_seg text := lower(trim(coalesce(p_segment, 'case')));
  v_limit int := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_every int := greatest(2, least(coalesce(p_boost_every, 5), 20));
  v_seed text := coalesce(
    nullif(trim(p_viewer_seed), ''),
    public.feed_viewer_seed('', v_seg)
  );
  v_slots int;
  v_need int;
  v_organic uuid[];
  v_boost uuid[];
  v_boost_scores numeric[];
  v_out_ids uuid[] := '{}';
  v_out_boost boolean[] := '{}';
  v_out_score numeric[] := '{}';
  v_oi int := 1;
  v_bi int := 1;
  v_i int := 0;
  v_id uuid;
  v_is_b boolean;
  v_sc numeric;
  v_start int;
  v_end int;
  v_pos int;
begin
  v_need := v_offset + v_limit;
  v_slots := greatest(1, (v_need / v_every) + 2);

  -- Organic: caller list, or case segment from shared view / charts
  if p_organic_ids is not null and cardinality(p_organic_ids) > 0 then
    v_organic := p_organic_ids;
  elsif v_seg = 'case' then
    begin
      select coalesce(array_agg(c.chart_id order by c.created_at desc), '{}')
      into v_organic
      from (
        select chart_id, created_at
        from public.community_shared_cases
        order by created_at desc
        limit 500
      ) c;
    exception when undefined_table then
      select coalesce(array_agg(x.id order by x.created_at desc), '{}')
      into v_organic
      from (
        select id, created_at
        from public.customer_charts
        where coalesce(is_case_shared, false) = true
        order by created_at desc
        limit 500
      ) x;
    end;
  elsif v_seg in ('interior', 'device_review') then
    select coalesce(array_agg(p.id order by p.created_at desc), '{}')
    into v_organic
    from (
      select id, created_at
      from public.community_posts
      where post_type = v_seg
      order by created_at desc
      limit 500
    ) p;
  else
    v_organic := '{}';
  end if;

  select
    coalesce(array_agg(t.target_id order by t.slot_rank), '{}'),
    coalesce(array_agg(t.score order by t.slot_rank), '{}')
  into v_boost, v_boost_scores
  from public.pick_boost_slot_targets(v_seg, v_slots, v_seed, 40) t;

  -- Build interleaved stream (no boost dump when organic exhausted)
  while coalesce(array_length(v_out_ids, 1), 0) < v_need
    and (
      v_oi <= coalesce(array_length(v_organic, 1), 0)
      or v_bi <= coalesce(array_length(v_boost, 1), 0)
    )
  loop
    v_is_b := false;
    v_sc := 0;
    if (v_i % v_every = 0)
       and v_bi <= coalesce(array_length(v_boost, 1), 0) then
      v_id := v_boost[v_bi];
      v_sc := v_boost_scores[v_bi];
      v_bi := v_bi + 1;
      v_is_b := true;
      if v_id = any (v_out_ids) then
        v_i := v_i + 1;
        continue;
      end if;
      v_out_ids := v_out_ids || v_id;
      v_out_boost := v_out_boost || v_is_b;
      v_out_score := v_out_score || v_sc;
      v_i := v_i + 1;
      continue;
    end if;

    if v_oi <= coalesce(array_length(v_organic, 1), 0) then
      v_id := v_organic[v_oi];
      v_oi := v_oi + 1;
      if v_id = any (v_boost) or v_id = any (v_out_ids) then
        continue;
      end if;
      v_out_ids := v_out_ids || v_id;
      v_out_boost := v_out_boost || false;
      v_out_score := v_out_score || 0::numeric;
      v_i := v_i + 1;
      continue;
    end if;

    -- Organic exhausted: only place remaining boosts on boost indices
    if v_bi <= coalesce(array_length(v_boost, 1), 0) then
      if (v_i % v_every = 0) then
        v_id := v_boost[v_bi];
        v_sc := v_boost_scores[v_bi];
        v_bi := v_bi + 1;
        if not (v_id = any (v_out_ids)) then
          v_out_ids := v_out_ids || v_id;
          v_out_boost := v_out_boost || true;
          v_out_score := v_out_score || v_sc;
        end if;
      end if;
      v_i := v_i + 1;
      continue;
    end if;

    exit;
  end loop;

  v_start := v_offset + 1;
  v_end := least(
    coalesce(array_length(v_out_ids, 1), 0),
    v_offset + v_limit
  );

  if v_end < v_start then
    return;
  end if;

  for v_pos in v_start..v_end loop
    target_id := v_out_ids[v_pos];
    is_boost := v_out_boost[v_pos];
    position := v_pos - 1;
    score := v_out_score[v_pos];
    return next;
  end loop;
end;
$$;

-- Convenience aliases
create or replace function public.get_home_feed(
  p_limit int default 20,
  p_offset int default 0,
  p_viewer_seed text default ''
)
returns table (
  target_id uuid,
  is_boost boolean,
  position int,
  score numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select * from public.get_interleaved_feed_ids(
    'case', '{}', p_limit, p_offset, p_viewer_seed, 5
  );
$$;

create or replace function public.get_community_feed(
  p_segment text default 'interior',
  p_limit int default 20,
  p_offset int default 0,
  p_viewer_seed text default ''
)
returns table (
  target_id uuid,
  is_boost boolean,
  position int,
  score numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select * from public.get_interleaved_feed_ids(
    lower(trim(coalesce(p_segment, 'interior'))),
    '{}',
    p_limit,
    p_offset,
    p_viewer_seed,
    5
  );
$$;

grant execute on function public.feed_viewer_seed(text, text, timestamptz)
  to anon, authenticated, service_role;
grant execute on function public.boost_feed_segment(text, uuid)
  to anon, authenticated, service_role;
grant execute on function public.feed_seed_rank(text, text)
  to anon, authenticated, service_role;
grant execute on function public.list_boost_candidates_scored(text, int)
  to anon, authenticated, service_role;
grant execute on function public.pick_boost_slot_targets(text, int, text, int)
  to anon, authenticated, service_role;
grant execute on function public.get_interleaved_feed_ids(text, uuid[], int, int, text, int)
  to anon, authenticated, service_role;
grant execute on function public.get_home_feed(int, int, text)
  to anon, authenticated, service_role;
grant execute on function public.get_community_feed(text, int, int, text)
  to anon, authenticated, service_role;
