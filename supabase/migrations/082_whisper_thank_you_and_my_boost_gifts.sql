-- 082: E2 — 감사 위스퍼 숏컷 + 내가 후원한 케이스 (list_my_boost_gifts)

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) community_posts — link thank-you whisper to fan_gift
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.community_posts
  add column if not exists reply_to_fan_gift_id uuid
    references public.fan_gifts (id) on delete set null;

create unique index if not exists idx_community_posts_reply_fan_gift
  on public.community_posts (reply_to_fan_gift_id)
  where reply_to_fan_gift_id is not null;

comment on column public.community_posts.reply_to_fan_gift_id is
  'Director thank-you whisper tied to a fan_gift (one per gift).';

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) send_thank_you_whisper — 1:1 감사 속삭임
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.send_thank_you_whisper(
  p_fan_gift_id uuid,
  p_body text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_gift public.fan_gifts%rowtype;
  v_shop uuid;
  v_supporter_user uuid;
  v_body text;
  v_post_id uuid;
  v_name text;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;
  if p_fan_gift_id is null then
    raise exception 'fan_gift_id required';
  end if;

  select * into v_gift
  from public.fan_gifts
  where id = p_fan_gift_id and status = 'completed';
  if not found then
    raise exception 'fan_gift not found';
  end if;

  if exists (
    select 1 from public.community_posts cp
    where cp.reply_to_fan_gift_id = p_fan_gift_id
  ) then
    raise exception 'thank you whisper already sent';
  end if;

  select s.id into v_shop
  from public.shops s
  where s.id = v_gift.beneficiary_shop_id
    and (
      s.owner_user_id = v_uid
      or exists (
        select 1 from public.shop_memberships m
        where m.shop_id = s.id and m.user_id = v_uid
      )
    );
  if v_shop is null then
    raise exception 'shop access denied';
  end if;

  select c.user_id, coalesce(nullif(trim(v_gift.fan_display_name), ''), c.name, '후원자')
  into v_supporter_user, v_name
  from public.customers c
  where c.id = v_gift.fan_customer_id;

  if v_supporter_user is null then
    raise exception 'supporter user not linked';
  end if;

  v_body := left(trim(coalesce(p_body, '')), 2000);
  if v_body = '' then
    v_body := format('%s님, 후원해 주셔서 감사합니다!', v_name);
  end if;

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
    whisper_recipient_count,
    reply_to_fan_gift_id
  ) values (
    v_shop,
    v_uid,
    'case_share',
    '',
    v_body,
    'directors_only',
    'published',
    true,
    jsonb_build_object(
      'op', 'union',
      'atoms', jsonb_build_array('explicit'),
      'explicit_user_ids', jsonb_build_array(v_supporter_user),
      'shop_id', v_shop,
      'kind', 'thank_you_supporter',
      'fan_gift_id', p_fan_gift_id
    ),
    'union',
    0,
    p_fan_gift_id
  )
  returning id into v_post_id;

  insert into public.community_whisper_recipients (post_id, user_id, atom_bits)
  values (v_post_id, v_supporter_user, 16)
  on conflict (post_id, user_id) do nothing;

  update public.community_posts
  set whisper_recipient_count = 1, updated_at = now()
  where id = v_post_id;

  return jsonb_build_object(
    'ok', true,
    'post_id', v_post_id,
    'whisper_id', v_post_id,
    'recipient_count', 1,
    'fan_gift_id', p_fan_gift_id,
    'supporter_name', v_name
  );
end;
$$;

comment on function public.send_thank_you_whisper(uuid, text) is
  'Director 1:1 thank-you whisper to a fan_gift supporter.';

grant execute on function public.send_thank_you_whisper(uuid, text)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) list_my_boost_gifts — 고객 「내가 후원한 케이스」
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_my_boost_gifts(
  p_fan_customer_id uuid,
  p_limit int default 50
)
returns table (
  fan_gift_id uuid,
  target_type text,
  chart_id uuid,
  shop_id uuid,
  shop_name text,
  sku text,
  echo_spent int,
  gift_kind text,
  created_at timestamptz,
  case_title text,
  has_thank_you boolean,
  thank_you_post_id uuid
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if p_fan_customer_id is null then
    raise exception 'fan_customer_id required';
  end if;

  return query
  select
    fg.id,
    fg.target_type,
    case when fg.target_type = 'chart' then fg.target_id else cp.source_chart_id end,
    fg.beneficiary_shop_id,
    coalesce(nullif(trim(s.name), ''), 'SORI'),
    fg.sku,
    fg.echo_spent,
    fg.gift_kind,
    fg.created_at,
    coalesce(
      nullif(trim(cc.care_name), ''),
      nullif(trim(cc.treatment_summary), ''),
      '케이스'
    ),
    exists (
      select 1 from public.community_posts p
      where p.reply_to_fan_gift_id = fg.id
    ),
    (
      select p.id from public.community_posts p
      where p.reply_to_fan_gift_id = fg.id
      limit 1
    )
  from public.fan_gifts fg
  join public.shops s on s.id = fg.beneficiary_shop_id
  left join public.customer_charts cc
    on fg.target_type = 'chart' and cc.id = fg.target_id
  left join public.community_posts cp
    on fg.target_type = 'community_post' and cp.id = fg.target_id
  where fg.fan_customer_id = p_fan_customer_id
    and fg.status = 'completed'
    and fg.gift_kind in (
      'boost', 'boost_with_ai_fill',
      'boost_special_gold', 'boost_special_platinum'
    )
  order by fg.created_at desc
  limit v_limit;
end;
$$;

-- PostgREST alias (Flutter p_customer_id)
create or replace function public.list_my_boost_gifts_for_customer(
  p_customer_id uuid,
  p_limit int default 50
)
returns table (
  fan_gift_id uuid,
  target_type text,
  chart_id uuid,
  shop_id uuid,
  shop_name text,
  sku text,
  echo_spent int,
  gift_kind text,
  created_at timestamptz,
  case_title text,
  has_thank_you boolean,
  thank_you_post_id uuid
)
language sql
security definer
set search_path = public
as $$
  select * from public.list_my_boost_gifts(p_customer_id, p_limit);
$$;

grant execute on function public.list_my_boost_gifts(uuid, int)
  to authenticated;
grant execute on function public.list_my_boost_gifts_for_customer(uuid, int)
  to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) list_pending_supporter_notifications — 원장 감사 위스퍼 대기
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.list_pending_supporter_notifications(
  p_shop_id uuid,
  p_limit int default 30
)
returns table (
  notification_id uuid,
  kind text,
  title text,
  body text,
  created_at timestamptz,
  fan_gift_id uuid,
  chart_id uuid,
  supporter_name text,
  supporter_customer_id uuid,
  has_thank_you boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 30), 100));
begin
  if p_shop_id is null then
    raise exception 'shop_id required';
  end if;

  return query
  select
    n.id,
    n.kind,
    n.title,
    n.body,
    n.created_at,
    nullif(trim(coalesce(n.payload->>'fan_gift_id', '')), '')::uuid,
    nullif(trim(coalesce(n.payload->>'chart_id', '')), '')::uuid,
    coalesce(
      nullif(trim(n.payload->>'supporter_name'), ''),
      nullif(trim(n.payload->>'fan_name'), ''),
      '후원자'
    ),
    nullif(trim(coalesce(n.payload->>'customer_id', '')), '')::uuid,
    exists (
      select 1 from public.community_posts cp
      where cp.reply_to_fan_gift_id =
        nullif(trim(coalesce(n.payload->>'fan_gift_id', '')), '')::uuid
    )
  from public.shop_notifications n
  where n.shop_id = p_shop_id
    and n.kind in ('fan_boost', 'special_supporter')
  order by n.created_at desc
  limit v_limit;
end;
$$;

grant execute on function public.list_pending_supporter_notifications(uuid, int)
  to anon, authenticated, service_role;
