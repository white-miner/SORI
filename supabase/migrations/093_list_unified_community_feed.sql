-- 093_list_unified_community_feed.sql
-- Unified Feed S2: recency-ranked fetch (client applies 4:1 boost interleave).

create or replace function public.list_unified_community_feed(
  p_filter text default 'all',
  p_limit int default 80,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_filter text := lower(trim(coalesce(p_filter, 'all')));
  v_limit int := greatest(1, least(coalesce(p_limit, 80), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_result jsonb;
begin
  with base as (
    select u.*
    from public.unified_feed_items_v1 u
    where
      case v_filter
        when 'all' then
          -- PO: only public whispers in 전체; other whispers excluded
          (u.feed_kind <> 'whisper')
          or (
            u.feed_kind = 'whisper'
            and u.visibility = 'public'
            and coalesce(u.feed_metadata ->> 'is_public', 'false') = 'true'
          )
          or (
            u.feed_kind = 'whisper'
            and u.visibility = 'public'
            and exists (
              select 1
              from public.community_posts cp
              where cp.id = u.source_post_id
                and coalesce(cp.audience_spec -> 'atoms', '[]'::jsonb) ? 'everyone'
            )
          )
        when 'whisper' then u.feed_kind = 'whisper'
        when 'interior' then u.feed_kind = 'interior'
        when 'device_review' then u.feed_kind = 'device_review'
        when 'marketplace' then u.feed_kind = 'marketplace'
        when 'seminar' then u.feed_kind = 'seminar'
        when 'ba' then u.feed_kind = 'ba'
        else true
      end
  ),
  ranked as (
    select
      b.*,
      row_number() over (order by b.sort_at desc nulls last, b.feed_id) as rn
    from base b
  ),
  page as (
    select * from ranked
    where rn > v_offset and rn <= v_offset + v_limit
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'feed_id', feed_id,
      'kind', feed_kind,
      'shop_id', shop_id,
      'author_user_id', author_user_id,
      'sort_at', sort_at,
      'source_post_id', source_post_id,
      'source_chart_id', source_chart_id,
      'source_seminar_id', source_seminar_id,
      'feed_metadata', feed_metadata,
      'visibility', visibility
    ) order by rn
  ), '[]'::jsonb)
  into v_result
  from page;

  return jsonb_build_object(
    'items', v_result,
    'filter', v_filter,
    'limit', v_limit,
    'offset', v_offset
  );
end;
$$;

comment on function public.list_unified_community_feed(text, int, int) is
  'Unified community feed — recency sort; boost 4:1 interleave on client (059).';

grant execute on function public.list_unified_community_feed(text, int, int)
  to authenticated;
