-- PRD v3.1-C: Top Mentor online ring — expose profiles.last_seen_at.

CREATE OR REPLACE FUNCTION public.list_discover_directors(
  p_limit int DEFAULT 40,
  p_query text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit int := greatest(1, least(coalesce(p_limit, 40), 100));
  v_q text := lower(trim(coalesce(p_query, '')));
BEGIN
  RETURN coalesce((
    SELECT jsonb_agg(row_data ORDER BY sort_followers DESC, sort_name)
    FROM (
      SELECT
        coalesce(s.follower_count, 0) AS sort_followers,
        lower(s.name) AS sort_name,
        jsonb_build_object(
          'shop_id', s.id,
          'shop_name', s.name,
          'owner_user_id', s.owner_user_id,
          'owner_name', s.owner_name,
          'nickname', coalesce(
            nullif(trim(p.nickname), ''),
            nullif(trim(p.name), ''),
            nullif(trim(s.owner_name), ''),
            s.name
          ),
          'avatar_url', coalesce(
            nullif(trim(p.avatar_url), ''),
            nullif(trim(s.profile_image_url), '')
          ),
          'bio', left(coalesce(s.bio, ''), 120),
          'address', coalesce(s.address, ''),
          'follower_count', coalesce(s.follower_count, 0),
          'shared_case_count', coalesce(s.shared_case_count, 0),
          'is_official', coalesce(s.is_official, false),
          'slug', coalesce(s.slug, ''),
          'is_seed', coalesce(p.is_seed, false),
          'last_seen_at', p.last_seen_at
        ) AS row_data
      FROM public.shops s
      LEFT JOIN public.profiles p ON p.id = s.owner_user_id
      WHERE coalesce(s.is_official, false) = false
        AND (
          v_q = ''
          OR lower(s.name) LIKE '%' || v_q || '%'
          OR lower(coalesce(s.owner_name, '')) LIKE '%' || v_q || '%'
          OR lower(coalesce(p.nickname, '')) LIKE '%' || v_q || '%'
          OR lower(coalesce(p.name, '')) LIKE '%' || v_q || '%'
          OR lower(coalesce(s.address, '')) LIKE '%' || v_q || '%'
        )
      ORDER BY coalesce(s.follower_count, 0) DESC, s.name ASC
      LIMIT v_limit
    ) q
  ), '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_discover_directors(int, text)
  TO authenticated, anon;

COMMENT ON FUNCTION public.list_discover_directors(int, text) IS
  'Discover directors + last_seen_at for Top Mentor online ring (PRD v3.1-C).';
