-- 062_seed_initial_content.sql
-- Cold-start seed: Official guides + 3 master directors + B/A + social proof.
-- Idempotent fixed UUIDs. Timestamps spaced across prior 14 days via _seed_ts().
-- Media: prefers Storage public path seed/... ; picsum used as portable CDN stand-in
-- until objects are uploaded to the `seed` bucket.

-- ═══════════════════════════════════════════════════════════════════════════
-- 0) Schema: profiles.is_seed
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.profiles
  add column if not exists is_seed boolean not null default false;

comment on column public.profiles.is_seed is
  'Cold-start / demo persona. Exclude from real analytics when true.';

create index if not exists profiles_is_seed_idx
  on public.profiles (is_seed)
  where is_seed = true;

-- Spaced timestamp helper: n=0..N over ~14 days
create or replace function public._seed_ts(p_n int, p_jitter int default 0)
returns timestamptz
language sql
immutable
as $$
  select now()
    - make_interval(
        days => (abs(p_n) % 14),
        hours => 8 + ((abs(p_n) * 3 + abs(p_jitter)) % 14),
        mins => ((abs(p_n) * 11 + abs(p_jitter) * 7) % 50)
      );
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) auth.users + profiles (seed directors + fans)
-- ═══════════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

do $$
declare
  r record;
  v_users constant uuid[] := array[
    '00000000-0000-4000-8000-000000000201'::uuid, -- 서연
    '00000000-0000-4000-8000-000000000202'::uuid, -- 준호
    '00000000-0000-4000-8000-000000000203'::uuid, -- 하늘
    '00000000-0000-4000-8000-000000000301'::uuid,
    '00000000-0000-4000-8000-000000000302'::uuid,
    '00000000-0000-4000-8000-000000000303'::uuid,
    '00000000-0000-4000-8000-000000000304'::uuid,
    '00000000-0000-4000-8000-000000000305'::uuid,
    '00000000-0000-4000-8000-000000000306'::uuid,
    '00000000-0000-4000-8000-000000000307'::uuid,
    '00000000-0000-4000-8000-000000000308'::uuid,
    '00000000-0000-4000-8000-000000000309'::uuid,
    '00000000-0000-4000-8000-00000000030a'::uuid,
    '00000000-0000-4000-8000-00000000030b'::uuid,
    '00000000-0000-4000-8000-00000000030c'::uuid
  ];
  v_emails constant text[] := array[
    'seed-seoyeon@sori.local',
    'seed-junho@sori.local',
    'seed-haneul@sori.local',
    'seed-fan01@sori.local',
    'seed-fan02@sori.local',
    'seed-fan03@sori.local',
    'seed-fan04@sori.local',
    'seed-fan05@sori.local',
    'seed-fan06@sori.local',
    'seed-fan07@sori.local',
    'seed-fan08@sori.local',
    'seed-fan09@sori.local',
    'seed-fan10@sori.local',
    'seed-fan11@sori.local',
    'seed-fan12@sori.local'
  ];
  v_names constant text[] := array[
    '서연', '준호', '하늘',
    '민지', '수아', '도윤', '하린', '지우', '예나',
    '시우', '채원', '현서', '유나', '건우', '소율'
  ];
  v_roles constant text[] := array[
    'director', 'director', 'director',
    'customer', 'customer', 'customer', 'customer', 'customer', 'customer',
    'customer', 'customer', 'customer', 'customer', 'customer', 'customer'
  ];
  i int;
begin
  if to_regclass('auth.users') is null then
    raise notice '062: auth.users missing — skip auth seed';
    return;
  end if;

  for i in 1..array_length(v_users, 1) loop
    begin
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, recovery_token,
        email_change_token_new, email_change
      ) values (
        '00000000-0000-0000-0000-000000000000',
        v_users[i],
        'authenticated',
        'authenticated',
        v_emails[i],
        crypt('seed-not-for-login', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('name', v_names[i], 'is_seed', true),
        public._seed_ts(i + 20),
        public._seed_ts(i + 20),
        '', '', '', ''
      )
      on conflict (id) do nothing;
    exception when others then
      raise notice '062: auth.users insert skip %: %', v_emails[i], sqlerrm;
    end;

    begin
      insert into auth.identities (
        id, user_id, identity_data, provider, provider_id,
        last_sign_in_at, created_at, updated_at
      ) values (
        v_users[i],
        v_users[i],
        jsonb_build_object('sub', v_users[i]::text, 'email', v_emails[i]),
        'email',
        v_users[i]::text,
        now(),
        now(),
        now()
      )
      on conflict do nothing;
    exception when others then
      null;
    end;

    insert into public.profiles (
      id, role, name, nickname, phone, active_mode, avatar_url, is_seed, created_at, updated_at
    ) values (
      v_users[i],
      v_roles[i],
      v_names[i],
      v_names[i],
      '',
      case when v_roles[i] = 'director' then 'director' else 'customer' end,
      'https://picsum.photos/seed/sori-seed-avatar-' || i::text || '/200',
      true,
      public._seed_ts(i + 20),
      public._seed_ts(i + 20)
    )
    on conflict (id) do update set
      nickname = excluded.nickname,
      name = excluded.name,
      is_seed = true,
      avatar_url = excluded.avatar_url,
      updated_at = now();
  end loop;
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) Master shops + memberships
-- ═══════════════════════════════════════════════════════════════════════════

insert into public.shops (
  id, name, owner_name, owner_user_id, phone, address, bio,
  profile_image_url, created_at, updated_at
) values
(
  '00000000-0000-4000-8000-000000000101',
  '글로우핏 청담',
  '서연',
  '00000000-0000-4000-8000-000000000201',
  '',
  '서울 강남구 청담동',
  '페이스·리프팅 전문. SORI 퀄리티 바 시드 샵.',
  'https://picsum.photos/seed/sori-shop-glow/400',
  public._seed_ts(21),
  public._seed_ts(21)
),
(
  '00000000-0000-4000-8000-000000000102',
  '바디아틀리에 성수',
  '준호',
  '00000000-0000-4000-8000-000000000202',
  '',
  '서울 성동구 성수동',
  '바디·순환 전문. SORI 퀄리티 바 시드 샵.',
  'https://picsum.photos/seed/sori-shop-body/400',
  public._seed_ts(22),
  public._seed_ts(22)
),
(
  '00000000-0000-4000-8000-000000000103',
  '루미에르 한남',
  '하늘',
  '00000000-0000-4000-8000-000000000203',
  '',
  '서울 용산구 한남동',
  '피부·장벽 전문. SORI 퀄리티 바 시드 샵.',
  'https://picsum.photos/seed/sori-shop-lumiere/400',
  public._seed_ts(23),
  public._seed_ts(23)
)
on conflict (id) do update set
  name = excluded.name,
  owner_name = excluded.owner_name,
  owner_user_id = excluded.owner_user_id,
  bio = excluded.bio,
  profile_image_url = excluded.profile_image_url,
  updated_at = now();

insert into public.shop_memberships (shop_id, user_id, role, title, is_public)
values
  ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000201', 'owner', '원장', true),
  ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000202', 'owner', '원장', true),
  ('00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000203', 'owner', '원장', true)
on conflict (shop_id, user_id) do update set
  role = excluded.role,
  title = excluded.title,
  is_public = true,
  updated_at = now();

-- Ensure Official shop exists (060)
insert into public.shops (
  id, name, owner_name, bio, is_official, slug, created_at, updated_at
) values (
  '00000000-0000-4000-8000-0000000000f1',
  'SORI',
  'SORI',
  '소통하는 리뷰 — SORI 공식 계정',
  true,
  'sori-official',
  public._seed_ts(0),
  public._seed_ts(0)
)
on conflict (id) do update set
  is_official = true,
  slug = 'sori-official',
  name = 'SORI',
  updated_at = now();

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Demo patients + seed fan customers
-- ═══════════════════════════════════════════════════════════════════════════

-- Anonymous demo patients for charts (one per chart shop rotation)
insert into public.customers (
  id, shop_id, name, phone, gender, birth_date, created_at, updated_at
)
select
  ('00000000-0000-4000-8000-0000000004' || lpad(to_hex(g), 2, '0'))::uuid,
  case ((g - 1) % 3)
    when 0 then '00000000-0000-4000-8000-000000000101'::uuid
    when 1 then '00000000-0000-4000-8000-000000000102'::uuid
    else '00000000-0000-4000-8000-000000000103'::uuid
  end,
  '시드고객' || g::text,
  '010-9000-' || lpad(g::text, 4, '0'),
  case when g % 2 = 0 then 'female' else 'male' end,
  (date '1990-01-01' + ((g * 97) % 4000)),
  public._seed_ts(g + 5),
  public._seed_ts(g + 5)
from generate_series(1, 12) as g
on conflict (id) do update set
  shop_id = excluded.shop_id,
  updated_at = now();

-- Fan customers (for Fan-Boost wallets) attached to glow shop
insert into public.customers (
  id, shop_id, name, phone, user_id, gender, birth_date, created_at, updated_at
)
select
  ('00000000-0000-4000-8000-0000000005' || lpad(to_hex(g), 2, '0'))::uuid,
  '00000000-0000-4000-8000-000000000101'::uuid,
  (array['민지','수아','도윤','하린','지우','예나','시우','채원','현서','유나','건우','소율'])[g],
  '010-9100-' || lpad(g::text, 4, '0'),
  ('00000000-0000-4000-8000-0000000003' || lpad(to_hex(g), 2, '0'))::uuid,
  'female',
  date '1995-06-15',
  public._seed_ts(g),
  public._seed_ts(g)
from generate_series(1, 12) as g
on conflict (id) do update set
  user_id = excluded.user_id,
  name = excluded.name,
  updated_at = now();

-- Fan wallets
insert into public.wallets (
  id, owner_type, customer_id, shop_id, owner_user_id,
  point_free_balance, point_paid_balance, created_at, updated_at
)
select
  ('00000000-0000-4000-8000-0000000009' || lpad(to_hex(g), 2, '0'))::uuid,
  'customer',
  ('00000000-0000-4000-8000-0000000005' || lpad(to_hex(g), 2, '0'))::uuid,
  null,
  ('00000000-0000-4000-8000-0000000003' || lpad(to_hex(g), 2, '0'))::uuid,
  500,
  200,
  public._seed_ts(g),
  public._seed_ts(g)
from generate_series(1, 12) as g
on conflict (id) do update set
  point_free_balance = greatest(public.wallets.point_free_balance, 100),
  updated_at = now();

-- Shop wallets (skip if shop already has a shop wallet)
insert into public.wallets (
  id, owner_type, shop_id, owner_user_id,
  point_free_balance, point_paid_balance, created_at, updated_at
)
select v.id, 'shop', v.shop_id, v.owner_user_id, 1000, 0, public._seed_ts(1), public._seed_ts(1)
from (
  values
    ('00000000-0000-4000-8000-000000000911'::uuid, '00000000-0000-4000-8000-000000000101'::uuid, '00000000-0000-4000-8000-000000000201'::uuid),
    ('00000000-0000-4000-8000-000000000912'::uuid, '00000000-0000-4000-8000-000000000102'::uuid, '00000000-0000-4000-8000-000000000202'::uuid),
    ('00000000-0000-4000-8000-000000000913'::uuid, '00000000-0000-4000-8000-000000000103'::uuid, '00000000-0000-4000-8000-000000000203'::uuid)
) as v(id, shop_id, owner_user_id)
where not exists (
  select 1 from public.wallets w
  where w.owner_type = 'shop' and w.shop_id = v.shop_id
)
on conflict (id) do nothing;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) Ideal B/A charts (12) — spaced 14 days
-- ═══════════════════════════════════════════════════════════════════════════

insert into public.customer_charts (
  id, shop_id, customer_id, visit_number, care_name, treatment_summary,
  director_insight, concern_chips, care_tags, device_info, skin_sensitivity,
  before_image_url, after_image_url, signature_url, consent_photo,
  consent_mandatory, is_case_shared, author_user_id, author_nickname_snap,
  visit_checked, visit_checked_at, created_at, updated_at
)
select
  ('00000000-0000-4000-8000-0000000006' || lpad(to_hex(g), 2, '0'))::uuid,
  case ((g - 1) % 3)
    when 0 then '00000000-0000-4000-8000-000000000101'::uuid
    when 1 then '00000000-0000-4000-8000-000000000102'::uuid
    else '00000000-0000-4000-8000-000000000103'::uuid
  end,
  ('00000000-0000-4000-8000-0000000004' || lpad(to_hex(g), 2, '0'))::uuid,
  1 + ((g - 1) % 4),
  (array[
    '리프팅 집중 케어','윤곽 라인 케어','홍조·장벽 진정','첫방문 상담 케어',
    '복부 체형 케어','셀룰라이트 집중','부종·순환 케어','EMS 바디 케어',
    '수분장벽 케어','민감 진정 케어','홈케어 미션 케어','시즌 피부 케어'
  ])[g],
  (array[
    '얼굴 라인 리프팅 · 탄력 집중 (4주 5회)',
    '턱선·볼 윤곽 정돈 프로그램',
    '장벽 케어 + 쿨링 마무리',
    '첫 방문 상담 후 맞춤 케어',
    '복부·옆구리 순환 집중',
    '허벅지 셀룰라이트 케어',
    '림프 순환·부종 완화',
    'EMS 코어 강화 루틴',
    '수분·장벽 리페어',
    '민감 피부 진정 프로토콜',
    '3일 홈케어 미션 동반',
    '환절기 피부 컨디션 케어'
  ])[g],
  (array[
    'EMS + 림프 후 쿨링이 붓기 재발을 줄여요.',
    '동일 각도 촬영이 비교의 핵심입니다.',
    '자극 케어 직후 장벽 보습을 꼭 챙기세요.',
    '첫 방문은 설명 톤이 신뢰의 절반입니다.',
    '식후 2시간 뒤 케어가 순환에 유리합니다.',
    '주 1–2회 리듬이 가장 안정적이에요.',
    '수분 섭취와 압박복 가이드를 함께 주세요.',
    'EMS는 강도보다 호흡 큐잉이 중요합니다.',
    '세안 직후 3분 보습 루틴을 강조하세요.',
    '민감기는 기기보다 핸드 테크닉 비중↑',
    '미션 체크가 재진율을 끌어올립니다.',
    '시즌 바뀔 때 홈케어 처방을 업데이트하세요.'
  ])[g],
  jsonb_build_array(
    (array['탄력/리프팅','윤곽','홍조','첫방문','바디','셀룰라이트','부종','EMS','장벽','민감','홈케어','시즌'])[g]
  ),
  jsonb_build_array(
    (array['탄력/리프팅','윤곽','홍조','첫방문','바디','셀룰라이트','부종','EMS','장벽','민감','홈케어','시즌'])[g]
  ),
  (array[
    'EMS 리프팅','고주파','쿨링·장벽','상담',
    '고주파 바디','진공·롤러','림프 드레인','EMS 바디',
    '수분침투','핸드 테크닉','홈케어','시즌케어'
  ])[g],
  (array['수부지','중성','민감','중성','중성','건성','중성','중성','건성','민감','중성','수부지'])[g],
  -- Prefer Storage seed/ba/{n}_*.jpg once uploaded; picsum is portable stand-in
  'https://picsum.photos/seed/sori-seed-ba-' || g::text || 'b/600/800',
  'https://picsum.photos/seed/sori-seed-ba-' || g::text || 'a/600/800',
  'https://example.com/seed/signatures/chart-' || lpad(g::text, 2, '0') || '.png',
  true,
  true,
  true,
  case ((g - 1) % 3)
    when 0 then '00000000-0000-4000-8000-000000000201'::uuid
    when 1 then '00000000-0000-4000-8000-000000000202'::uuid
    else '00000000-0000-4000-8000-000000000203'::uuid
  end,
  (array['서연','준호','하늘'])[((g - 1) % 3) + 1],
  true,
  public._seed_ts(g - 1, g),
  public._seed_ts(g - 1, g),
  public._seed_ts(g - 1, g)
from generate_series(1, 12) as g
on conflict (id) do update set
  care_name = excluded.care_name,
  treatment_summary = excluded.treatment_summary,
  director_insight = excluded.director_insight,
  before_image_url = excluded.before_image_url,
  after_image_url = excluded.after_image_url,
  is_case_shared = true,
  author_user_id = excluded.author_user_id,
  author_nickname_snap = excluded.author_nickname_snap,
  created_at = excluded.created_at,
  visit_checked_at = excluded.visit_checked_at,
  updated_at = now();

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) Official + community info posts
-- ═══════════════════════════════════════════════════════════════════════════

insert into public.community_posts (
  id, shop_id, author_user_id, post_type, title, body,
  visibility, status, like_count, comment_count, created_at, updated_at
) values
(
  '00000000-0000-4000-8000-000000000701',
  '00000000-0000-4000-8000-0000000000f1',
  null,
  'case_share',
  '소통하는 리뷰, SORI가 여는 임상 커뮤니티',
  'SORI는 원장의 임상과 고객의 후기를 같은 언어로 연결합니다. 공식 계정은 공지·가이드만 전하며, 운영(Ops) 권한과는 분리됩니다.',
  'public', 'published', 48, 5,
  public._seed_ts(13, 1), public._seed_ts(13, 1)
),
(
  '00000000-0000-4000-8000-000000000702',
  '00000000-0000-4000-8000-0000000000f1',
  null,
  'case_share',
  '첫 B/A 올리는 법 — 동의·사진·캡션 체크리스트',
  '1) 전자 동의 완료 2) 동일 각도 Before/After 3) 케어명·기간·기기 1개 4) 과장 없는 인사이트 한 줄. 이 네 가지가 SORI 퀄리티 바입니다.',
  'public', 'published', 62, 6,
  public._seed_ts(11, 2), public._seed_ts(11, 2)
),
(
  '00000000-0000-4000-8000-000000000703',
  '00000000-0000-4000-8000-0000000000f1',
  null,
  'case_share',
  'Echo와 정산의 차이 — 1E=₩100 이해하기',
  'Echo는 앱 안에서 쓰는 응원·노출 포인트입니다. 정산 KRW와 장부가 분리되어 있어, Fan-Boost는 출금 가능한 정산금을 건드리지 않습니다.',
  'public', 'published', 55, 4,
  public._seed_ts(9, 3), public._seed_ts(9, 3)
),
(
  '00000000-0000-4000-8000-000000000704',
  '00000000-0000-4000-8000-0000000000f1',
  null,
  'case_share',
  '팬이 띄워주는 법 — Fan-Boost 사용 가이드',
  '마음에 드는 임상을 Echo로 띄우면 Facepile에 닉네임이 남습니다. 익명은 없습니다. 응원은 투명하게, 원장님은 더 힘나게.',
  'public', 'published', 71, 7,
  public._seed_ts(7, 4), public._seed_ts(7, 4)
),
(
  '00000000-0000-4000-8000-000000000705',
  '00000000-0000-4000-8000-0000000000f1',
  null,
  'case_share',
  '원장님끼리 물어도 되는 질문 / 안 되는 질문',
  'OK: 기기 운용 팁, 동의 프로세스, 케어 주기. NG: 타샵 비방, 의료 확언, 개인정보 공유. 커뮤니티는 동료의 교실입니다.',
  'public', 'published', 39, 5,
  public._seed_ts(5, 5), public._seed_ts(5, 5)
),
(
  '00000000-0000-4000-8000-000000000706',
  '00000000-0000-4000-8000-0000000000f1',
  null,
  'case_share',
  '신규 원장 체크리스트 Day 1',
  '샵 프로필 채우기 → 첫 동의 케이스 공유 → 커뮤니티에 자기소개 한 줄. 막히면 이 공식 계정의 가이드를 다시 열어보세요.',
  'public', 'published', 44, 3,
  public._seed_ts(2, 6), public._seed_ts(2, 6)
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = 'published',
  like_count = excluded.like_count,
  created_at = excluded.created_at,
  updated_at = now();

-- Info posts from masters (6)
insert into public.community_posts (
  id, shop_id, author_user_id, post_type, title, body,
  visibility, status, like_count, comment_count, created_at, updated_at
) values
(
  '00000000-0000-4000-8000-000000000711',
  '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000201',
  'device_review',
  '이 고주파, 우리 샵에서 3개월 써본 솔직 메모',
  '발열 안정성과 핸드피스 무게가 실사용 만족도를 갈랐어요. 초반 2주는 강도보다 동선 연습 추천합니다.',
  'public', 'published', 28, 5,
  public._seed_ts(12, 7), public._seed_ts(12, 7)
),
(
  '00000000-0000-4000-8000-000000000712',
  '00000000-0000-4000-8000-000000000102',
  '00000000-0000-4000-8000-000000000202',
  'device_review',
  'EMS 바디 — 호흡 큐잉이 결과를 바꿉니다',
  '세기만 올리면 이탈이 늘어요. 들숨·날숨 타이밍을 말로 잡아주면 유지율이 확실히 달라집니다.',
  'public', 'published', 33, 6,
  public._seed_ts(10, 8), public._seed_ts(10, 8)
),
(
  '00000000-0000-4000-8000-000000000713',
  '00000000-0000-4000-8000-000000000103',
  '00000000-0000-4000-8000-000000000203',
  'interior',
  '시술룸 조명·동선 — 고객이 안심하는 세팅',
  '조명은 얼굴 정면 그림자 최소, 동선은 동의서→세안→케어 한 방향으로. 작은 정돈이 재진을 만듭니다.',
  'public', 'published', 22, 4,
  public._seed_ts(8, 9), public._seed_ts(8, 9)
),
(
  '00000000-0000-4000-8000-000000000714',
  '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000201',
  'interior',
  '대기 공간에 후기 QR만 두었더니',
  '대기 중 리뷰 요청이 자연스러워졌어요. 강요 문구 대신 「오늘 케어 기록 남기기」 카피가 반응이 좋았습니다.',
  'public', 'published', 19, 3,
  public._seed_ts(6, 10), public._seed_ts(6, 10)
),
(
  '00000000-0000-4000-8000-000000000715',
  '00000000-0000-4000-8000-000000000102',
  '00000000-0000-4000-8000-000000000202',
  'case_share',
  '동의서 사인 전 고객이 가장 많이 묻는 3가지',
  '사진 공개 범위, 가족 열람, 마케팅 수신. 미리 한 줄씩 답하면 사인 속도가 빨라집니다.',
  'public', 'published', 41, 8,
  public._seed_ts(4, 11), public._seed_ts(4, 11)
),
(
  '00000000-0000-4000-8000-000000000716',
  '00000000-0000-4000-8000-000000000103',
  '00000000-0000-4000-8000-000000000203',
  'case_share',
  '민감 고객 첫 방문 — 기기보다 설명 순서',
  '오늘 하는 것 / 안 하는 것 / 집에 가면 할 것. 이 세 문장만 고정해도 불안이 확 줄어요.',
  'public', 'published', 36, 5,
  public._seed_ts(1, 12), public._seed_ts(1, 12)
)
on conflict (id) do update set
  title = excluded.title,
  body = excluded.body,
  status = 'published',
  created_at = excluded.created_at,
  updated_at = now();

-- Cover media for official/info posts
insert into public.post_media (id, post_id, image_url, sort_order)
select
  ('00000000-0000-4000-8000-000000000a' || lpad(to_hex(g), 2, '0'))::uuid,
  ('00000000-0000-4000-8000-0000000007' || lpad(to_hex(g), 2, '0'))::uuid,
  'https://picsum.photos/seed/sori-seed-post-' || g::text || '/800/600',
  0
from generate_series(1, 6) as g
on conflict (id) do update set image_url = excluded.image_url;

insert into public.post_media (id, post_id, image_url, sort_order)
values
  ('00000000-0000-4000-8000-000000000b01', '00000000-0000-4000-8000-000000000711', 'https://picsum.photos/seed/sori-seed-info-1/800/600', 0),
  ('00000000-0000-4000-8000-000000000b02', '00000000-0000-4000-8000-000000000712', 'https://picsum.photos/seed/sori-seed-info-2/800/600', 0),
  ('00000000-0000-4000-8000-000000000b03', '00000000-0000-4000-8000-000000000713', 'https://picsum.photos/seed/sori-seed-info-3/800/600', 0),
  ('00000000-0000-4000-8000-000000000b04', '00000000-0000-4000-8000-000000000714', 'https://picsum.photos/seed/sori-seed-info-4/800/600', 0),
  ('00000000-0000-4000-8000-000000000b05', '00000000-0000-4000-8000-000000000715', 'https://picsum.photos/seed/sori-seed-info-5/800/600', 0),
  ('00000000-0000-4000-8000-000000000b06', '00000000-0000-4000-8000-000000000716', 'https://picsum.photos/seed/sori-seed-info-6/800/600', 0)
on conflict (id) do update set image_url = excluded.image_url;

-- case_share bridges for chart comments
insert into public.community_posts (
  id, shop_id, author_user_id, post_type, title, body,
  source_chart_id, visibility, status, like_count, comment_count,
  created_at, updated_at
)
select
  ('00000000-0000-4000-8000-0000000008' || lpad(to_hex(g), 2, '0'))::uuid,
  c.shop_id,
  c.author_user_id,
  'case_share',
  c.care_name,
  coalesce(nullif(trim(c.director_insight), ''), c.treatment_summary),
  c.id,
  'public',
  'published',
  0,
  0,
  c.created_at,
  c.created_at
from public.customer_charts c
where c.id::text like '00000000-0000-4000-8000-0000000006%'
on conflict (id) do update set
  source_chart_id = excluded.source_chart_id,
  status = 'published',
  created_at = excluded.created_at,
  updated_at = now();

-- ═══════════════════════════════════════════════════════════════════════════
-- 6) Social proof — likes + ice-break comments
-- ═══════════════════════════════════════════════════════════════════════════

-- Chart likes (liker_key = seed fan ids) — denser on first 4 hit charts
insert into public.chart_likes (chart_id, liker_key, created_at)
select
  ('00000000-0000-4000-8000-0000000006' || lpad(to_hex(((g - 1) % 12) + 1), 2, '0'))::uuid,
  'seed-fan-' || g::text || '-' || ((g * 3) % 17)::text,
  public._seed_ts(((g - 1) % 12), g)
from generate_series(1, 220) as g
on conflict (chart_id, liker_key) do nothing;

-- Extra likes on hit charts 1–3
insert into public.chart_likes (chart_id, liker_key, created_at)
select
  ('00000000-0000-4000-8000-0000000006' || lpad(to_hex(((g - 1) % 3) + 1), 2, '0'))::uuid,
  'seed-hit-' || g::text,
  public._seed_ts(((g - 1) % 3), g + 40)
from generate_series(1, 120) as g
on conflict (chart_id, liker_key) do nothing;

-- Ice-break comments on official + bridges
insert into public.community_comments (
  id, post_id, author_user_id, content, status, created_at, updated_at
)
values
(
  '00000000-0000-4000-8000-000000000c01',
  '00000000-0000-4000-8000-000000000702',
  '00000000-0000-4000-8000-000000000202',
  '이 체크리스트 그대로 샵 단톡에 공유했어요. 각도 팁도 더 올려주실 수 있을까요?',
  'published',
  public._seed_ts(10, 20), public._seed_ts(10, 20)
),
(
  '00000000-0000-4000-8000-000000000c02',
  '00000000-0000-4000-8000-000000000704',
  '00000000-0000-4000-8000-000000000203',
  'Fan-Boost 닉네임 공개 원칙이 오히려 신뢰가 생기네요. Echo 충전은 어디서 하나요?',
  'published',
  public._seed_ts(6, 21), public._seed_ts(6, 21)
),
(
  '00000000-0000-4000-8000-000000000c03',
  '00000000-0000-4000-8000-000000000801',
  '00000000-0000-4000-8000-000000000301',
  '이 케어 보통 몇 회 주기가 제일 좋으셨어요?',
  'published',
  public._seed_ts(0, 22) + interval '5 hours',
  public._seed_ts(0, 22) + interval '5 hours'
),
(
  '00000000-0000-4000-8000-000000000c04',
  '00000000-0000-4000-8000-000000000802',
  '00000000-0000-4000-8000-000000000302',
  '동의서 설명 톤이 정말 좋네요. 저희도 비슷하게 해볼게요.',
  'published',
  public._seed_ts(1, 23) + interval '8 hours',
  public._seed_ts(1, 23) + interval '8 hours'
),
(
  '00000000-0000-4000-8000-000000000c05',
  '00000000-0000-4000-8000-000000000715',
  '00000000-0000-4000-8000-000000000201',
  '가족 열람 문구 샘플 공유해주실 수 있을까요?',
  'published',
  public._seed_ts(3, 24) + interval '3 hours',
  public._seed_ts(3, 24) + interval '3 hours'
),
(
  '00000000-0000-4000-8000-000000000c06',
  '00000000-0000-4000-8000-000000000803',
  '00000000-0000-4000-8000-000000000303',
  'Before 각도 팁 공유해 주실 수 있을까요?',
  'published',
  public._seed_ts(2, 25) + interval '6 hours',
  public._seed_ts(2, 25) + interval '6 hours'
),
(
  '00000000-0000-4000-8000-000000000c07',
  '00000000-0000-4000-8000-000000000701',
  '00000000-0000-4000-8000-000000000304',
  '공식 계정과 Ops가 분리된다는 점이 안심됩니다.',
  'published',
  public._seed_ts(12, 26) + interval '4 hours',
  public._seed_ts(12, 26) + interval '4 hours'
),
(
  '00000000-0000-4000-8000-000000000c08',
  '00000000-0000-4000-8000-000000000711',
  '00000000-0000-4000-8000-000000000305',
  '핸드피스 무게 체감이 궁금해요. 하루 몇 명 기준이신가요?',
  'published',
  public._seed_ts(11, 27) + interval '2 hours',
  public._seed_ts(11, 27) + interval '2 hours'
)
on conflict (id) do update set
  content = excluded.content,
  status = 'published',
  created_at = excluded.created_at,
  updated_at = now();

-- Sync comment_count / like_count on seed bridges
update public.community_posts p
set comment_count = (
  select count(*)::int from public.community_comments c
  where c.post_id = p.id and c.status = 'published'
)
where p.id::text like '00000000-0000-4000-8000-0000000007%'
   or p.id::text like '00000000-0000-4000-8000-0000000008%';

update public.community_posts p
set like_count = greatest(
  p.like_count,
  (
    select count(*)::int
    from public.chart_likes l
    where l.chart_id = p.source_chart_id
  )
)
where p.source_chart_id is not null
  and p.id::text like '00000000-0000-4000-8000-0000000008%';

-- ═══════════════════════════════════════════════════════════════════════════
-- 7) Fan-Boost on hit charts 1–3 (Facepile demo)
-- ═══════════════════════════════════════════════════════════════════════════

insert into public.boost_placements (
  id, shop_id, item_sku, target_type, target_id, chart_id,
  region_code, starts_at, ends_at, status, points_spent,
  source, paid_by_customer_id, paid_by_wallet_id, fan_display_name,
  created_at, updated_at
)
select
  ('00000000-0000-4000-8000-000000000d' || lpad(to_hex(g), 2, '0'))::uuid,
  '00000000-0000-4000-8000-000000000101',
  'boost_local_7d',
  'chart',
  ('00000000-0000-4000-8000-0000000006' || lpad(to_hex(((g - 1) % 3) + 1), 2, '0'))::uuid,
  ('00000000-0000-4000-8000-0000000006' || lpad(to_hex(((g - 1) % 3) + 1), 2, '0'))::uuid,
  'seoul',
  public._seed_ts(((g - 1) % 3), g) + interval '1 hour',
  now() + interval '5 days',
  'active',
  (array[100, 200, 150, 300, 100, 250, 180, 120, 220])[g],
  'fan_boost',
  ('00000000-0000-4000-8000-0000000005' || lpad(to_hex(g), 2, '0'))::uuid,
  ('00000000-0000-4000-8000-0000000009' || lpad(to_hex(g), 2, '0'))::uuid,
  (array['민지','수아','도윤','하린','지우','예나','시우','채원','현서'])[g],
  public._seed_ts(((g - 1) % 3), g) + interval '2 hours',
  public._seed_ts(((g - 1) % 3), g) + interval '2 hours'
from generate_series(1, 9) as g
on conflict (id) do update set
  status = 'active',
  ends_at = excluded.ends_at,
  points_spent = excluded.points_spent,
  fan_display_name = excluded.fan_display_name,
  updated_at = now();

comment on function public._seed_ts(int, int) is
  '062 cold-start: spaced created_at over ~14 days.';
