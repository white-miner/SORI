-- 085: S5 — 샵 신뢰 스코어 (북마크·후원·리뷰·세미나 복합, 읽기 전용)

create or replace function public.get_shop_trust_score(p_shop_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_bookmarks int := 0;
  v_echo int := 0;
  v_gifts int := 0;
  v_review_avg numeric := 0;
  v_review_count int := 0;
  v_seminar_count int := 0;
  v_thank_yous int := 0;
  v_thank_rate numeric := 0;
  v_raw numeric := 0;
  v_score int := 0;
  v_label text := '성장 중';
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  select count(*)::int
  into v_bookmarks
  from public.case_bookmarks cb
  join public.customer_charts cc on cc.id = cb.chart_id
  where cc.shop_id = p_shop_id;

  select
    coalesce(sum(fg.echo_spent), 0)::int,
    count(*)::int,
    count(*) filter (
      where exists (
        select 1 from public.community_posts p
        where p.reply_to_fan_gift_id = fg.id
      )
    )::int
  into v_echo, v_gifts, v_thank_yous
  from public.fan_gifts fg
  where fg.beneficiary_shop_id = p_shop_id
    and fg.status = 'completed'
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    );

  if v_gifts > 0 then
    v_thank_rate := v_thank_yous::numeric / v_gifts::numeric;
  end if;

  select
    coalesce(avg(r.rating), 0),
    count(*)::int
  into v_review_avg, v_review_count
  from public.customer_reviews r
  where r.shop_id = p_shop_id
    and r.rating is not null
    and r.rating > 0;

  select count(*)::int
  into v_seminar_count
  from public.seminar_classes sc
  where sc.shop_id = p_shop_id;

  v_raw :=
    15 * ln(1 + v_bookmarks)
    + 25 * ln(1 + greatest(v_echo, 0) / 50.0)
    + 10 * ln(1 + v_gifts)
    + case
        when v_review_count > 0 then 20 * (v_review_avg / 5.0)
        else 0
      end
    + 10 * ln(1 + v_seminar_count)
    + 20 * v_thank_rate;

  v_score := round(least(100, greatest(0, v_raw)))::int;

  v_label := case
    when v_score >= 75 then '검증된 레퍼런스'
    when v_score >= 45 then '신뢰 쌓이는 중'
    else '성장 중'
  end;

  return jsonb_build_object(
    'ok', true,
    'score', v_score,
    'tier_label', v_label,
    'bookmark_count', v_bookmarks,
    'supporter_echo', v_echo,
    'supporter_gift_count', v_gifts,
    'review_avg', round(v_review_avg, 1),
    'review_count', v_review_count,
    'seminar_count', v_seminar_count,
    'thank_you_rate', round(v_thank_rate, 2)
  );
end;
$$;

grant execute on function public.get_shop_trust_score(uuid)
  to authenticated;
