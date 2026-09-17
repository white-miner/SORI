-- PRD v7.0 R1 — B/A 임시 촬영 세션 (My Feed 캐러셀 SSOT)
--
-- 배경: ShootInboxItem이 SharedPreferences 전용이라 기기 변경 시 사진이 유실되고
--       서버가 상태를 모르므로 신호등(🔴/🟢) 판정이 불가능했다.
-- 설계: 캐러셀 카드 1장 = 이 테이블의 row 1개. 완성 여부는 저장하지 않고
--       같은 row의 3개 필드에서 generated column으로 파생한다 (드리프트 원천 차단).

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) ba_capture_sessions
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.ba_capture_sessions (
  id                 uuid primary key default gen_random_uuid(),
  shop_id            uuid not null references public.shops(id) on delete cascade,
  author_id          uuid references public.profiles(id) on delete set null,

  -- 기기 로컬 큐(ShootInboxItem.sessionToken)와의 멱등 키.
  -- unique(shop_id, session_token)이 승격 재실행 시 중복 생성을 막는다.
  session_token      text not null,

  before_image_url   text,
  after_image_url    text,
  before_captured_at timestamptz,
  after_captured_at  timestamptz,

  customer_id        uuid references public.customers(id) on delete set null,
  chart_id           uuid references public.customer_charts(id) on delete set null,

  label              text not null default '',
  status             text not null default 'draft'
                     check (status in ('draft', 'linked', 'archived')),

  -- "완료" 눌러 옆으로 밀어둔 시각. status는 draft로 유지되어 🔴 경고가 남는다.
  deferred_at        timestamptz,
  linked_at          timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  -- 신호등 SSOT — Dart의 BaCaptureSession.isComplete와 동일 수식.
  is_complete boolean generated always as (
    before_image_url is not null and before_image_url <> ''
    and after_image_url is not null and after_image_url <> ''
    and chart_id is not null
  ) stored,

  unique (shop_id, session_token)
);

comment on table public.ba_capture_sessions is
  'PRD v7.0 — 차트 미연동 상태에서도 촬영 가능한 B/A 임시 세션. My Feed 캐러셀 SSOT.';
comment on column public.ba_capture_sessions.session_token is
  '기기 로컬 큐 멱등 키 — 승격/재동기화 시 중복 방지.';
comment on column public.ba_capture_sessions.is_complete is
  '신호등 파생값: before + after + chart_id 3박자 완비 시 true (🟢).';
comment on column public.ba_capture_sessions.deferred_at is
  '"완료"로 후순위화한 시각. 삭제가 아니라 정렬만 뒤로 — 🔴 경고는 유지.';

-- 캐러셀 쿼리 전용 부분 인덱스 (draft만 스캔).
create index if not exists idx_ba_sessions_carousel
  on public.ba_capture_sessions (shop_id, created_at desc)
  where status = 'draft';

create index if not exists idx_ba_sessions_chart
  on public.ba_capture_sessions (chart_id)
  where chart_id is not null;

-- updated_at 자동 갱신
create or replace function public.touch_ba_capture_session()
returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_ba_capture_sessions_touch on public.ba_capture_sessions;
create trigger trg_ba_capture_sessions_touch
  before update on public.ba_capture_sessions
  for each row execute function public.touch_ba_capture_session();

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) RLS — 샵 소속만 읽기, owner/director만 쓰기. 공개 select 정책 없음.
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.ba_capture_sessions enable row level security;

drop policy if exists ba_sessions_shop_read on public.ba_capture_sessions;
create policy ba_sessions_shop_read on public.ba_capture_sessions
  for select using (
    shop_id in (
      select sm.shop_id from public.shop_memberships sm
      where sm.user_id = auth.uid()
    )
  );

drop policy if exists ba_sessions_shop_write on public.ba_capture_sessions;
create policy ba_sessions_shop_write on public.ba_capture_sessions
  for all using (
    shop_id in (
      select sm.shop_id from public.shop_memberships sm
      where sm.user_id = auth.uid()
        and sm.role in ('owner', 'director')
    )
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) bind_ba_session_to_chart — 원자적 이관
--    반쪽 상태(Before만 차트에 붙고 After 실패)를 막기 위해 단일 트랜잭션 처리.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.bind_ba_session_to_chart(
  p_session_id  uuid,
  p_customer_id uuid,
  p_chart_id    uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.ba_capture_sessions;
  v_result  jsonb;
begin
  select * into v_session
    from public.ba_capture_sessions
   where id = p_session_id
     for update;

  if not found then
    raise exception 'ba_capture_session % not found', p_session_id
      using errcode = 'P0002';
  end if;

  if not exists (select 1 from public.customer_charts where id = p_chart_id) then
    raise exception 'customer_chart % not found', p_chart_id
      using errcode = 'P0002';
  end if;

  -- 1) 차트에 B/A URL 반영 (세션에 있는 값만 덮어씀)
  update public.customer_charts
     set before_image_url = coalesce(
           nullif(v_session.before_image_url, ''), before_image_url),
         after_image_url  = coalesce(
           nullif(v_session.after_image_url, ''), after_image_url),
         photo_meta = coalesce(photo_meta, '{}'::jsonb) || jsonb_build_object(
           'ba_session_id', p_session_id::text,
           'ba_bound_at', to_char(now() at time zone 'utc',
                                  'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         )
   where id = p_chart_id;

  -- 2) 세션 상태 전이 → is_complete 자동 true → 캐러셀 쿼리에서 이탈
  update public.ba_capture_sessions
     set customer_id = p_customer_id,
         chart_id    = p_chart_id,
         status      = 'linked',
         linked_at   = now()
   where id = p_session_id
  returning to_jsonb(ba_capture_sessions.*) into v_result;

  return v_result;
end $$;

grant execute on function public.bind_ba_session_to_chart(uuid, uuid, uuid)
  to authenticated;

comment on function public.bind_ba_session_to_chart(uuid, uuid, uuid) is
  'PRD v7.0 — B/A 세션을 고객 차트에 원자적으로 연결. 성공 시 🟢 판정 → 관리 케이스 피드로 이관.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) PostgREST 스키마 캐시 리로드
--    이걸 빠뜨리면 테이블이 실제로 존재해도 클라이언트가 PGRST205
--    ("Could not find the table ... in the schema cache")를 받는다.
-- ═══════════════════════════════════════════════════════════════════════════

notify pgrst, 'reload schema';
