-- 087: B/A 커뮤니티 발행 동의 게이트 (SNS marketing 필수)
-- + shop_notifications kind CHECK 확장

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) shop_notifications kind CHECK 확장
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.shop_notifications
  drop constraint if exists shop_notifications_kind_check;

alter table public.shop_notifications
  add constraint shop_notifications_kind_check
  check (kind in (
    'fan_boost',
    'special_supporter',
    'case_bookmark',
    'market_inquiry',
    'tip',
    'system',
    'whisper',
    'like',
    'comment'
  ));

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) assert_chart_community_publishable
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.assert_chart_community_publishable(p_chart_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_sig text;
  v_pdf text;
  v_marketing boolean;
  v_offline boolean;
begin
  if p_chart_id is null then
    raise exception 'chart_id required';
  end if;

  select
    coalesce(nullif(trim(signature_url), ''), ''),
    coalesce(nullif(trim(consent_pdf_url), ''), ''),
    coalesce(consent_marketing, false),
    coalesce(consent_offline_only, false)
  into v_sig, v_pdf, v_marketing, v_offline
  from public.customer_charts
  where id = p_chart_id;

  if not found then
    raise exception 'chart not found';
  end if;

  if v_sig = '' and v_pdf = '' then
    raise exception 'consent signature required';
  end if;

  if v_offline and not v_marketing then
    raise exception 'SNS marketing consent required';
  end if;

  if not v_marketing then
    raise exception 'SNS marketing consent required';
  end if;
end;
$$;

grant execute on function public.assert_chart_community_publishable(uuid)
  to authenticated, anon, public;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) save_chart_and_publish_case — 발행 전 assert (052 시그니처 유지)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.save_chart_and_publish_case(
  p_chart_id uuid,
  p_shop_id uuid,
  p_publish boolean default true,
  p_title text default null,
  p_body text default null,
  p_image_urls text[] default '{}',
  p_author_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chart public.customer_charts%rowtype;
  v_post_id uuid;
  v_title text;
  v_body text;
  v_urls text[];
  v_url text;
  v_ord int := 0;
  v_existing uuid;
begin
  if p_chart_id is null or p_shop_id is null then
    raise exception 'chart_id and shop_id required';
  end if;

  select * into v_chart
  from public.customer_charts
  where id = p_chart_id
  for update;

  if not found then
    raise exception 'chart not found: %', p_chart_id;
  end if;

  if v_chart.shop_id is distinct from p_shop_id then
    raise exception 'shop_id mismatch for chart';
  end if;

  if not coalesce(p_publish, false) then
    update public.customer_charts
    set is_case_shared = false,
        case_shared = false,
        updated_at = now()
    where id = p_chart_id;
    return jsonb_build_object(
      'chart_id', p_chart_id,
      'published', false,
      'post_id', null
    );
  end if;

  -- ★ SNS 마케팅 동의 게이트
  perform public.assert_chart_community_publishable(p_chart_id);

  update public.customer_charts
  set is_case_shared = true,
      case_shared = true,
      updated_at = now()
  where id = p_chart_id;

  select p.id into v_existing
  from public.community_posts p
  where p.source_chart_id = p_chart_id
    and p.post_type = 'case_share'
  order by p.created_at desc
  limit 1;

  if v_existing is not null then
    return jsonb_build_object(
      'chart_id', p_chart_id,
      'published', true,
      'post_id', v_existing,
      'deduped', true
    );
  end if;

  v_title := nullif(trim(coalesce(p_title, '')), '');
  if v_title is null then
    v_title := trim(coalesce(v_chart.care_name, '')) || ' · 임상 케이스';
    if trim(coalesce(v_chart.care_name, '')) = '' then
      v_title := '시술 케이스 · 임상 케이스';
    end if;
  end if;

  v_body := nullif(trim(coalesce(p_body, '')), '');
  if v_body is null then
    v_body := trim(both E'\n' from concat_ws(
      E'\n\n',
      nullif(trim(coalesce(v_chart.treatment_summary, '')), ''),
      nullif(trim(coalesce(v_chart.director_insight, '')), '')
    ));
    if v_body is null or v_body = '' then
      v_body := coalesce(nullif(trim(v_chart.care_name), ''), '시술')
        || ' 임상 기록 공유 (고객 정보는 비식별화되었습니다)';
    end if;
  end if;

  insert into public.community_posts (
    shop_id,
    author_user_id,
    post_type,
    title,
    body,
    style_tags,
    visibility,
    status,
    source_chart_id
  ) values (
    p_shop_id,
    p_author_user_id,
    'case_share',
    v_title,
    v_body,
    array['케이스공유', '비식별']::text[],
    'public',
    'published',
    p_chart_id
  )
  returning id into v_post_id;

  v_urls := coalesce(p_image_urls, '{}'::text[]);
  if coalesce(array_length(v_urls, 1), 0) = 0 then
    v_urls := array_remove(array[
      nullif(trim(coalesce(v_chart.before_image_url, '')), ''),
      nullif(trim(coalesce(v_chart.after_image_url, '')), '')
    ], null);
  end if;

  foreach v_url in array coalesce(v_urls, '{}'::text[])
  loop
    if v_url is null or length(trim(v_url)) = 0 then
      continue;
    end if;
    if v_url not like 'http%' and v_url not like 'data:%' then
      continue;
    end if;
    insert into public.post_media (post_id, image_url, sort_order)
    values (v_post_id, trim(v_url), v_ord);
    v_ord := v_ord + 1;
  end loop;

  return jsonb_build_object(
    'chart_id', p_chart_id,
    'published', true,
    'post_id', v_post_id,
    'deduped', false
  );
exception
  when others then
    raise;
end;
$$;

comment on function public.save_chart_and_publish_case(uuid, uuid, boolean, text, text, text[], uuid) is
  '차트 is_case_shared + case_share 발행 All-or-Nothing. SNS marketing consent required (087).';

grant execute on function public.save_chart_and_publish_case(uuid, uuid, boolean, text, text, text[], uuid)
  to anon, authenticated, public;
