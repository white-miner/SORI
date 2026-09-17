# PRD v7.0 — 홈 탭 전면 개편 및 'My Feed' 아키텍처 구축

**Status:** **Approved** · PO 마인드 Final Sign-off 2026-09-02 (Q1~Q7 종결)
**Author:** Expert Lead Engineer & UX/UI Architect
**Requested by:** PO 마인드 · 2026-09-02
**Supersedes:** PRD v5.3 / v5.4 (홈 탭 레이아웃 전면 대체) · v6.0 리포트 파이프라인은 **유지**
**Reference mockup:** `image_7.png`
**Rule:** **Approved · Implementation in progress (R1 → R8)**

> **⚠️ 버전 번호 안내**
> PO 지시서는 본 문서를 「PRD v5.3」으로 명명했으나, `docs/PRD_v5.3_HOME_DASHBOARD.md`는 이미 구현·머지된 SSOT이며 v5.4가 그 시각 레이어를 대체한 상태입니다. 기존 SSOT를 덮어쓰지 않기 위해 **v7.0**으로 채번했습니다. PO가 다른 번호를 원하시면 파일명만 교체하겠습니다.

---

## 0. Executive Summary

| 항목 | 현재 (v5.4) | v7.0 목표 |
|------|-------------|-----------|
| 홈 구조 | 단일 스크롤 Operation Desk | **[My Feed / My Asset / Timer] 상단 3탭** |
| 피드 성격 | `interleavedCaseFeed` = 불특정 다수 + Boost 광고 | **My Feed = 원장 본인 샵 데이터만**, Boost·랭킹 **완전 배제** |
| B/A 촬영 | `ShootInboxItem` (촬영 허브 안에 숨음, **SharedPreferences 로컬 전용**) | **홈 Hero 직하 캐러셀로 승격 + Supabase 테이블 승격** |
| B/A 상태 | 상태 개념 **없음** | **신호등(🔴/🟢) 파생 상태 + 자동 피드 이관** |
| 관리 케이스 | 없음 (보관함/탐색에 분산) | **무한 스크롤 상담 무기 피드** |

**핵심 설계 결단 3가지 (본 PRD의 축):**

1. **신호등은 저장하지 않고 파생한다.** `is_complete`를 별도 컬럼으로 쓰면 반드시 실제 데이터와 어긋납니다. 같은 row의 3개 필드(before URL / after URL / chart_id)로부터 **Postgres generated column + Dart getter**로 동일 수식을 파생시켜, 드리프트를 원천 차단합니다.
2. **'피드 이관'은 복사가 아니라 상태 전이다.** 초록 판정 시 데이터를 관리 케이스 테이블로 복사하지 않습니다. B/A 세션이 `chart_id`를 갖는 순간 캐러셀 쿼리에서 빠지고, 관리 케이스 쿼리(= `customer_charts` 조회)에 자동으로 잡힙니다. **한 벌의 진실만 존재**합니다.
3. **My Feed는 공개 게이트웨이를 타지 않는다.** 기존 공개 피드는 `087_consent_publish_gateway`(고객 동의 필수)와 Boost 경매를 통과해야 합니다. My Feed는 **원장 본인만 보는 프라이빗 자산**이므로 이 파이프라인을 전부 우회하고 RLS(`shop_memberships`)만으로 보호합니다. 이 분리가 무너지면 고객 사진이 외부에 노출되는 P0 사고가 됩니다.

---

## 1. 현행 코드 자산 인벤토리 (재사용 가능 / 갭)

먼저 "무엇을 새로 만들지 않아도 되는가"를 확정했습니다. 4대 컴포넌트 중 **Hero와 Quick Action은 사실상 이미 존재**하고, 신규 개발 리소스는 **B/A 캐러셀과 관리 케이스 피드에 집중**됩니다.

### 1.1 재사용 (신규 개발 불필요)

| 시안 요소 | 기존 자산 | 경로 |
|-----------|-----------|------|
| 대형 플립 시계 | `FlipClockDisplay(homeHero: true)` — v5.4에서 hero 모드 구현 + blank screen 핫픽스 완료 | `lib/features/operation/widgets/flip_clock_display.dart` |
| 날짜 헤더 (`📅 2026년 9월 2일`) | `HomeHeroCard` 상단 date row | `lib/features/visit/widgets/home_hero_card.dart` |
| 스케줄러 데이터 | `care_schedule_entries` 테이블 (`scheduled_at`, `customer_name`, `care_label`, `status`) | `supabase/migrations/096_care_schedule_entries.sql` |
| 스트립 초록 점 | `HomeVisualTokens.memoActiveFill` `#34C759` · `memoBarHeight 44` · `memoDotSize 8` | `lib/features/visit/home_visual_tokens.dart` |
| 신규 고객 라우팅 | `_startNewCustomerFlow()` → `VisitNewCustomerFormPage` | `lib/features/visit/visit_launcher_page.dart:173` |
| 재방문 라우팅 | `_startReturningCustomerFlow()` → `VisitExistingCustomerPickerPage` + `BaRecallCache.prefetch` | `lib/features/visit/visit_launcher_page.dart:199` |
| B/A 촬영기 | `SmartGuideCameraPage.open(kind:, ghostBeforeUrl:)` — After 잔상 가이드 내장 | `lib/views/smart_guide_camera_page.dart` |
| 사진 업로드 | `ChartPhotoCompressor.toWebp` + `ChartPhotoStorage.uploadWebp` → `chart_photos` 버킷 (public) | `019_chart_photos_storage.sql` |
| B/A 좌우 비교 | `BeforeAfterSlider` + `ChartImagePane` (`borderRadius`, `aspectRatio`, `dragHandleOnly` 지원) | `lib/widgets/before_after_slider.dart` |
| 고객 키워드 칩 | `chart.metadataSummaryLine` → **`"만 38세 · 여성 · 민감 · 부종 고민"`** — 시안 캡션과 정확히 일치 | `lib/models/customer_chart.dart:189` |
| 회차 / 케어명 | `chart.visitNumber`, `chart.serviceMenuLabel` (빈 값 시 `'관리 케이스'` fallback) | `lib/models/customer_chart.dart:167` |
| 북마크 (시안 우상단 🔖) | `case_bookmarks` + `toggle_case_bookmark()` RPC | `083_case_bookmarks_ssot.sql` |

> **판단:** 시안 캡션 `만 38세 , 여성, 민감,부종/ 순환고민`은 `metadataSummaryLine`의 출력과 구분자만 다릅니다. **새 모델을 만들지 않고 기존 getter를 그대로 렌더링**합니다.

### 1.2 갭 (신규 개발 필요)

| # | 갭 | 영향 |
|---|-----|------|
| **G1** | `ShootInboxItem`이 **SharedPreferences 전용** (`ShootInboxLocal`, key `sori_shoot_inbox_$shopId`) | 앱 삭제/기기 변경 시 **임시 사진 전량 소실**. 태블릿-폰 병행 불가. 서버가 상태를 모르므로 신호등 판정 불가 |
| **G2** | 큐 항목이 **낱장 단위** — Before와 After가 `sessionToken` 문자열로만 느슨히 묶임, 제약 없음 | 시안의 "카드 1장 = B/A 한 쌍" 표현 불가. 짝 판정 로직 부재 |
| **G3** | 신호등(완성/미완성) 상태 개념 자체가 **없음** | 4대 컴포넌트의 핵심 로직 전부 |
| **G4** | `bindShootInboxToCustomer()`가 **1장씩** 바인딩 (`sori_store.dart:5649`) | B/A 쌍을 원자적으로 차트에 연결 불가 (중간 실패 시 반쪽 상태) |
| **G5** | 미연결 사진이 `customerId: 'unbound'` 경로로 업로드 (`sori_store.dart:5613`) — **GC 없음** | 고아 사진 스토리지 영구 누적 |
| **G6** | 샵 스코프 + 무한 스크롤(keyset) 케이스 피드 쿼리 없음 | 관리 케이스 피드 |
| **G7** | 홈에 상단 탭 셸 없음 (`sori_router.dart:353`이 `VisitLauncherPage` 직결) | 3탭 구조 |
| **G8** | `interleavedCaseFeed`는 Boost 경매·타샵 노출 포함 (`sori_store.dart:3393`) | **My Feed에서 절대 재사용 금지** |

---

## 2. 정보 구조 (IA) — 상단 3탭

```
VisitLauncherPage  (GNB 홈, director only)
└── HomeTabShell                       [신규]
    ├── TabBar  [ My Feed | My Asset | Timer ]   sticky, canvasBg
    ├── Tab 0 — MyFeedPane              [본 스프린트 100%]
    │   ├── ① HomeHeroCard        (플립 시계 + 스케줄러 스트립)
    │   ├── ② HomeQuickActionRow  (신규 고객 / 재방문 고객)
    │   ├── ③ BaCaptureCarousel   (가로 스크롤 · 신호등)
    │   └── ④ ManagementCaseFeed  (무한 스크롤 · keyset)
    ├── Tab 1 — MyAssetPane             [뼈대만 — _ComingSoonPane]
    └── Tab 2 — TimerPane               [v5.4 자산 전량 이주 — Q1(b)]
        ├── HomeToolboxRow        (툴박스 6종)
        ├── CareStartButton       (케어 시작 · Green #34C759)
        └── HomePresetQuickPick   (5색 프리셋 · Path C SSOT)
```

> **Q1(b) 결정 반영:** v5.4에서 복구한 툴박스 6종·케어 시작 버튼·프리셋 퀵픽은 **삭제하지 않고 Timer 탭 한 곳으로 전량 이주**합니다. My Asset 탭은 이번 스프린트에서 순수 뼈대입니다. 이 이주는 위젯 이동만 수행하며 **Path C 로직·`VisitTimerStore` 상태·SharedPreferences 키는 일절 건드리지 않습니다.**

**스크롤 아키텍처 (v5.4 blank screen 재발 방지 필수 조건):**
`NestedScrollView`는 중첩 제약 계산이 복잡해 v5.4에서 겪은 unbounded height 붕괴를 재현할 위험이 큽니다. 대신 **탭별 독립 `CustomScrollView`** 를 쓰고, ①②③은 `SliverToBoxAdapter`, ④만 `SliverList`로 구성합니다. 캐러셀은 **고정 높이 `SizedBox`** 안의 가로 `ListView`로 감싸 세로 제약을 완전히 차단합니다.

> `HomeHeroCard`의 `FittedBox.scaleDown` 핫픽스는 **그대로 유지**합니다. `OverflowBox`로 되돌리지 않습니다.

---

## 3. 데이터베이스 설계

### 3.1 신규 테이블 `ba_capture_sessions` (마이그레이션 `108`)

캐러셀 **카드 1장 = 이 테이블의 row 1개**입니다. G1·G2·G3를 동시에 해결합니다.

```sql
create table if not exists public.ba_capture_sessions (
  id                 uuid primary key default gen_random_uuid(),
  shop_id            uuid not null references public.shops(id) on delete cascade,
  author_id          uuid references public.profiles(id) on delete set null,

  -- 기기 로컬 큐(ShootInboxItem.sessionToken)와의 멱등 키. 오프라인 재동기화 안전장치.
  session_token      text not null,

  before_image_url   text,
  after_image_url    text,
  before_captured_at timestamptz,
  after_captured_at  timestamptz,

  -- 차트 매핑 (초록 판정의 세 번째 조건)
  customer_id        uuid references public.customers(id)      on delete set null,
  chart_id           uuid references public.customer_charts(id) on delete set null,

  label              text not null default '',   -- 임시 메모 ("최진실님")
  status             text not null default 'draft'
                     check (status in ('draft','linked','archived')),

  deferred_at        timestamptz,   -- "완료" 눌러 옆으로 밀어둔 시각 (경고는 유지)
  linked_at          timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  -- ★ 신호등 SSOT — 저장하지 않고 같은 row에서 파생
  is_complete boolean generated always as (
    before_image_url is not null and before_image_url <> ''
    and after_image_url is not null and after_image_url <> ''
    and chart_id is not null
  ) stored,

  unique (shop_id, session_token)
);

create index if not exists idx_ba_sessions_carousel
  on public.ba_capture_sessions (shop_id, status, created_at desc)
  where status = 'draft';
```

**RLS:** `care_schedule_entries`(096)와 동일 패턴. 읽기 = `shop_memberships` 소속, 쓰기 = `role in ('owner','director')`. **공개 select 정책 없음.**

### 3.2 신호등 판정 로직 (PO 명세 → 수식)

| 조건 | `before` | `after` | `chart_id` | 판정 | 캐러셀 |
|------|----------|---------|-----------|------|--------|
| 아무것도 없음 | ✗ | ✗ | ✗ | 🔴 (빈 카드) | 표시 — 촬영 유도 |
| Before만 | ✓ | ✗ | ✗ | 🔴 | 표시 |
| After만 | ✗ | ✓ | ✗ | 🔴 | 표시 |
| 2장 O, 차트 미연동 | ✓ | ✓ | ✗ | 🔴 | 표시 — **"고객 연결 필요"** |
| 2장 O + 차트 매핑 | ✓ | ✓ | ✓ | 🟢 | **사라짐 → 관리 케이스로 이관** |

Dart 미러 (동일 수식, 서버 컬럼과 1:1):

```dart
bool get isComplete =>
    (beforeImageUrl?.trim().isNotEmpty ?? false) &&
    (afterImageUrl?.trim().isNotEmpty ?? false) &&
    (chartId?.trim().isNotEmpty ?? false);

/// 🔴 세부 사유 — 카드 배지 문구 분기용
BaDraftReason get reason {
  if (isComplete) return BaDraftReason.complete;
  if (!hasBefore && !hasAfter) return BaDraftReason.empty;
  if (!hasBefore) return BaDraftReason.missingBefore;
  if (!hasAfter) return BaDraftReason.missingAfter;
  return BaDraftReason.unlinked;   // 2장 O · 차트 X
}
```

> **PO 명세 반영:** "완료 버튼을 눌러 리스트를 옆으로 넘겨둘 수는 있으나, 경고 표시로 계속 남겨둔다" → `deferred_at`을 채우되 **`status`는 `draft` 유지**. 정렬만 뒤로 밀리고 🔴는 그대로 남습니다. 삭제가 아니라 **후순위화**입니다.

### 3.3 이관 RPC — 원자적 바인딩 (G4 해결)

반쪽 상태(Before만 차트에 붙고 After는 실패)를 막기 위해 단일 트랜잭션 RPC로 처리합니다.

```sql
create or replace function public.bind_ba_session_to_chart(
  p_session_id uuid,
  p_customer_id uuid,
  p_chart_id uuid
) returns jsonb
language plpgsql security definer as $$
declare v_s public.ba_capture_sessions;
begin
  select * into v_s from public.ba_capture_sessions
   where id = p_session_id for update;
  if not found then raise exception 'ba session not found'; end if;

  -- 1) 차트에 B/A URL 반영 (있는 것만 덮어씀)
  update public.customer_charts
     set before_image_url = coalesce(nullif(v_s.before_image_url,''), before_image_url),
         after_image_url  = coalesce(nullif(v_s.after_image_url,''),  after_image_url),
         photo_meta = photo_meta || jsonb_build_object(
           'ba_session_id', p_session_id::text,
           'bound_at', now()
         )
   where id = p_chart_id;

  -- 2) 세션 상태 전이 → is_complete 자동 true → 캐러셀에서 이탈
  update public.ba_capture_sessions
     set customer_id = p_customer_id,
         chart_id    = p_chart_id,
         status      = 'linked',
         linked_at   = now(),
         updated_at  = now()
   where id = p_session_id
  returning to_jsonb(ba_capture_sessions.*) into v_s;

  return to_jsonb(v_s);
end $$;
```

### 3.4 두 개의 쿼리 = 두 개의 영역

```sql
-- ③ B/A 캐러셀 : 미완성만, 밀어둔 것은 뒤로
select * from public.ba_capture_sessions
 where shop_id = :shop and status = 'draft' and is_complete = false
 order by (deferred_at is not null), created_at desc;

-- ④ 관리 케이스 : 완성된 차트만 (keyset 무한 스크롤)
select c.* from public.customer_charts c
 where c.shop_id = :shop
   and coalesce(c.before_image_url,'') <> ''
   and coalesce(c.after_image_url,'')  <> ''
   and (coalesce(c.created_at, c.visit_checked_at), c.id) < (:cursor_at, :cursor_id)
 order by coalesce(c.created_at, c.visit_checked_at) desc, c.id desc
 limit 10;
```

> **여기가 '자동 이관'의 전부입니다.** 별도 이관 job도, 복사 테이블도 없습니다. `chart_id`가 채워지면 ③에서 빠지고 ④에 나타납니다. `OFFSET` 대신 keyset 커서를 쓰는 이유는, 스크롤 중 새 케이스가 추가돼도 항목이 중복/누락되지 않기 때문입니다.

### 3.5 스토리지 경로 및 GC (G5)

| | 현재 | v7.0 |
|---|------|------|
| 경로 | `chart_photos/…/unbound/…` | `chart_photos/{shopId}/ba_draft/{sessionToken}/{before\|after}.webp` |
| 바인딩 후 | 그대로 방치 | **URL 재사용** (물리 이동 없음 — 비용 0) |
| 고아 정리 | 없음 | `status='draft' and created_at < now() - 30d` → `archived` + 스토리지 삭제. **정리 job은 v7.1로 이월**, v7.0은 경로 규약과 `archived` 상태만 확정 |

### 3.6 로컬 큐 마이그레이션 (기존 데이터 보존)

기존 `sori_shoot_inbox_$shopId`에 남아있는 원장님 사진을 잃지 않도록, 최초 1회 승격을 수행합니다.

1. 앱 부팅 시 `ShootInboxLocal.load(shopId)` 실행.
2. 같은 `sessionToken`끼리 묶어 `ba_capture_sessions` row로 upsert (`unique(shop_id, session_token)` 덕분에 **재실행 안전**).
3. 성공 시 로컬 키 삭제. 실패 시 로컬 유지 후 다음 부팅 재시도.
4. `ShootInboxLocal`은 **오프라인 쓰기 버퍼로 강등**해 존치 (제거하지 않음).

---

## 4. UI 렌더링 전략 — CDG(Calm Data Glass) 적용

기존 `HomeVisualTokens`를 확장합니다. **하드코딩 색상·수치 금지**, 전량 토큰 경유가 원칙입니다.

### 4.1 ① Hero — 플립 시계 + 스케줄러 스트립

시안 상단 카드. `HomeHeroCard`를 유지하되 하단부만 교체합니다.

| 요소 | 스펙 | 비고 |
|------|------|------|
| 날짜 행 | `dateIconSize 16` · `dateTextSize 13` · `#111111` · minHeight 44 | v5.4 유지 |
| 플립 시계 | `flipDigitHeightHome 132` · `flipDigitWidthHome 82` · `flipTileFill #111111` · radius 14 | `homeHero: true` |
| 초 단위 | 시안 우하단 소형 `11` | 기존 `cornerSsScale` 활용 |
| **스케줄러 스트립** | h `44` · radius `22` · fill `#F4F6F9` · 좌측 dot `8dp` `#34C759` (inset 14) · text `12sp` | **`MemoStackDisplay` 대체** |
| 스트립 문구 | `HH:mm · {customer_name}님 {care_label}` → `12:30 김민정님 상담예약` | `care_schedule_entries` |
| 빈 상태 | dot `#C7C7CC` + `"오늘 예약된 일정이 없습니다"` | 탭 시 일정 추가 |
| 탭 | 시간대별 메모/일정 팝업 (`showModalBottomSheet`) | |

**정렬 규칙:** `status='scheduled'` 중 `scheduled_at >= now()`인 **가장 가까운 1건**. 없으면 오늘 마지막 완료 건을 회색으로. 2건 이상이면 우측에 `+N` 칩.

### 4.2 ② Quick Action

| | 신규 고객 | 재방문 고객 |
|---|-----------|-------------|
| Fill | **`#8B5CF6` (violet)** — 시안 | `#FFFFFF` + border `#E5E5EA` |
| Text/Icon | `#FFFFFF` · `person_add` | `#111111` · `history` |
| 크기 | 좌우 균등 `Expanded` · h `52` · radius `16` · gap `10` | 동일 |
| 라우팅 | `_startNewCustomerFlow()` | `_startReturningCustomerFlow()` |

> **Q2(a) 결정 반영 — 시안 우선.** 신규 고객 = **보라 `#8B5CF6`** (신규 토큰 `HomeVisualTokens.quickNewFill`). v5.4의 Green `#34C759`는 **Timer 탭 케어 시작 CTA 전용**으로 격하되어 계속 살아 있습니다. 즉 CDG 헌법상 Green은 "케어 실행", 보라는 "신규 진입"으로 의미가 분리됩니다.

### 4.3 ③ B/A 등록 캐러셀

```
┌ B/A 등록 ─────────────────────────────────────────────
│ ┌──────────┐  ┌──────────┐  ┌──────────┐
│ │  ⊕  │ ⊕  │  │🟢 최진실님│  │🔴 우…    │   →  가로 스크롤
│ │Before│After│ │ [B][A]   │  │ [B][ ? ] │
│ └──────────┘  └──────────┘  └──────────┘
```

| 토큰 | 값 |
|------|-----|
| `baCarouselHeight` | `132` (고정 — 세로 제약 차단) |
| `baCardW` / `baCardH` | `148` / `112` |
| `baCardRadius` | `16` |
| `baCardGap` | `10` |
| `baDotSize` | `8` |
| `baDotRed` | `#FF3B30` (`SoriTokens.systemRed`) |
| `baDotGreen` | `#34C759` (`memoActiveFill`) |
| `baAddCircle` | `36` · fill `#FFFFFF` · icon `#111111` |
| 섹션 헤더 | `"B/A 등록"` `13sp` `#111111` w600 |

**카드 구조:** 좌우 2분할. 좌 = Before 슬롯, 우 = After 슬롯. 빈 슬롯은 `⊕`, 채워진 슬롯은 썸네일(`BoxFit.cover`). 좌상단에 상태 dot + 라벨.

**인터랙션:**
- `⊕` 탭 → `SmartGuideCameraPage.open(kind:)`. After 촬영 시 같은 세션의 Before를 `ghostBeforeUrl`로 전달해 **잔상 가이드** 제공 (기존 기능 재활용).
- **차트 미연동 상태 강조:** 2장 다 찍혔는데 `chart_id`가 없으면 카드 하단에 `"고객 연결"` 액션 칩을 띄웁니다. 탭 → 고객 선택 시트 → `bind_ba_session_to_chart` → **카드가 우측으로 슬라이드 아웃되며 ④ 최상단에 삽입**되는 전이 애니메이션(`AnimatedList`, 320ms).
- 첫 번째 슬롯은 항상 "새 세션 만들기" 빈 카드로 고정합니다. 원장님이 스크롤 없이 즉시 촬영 가능해야 하기 때문입니다.

**넛지:** 🔴가 1개 이상이면 섹션 헤더 우측에 `🔴 N`. `deferred_at`이 있어도 카운트에 포함합니다(PO 명세: 경고 유지).

> **Q3(a) 결정 반영 — 🟢는 영구 상태가 아니다.** 초록 점은 **이관 확정 애니메이션(320ms) 동안만** 렌더링되는 전이 상태입니다. `bind_ba_session_to_chart` 성공 즉시 카드에 🟢를 찍고 우측 슬라이드 아웃 → 다음 프레임부터 캐러셀 쿼리(`is_complete = false`)에서 자연 제외됩니다. **별도 "숨김" 플래그를 두지 않습니다.** 시안의 🟢 카드는 이 320ms 순간을 포착한 것으로 해석합니다.

### 4.4 ④ 관리 케이스 피드

시안 카드 해부:

| 영역 | 소스 | 스펙 |
|------|------|------|
| 좌상단 `N 회차` | `chart.visitNumber` | `12sp` `#111111` w600 |
| 중앙 `스페셜 웨딩 케어` | `chart.serviceMenuLabel` | `14sp` w700 |
| 우상단 🔖 | `toggle_case_bookmark(chart_id)` | `20dp` |
| 이미지 | **`BeforeAfterSlider`**, `Before`/`After` 필 라벨 오버레이 | `aspectRatio 4/3` · radius 0 (edge-to-edge) |
| 우하단 확대 | 전체화면 비교 뷰어 | `28dp` glass circle |
| 캡션 | **`chart.metadataSummaryLine`** → `만 38세 · 여성 · 민감 · 부종 고민` | `12sp` `#8E8E93` |

| 토큰 | 값 |
|------|-----|
| `caseCardRadius` | `20` |
| `caseCardFill` | `#FFFFFF` |
| `caseCardShadow` | blur 30 · `#0A000000` · offset (0,8) |
| `caseCardGap` | `12` |
| `casePillFill` | `#00000073` (glass) · text `#FFFFFF` `11sp` |

**좌우 슬라이드 컨트롤 (Q3 관련):** 시안의 `Before`/`After` 양쪽 필 배치는 **커튼형 드래그 슬라이더**(`BeforeAfterSlider`, 이미 보유)와 가장 잘 맞습니다. 상담 중 원장님이 한 손가락으로 경계선을 문지르며 설명하는 동작이 자연스럽고, 페이지 넘김보다 변화량이 즉각적으로 읽힙니다. `dragHandleOnly: false`로 전체 영역 드래그를 허용합니다.

**무한 스크롤:** 페이지 10건, 잔여 3건 지점에서 prefetch. 하단 스켈레톤 shimmer. `RefreshIndicator`로 상단 리프레시.

**빈 상태:** `"완성된 B/A 케이스가 아직 없습니다 — 위에서 Before/After를 등록해 보세요"` + ③으로 스크롤하는 CTA.

> **Q5(a) 결정 반영 — 역할 분리 엄수.** After가 없는 미완성 차트는 이 피드에 **노출하지 않습니다**(회색 처리조차 하지 않음). ③ 캐러셀 = 미완성 독촉, ④ 피드 = 완성 자산. 이 경계가 흐려지면 상담 중 미완성 케이스가 고객에게 보이는 사고가 납니다.

### 4.5 My Asset / Timer 탭

- **My Asset:** `_ComingSoonPane(title:, subtitle:)` 뼈대만. (Q7)
- **Timer:** Q1(b)에 따라 `HomeToolboxRow` + `CareStartButton` + `HomePresetQuickPick`을 **v5.4 시각 스펙 그대로** 이주. 픽셀 값·토큰·핸들러 시그니처를 변경하지 않아 v5.4 골든 테스트가 그대로 통과해야 합니다.

---

## 5. 프라이버시 및 격리 (P0)

| 규칙 | 강제 수단 |
|------|-----------|
| My Feed는 **자기 샵 데이터만** | 쿼리 `shop_id = session.shopId` + RLS `shop_memberships` |
| Boost/광고 **완전 배제** | `interleavedCaseFeed`·`activeBoostPlacements` **import 금지** (테스트로 감시) |
| 고객 동의 게이트웨이 **미경유** | 공개 발행(`087`)과 무관 — 단, **외부 공유 액션은 기존 게이트웨이를 반드시 통과** |
| 임시 사진 공개 노출 금지 | `chart_photos` 버킷이 **public read**이므로 URL 추측 방지를 위해 `session_token`에 UUID 사용 |

> **리스크 명시 · Q6(a) 결정:** `chart_photos` 버킷은 019 마이그레이션 기준 `public: true`입니다. 즉 URL을 아는 사람은 누구나 고객 얼굴 사진을 열 수 있습니다. v7.0은 **추측 불가능한 UUID `session_token` 경로**로 완화만 하고, **버킷 private 전환 + signed URL은 v7.1 보안 스프린트로 분리**합니다. 이 항목은 미해결 리스크로 §9에 존치되며, v7.1 착수 전까지 닫히지 않습니다.

---

## 6. 구현 계획

| # | 작업 | 산출물 |
|---|------|--------|
| **R1** | 마이그레이션 `108_ba_capture_sessions.sql` — 테이블·인덱스·RLS·`bind_ba_session_to_chart` RPC | SQL |
| **R2** | `BaCaptureSession` 모델 + `isComplete`/`reason` getter + repository 3종(Supabase/Memory/interface) CRUD | Dart |
| **R3** | `SoriStore`: `baDraftSessions`, `createBaSession`, `attachBaPhoto`, `deferBaSession`, `bindBaSessionToChart` + **로컬 큐 승격 마이그레이션** | Dart |
| **R4** | `HomeTabShell` (3탭) + `MyFeedPane` 스크롤 골격 + `MyAssetPane`(`_ComingSoonPane`) + **`TimerPane`에 v5.4 자산 3종 이주** (Q1b) | Dart |
| **R5** | `HomeSchedulerStrip` + `HomeQuickActionRow` (기존 라우팅 결선) | Dart |
| **R6** | `BaCaptureCarousel` + 카드 + 신호등 + 고객 연결 시트 + 이관 애니메이션 | Dart |
| **R7** | `ManagementCaseFeed` — keyset 페이지네이션 + `ManagementCaseCard` + 북마크 + 전체화면 뷰어 | Dart |
| **R8** | `HomeVisualTokens` 확장 · 유닛/위젯/골든 테스트 · CI 등록 | 테스트 |

**의존성:** R1 → R2 → R3 → (R4 ∥ R5) → R6 → R7 → R8. R4/R5는 병렬 가능합니다.

**테스트 게이트:**
- 신호등 진리표 5케이스 전수 유닛 테스트
- `bind_ba_session_to_chart` 후 캐러셀 이탈 + 피드 진입 상태 전이 테스트
- 로컬 큐 승격 **멱등성** 테스트 (2회 실행 시 중복 row 0)
- keyset 페이지네이션 중복/누락 0 테스트
- `MyFeedPane`이 `interleavedCaseFeed`를 호출하지 않음을 검증하는 **격리 테스트**
- `HomeVisualTokens` 골든 (v5.4 `HomeVisualGoldenHarness` 방식 — 폰트 네트워크 의존 없음)

---

## 7. 인수 조건 (Acceptance Criteria)

1. 홈 진입 시 `[My Feed | My Asset | Timer]` 3탭이 보이고 My Feed가 기본 선택된다.
2. 차트를 열지 않은 상태에서 캐러셀 `⊕`만으로 Before/After를 촬영·저장할 수 있다.
3. 앱을 완전 종료 후 **다른 기기에서 로그인**해도 임시 B/A 세션이 그대로 보인다. (G1 해결 증명)
4. 사진 1장만 있는 세션은 🔴, 2장+차트 매핑 완료 세션은 🟢로 표시된다.
5. "완료"로 밀어둔 🔴 세션은 캐러셀 뒤로 이동하되 **사라지지 않고** 경고 카운트에 남는다.
6. 고객 차트에 연결하는 순간 카드가 캐러셀에서 사라지고 관리 케이스 피드 **최상단**에 나타난다.
7. 관리 케이스 카드에 회차·케어명·고객 키워드 한 줄이 모두 보이고, 이미지 좌우 슬라이드로 B/A가 비교된다.
8. 관리 케이스 피드를 스크롤하면 10건 단위로 끊김 없이 추가 로드되며 중복 항목이 없다.
9. My Feed 어디에도 **타 샵 데이터나 Boost 게시물이 노출되지 않는다.**
10. 기존 로컬 큐(`sori_shoot_inbox_*`)에 있던 사진이 **1장도 유실되지 않고** 승격된다.
11. **Timer 탭에서 v5.4의 툴박스 6종·케어 시작·프리셋 퀵픽이 픽셀 그대로 동작**하며, Path C 트리거와 `homeSelectedPresetSlot` 영속이 회귀 없이 유지된다. (v5.4 골든 테스트 무수정 통과)

---

## 8. PO Decisions — **종결 (2026-09-02)**

| # | 질문 | **PO 결정** | 구현 영향 |
|---|------|------------|-----------|
| **Q1** | v5.4 툴박스 6종 · 케어 시작 · 프리셋 퀵픽의 행선지 | **(b) 전부 Timer 탭으로 모아서 이동** | §2 IA · §4.5 · R4에 이주 작업 포함. My Asset은 순수 뼈대 |
| **Q2** | 신규 고객 버튼 색상 (시안 보라 vs v5.4 Green) | **(a) 시안 우선 — 보라 `#8B5CF6`** | §4.2 · `quickNewFill` 토큰 신설. Green은 Timer 탭 케어 시작 전용 |
| **Q3** | 시안 캐러셀의 🟢 카드 vs "초록은 사라진다" 충돌 | **(a) 320ms 확정 애니메이션 중에만 🟢, 즉시 제거** | §4.3 · 별도 숨김 플래그 없음. 쿼리 `is_complete = false`가 유일한 필터 |
| **Q4** | 바인딩 시 오늘 회차가 없으면? | **제안 채택 — `ensureTodayShootChart()` 재사용** | 직전 케어 내용 복사해 신규 회차 자동 생성 (`sori_store.dart:5499`) |
| **Q5** | 관리 케이스에 After 없는 차트도 회색 노출? | **(a) 아니오 — 두 장 완비만 노출** | §4.4 · ③/④ 역할 완전 분리 |
| **Q6** | `chart_photos` public → private + signed URL | **(a) v7.1 별도 보안 스프린트로 분리** | v7.0은 UUID 경로 완화만. §9 리스크에 **미해결로 존치** |
| **Q7** | My Asset 탭의 최종 정체 | **이번엔 뼈대만** | 다음 스프린트에서 기획 |

---

## 9. Risk Register

| 리스크 | 영향 | 완화 |
|--------|------|------|
| 중첩 스크롤로 인한 blank screen 재발 (v5.4 사고) | **P0** | `NestedScrollView` 미사용 · 캐러셀 고정 높이 · `FittedBox.scaleDown` 유지 · 골든 테스트 |
| 로컬 큐 승격 중 사진 유실 | **P0** | 업로드 성공 확인 후에만 로컬 삭제 · `unique(shop_id, session_token)` 멱등 · 실패 시 로컬 존치 |
| 공개 피드 코드 재사용으로 타샵/고객 데이터 노출 | **P0** | import 금지 격리 테스트 · RLS 이중 방어 |
| **`chart_photos` public 버킷 — URL만 알면 고객 얼굴 사진 열람 가능** | **P1 · 미해결 존치** | v7.0은 UUID 경로 완화만. **v7.1 보안 스프린트에서 private + signed URL 전환** (Q6a) |
| Timer 탭 이주 중 Path C 로직·프리셋 영속 회귀 | P1 | 위젯 이동만 수행 · 핸들러 시그니처 불변 · v5.4 테스트 무수정 통과를 게이트로 |
| `is_complete` generated column과 Dart getter 수식 불일치 | P1 | 진리표 유닛 테스트로 양측 동시 검증 |
| 고아 사진 스토리지 누적 | P2 | `archived` 상태 확보 후 v7.1 GC job |
| 무한 스크롤 offset 방식의 중복/누락 | P2 | keyset 커서 채택 |

---

## 10. 범위 밖 (Out of Scope)

- My Asset 탭의 **실제 기능** (뼈대만)
- 고아 사진 GC 배치 job (v7.1)
- 스토리지 private + signed URL 전환 (**v7.1 보안 스프린트 확정** — Q6a)
- 관리 케이스의 외부 공유·인스타 발행 (기존 동의 게이트웨이 경유, 미변경)
- v6.0 방문 종료 리포트 파이프라인 (**변경 없이 유지**)

---

## 11. 구현 완료 기록 (2026-09-02)

R1~R8 전량 구현 완료. 아래는 설계 대비 실제 구현에서 조정된 지점이다.

### 11.1 산출물

| # | 산출물 | 경로 |
|---|--------|------|
| R1 | 테이블 · 부분 인덱스 · RLS · `bind_ba_session_to_chart` RPC | `supabase/migrations/108_ba_capture_sessions.sql` |
| R2 | `BaCaptureSession` · `BaCaptureStatus` · `BaDraftReason` | `lib/models/ba_capture_session.dart` |
| R2 | 리포지토리 3종 (interface / Supabase / Memory) | `lib/data/*.dart` |
| R3 | 세션 CRUD · 무손실 멱등 승격 · `managementCaseCharts()` | `lib/services/sori_store.dart` |
| R4 | `HomeTabShell` 3탭 · Timer 탭 이주 · `_ComingSoonPane` | `lib/features/visit/visit_launcher_page.dart` |
| R5 | 스케줄러 스트립 · 퀵액션 행 | `lib/features/visit/widgets/home_scheduler_strip.dart`, `home_quick_action_row.dart` |
| R6 | B/A 캐러셀 · 신호등 · 320ms 전이 | `lib/features/visit/widgets/ba_capture_carousel.dart` |
| R7 | 관리 케이스 카드 · keyset 커서 | `lib/features/visit/widgets/management_case_card.dart`, `management_case_paginator.dart` |
| R8 | 토큰 확장 · 유닛/위젯/E2E/골든 60건 | `lib/features/visit/home_visual_tokens.dart`, `test/my_feed_v70*.dart` |

### 11.2 설계 대비 조정

1. **사진 업로드 주체.** 설계 시점에는 `attachBaPhoto`가 직접 압축·업로드하는 것으로 잡았으나, `SmartGuideCameraPage`가 이미 WebP 압축과 Storage 업로드를 수행하고 URL을 반환한다. 중복 업로드를 없애기 위해 `attachBaPhoto`는 **URL만 받아 세션에 부착**한다. 스토리지 경로 격리는 카메라에 넘기는 `customerId` 세그먼트(`SoriStore.baDraftStorageSegment` → `ba_draft_{uuid}`)로 달성했다.
2. **관리 케이스 데이터 소스.** 부트스트랩이 이미 샵 차트 전량을 메모리에 적재하므로, DB 왕복을 추가하지 않고 `ManagementCasePaginator`가 **동일한 (게시시각, id) 키셋 커서를 클라이언트에서** 적용한다. 커서 규약은 §3.4 SQL과 동일하므로, 향후 서버 페이징으로 옮겨도 동작이 바뀌지 않는다.
3. **`HomeHeroCard` 하위 호환.** `schedulerStrip`을 선택 파라미터로 두어, 미지정 시 v5.4 `MemoStackDisplay`로 폴백한다. 덕분에 v5.4 hero 렌더 테스트가 무수정으로 통과한다.
4. **🔴 배지 문구.** `unlinked` 상태의 배지를 `고객 연결` → **`연결 대기`** 로 변경했다. 카드 하단 액션 칩이 `고객 연결`이라 같은 문구가 한 카드에 두 번 나오는 문제를 위젯 테스트가 잡아냈다.
5. **카드 높이 계산.** 슬롯 영역을 고정 높이에서 `Expanded`로 바꿨다. "고객 연결" 칩이 붙는 경우 고정 높이 계산이 7px 넘쳤고, 이 역시 위젯 테스트가 선제 검출했다.

### 11.3 검증 결과

| 게이트 | 결과 |
|--------|------|
| 신호등 진리표 6케이스 | 통과 |
| 로컬 큐 승격 (병합 · 멱등 · 빈 URL 스킵) | 통과 — 재실행 시 중복 row 0 |
| keyset 페이지네이션 (중복·누락 0, 상단 삽입 내성) | 통과 |
| 🟢 이관 (캐러셀 이탈 → 피드 진입) | 통과 |
| 공개 피드 API 격리 (4개 파일 정적 스캔) | 통과 |
| **v5.4 골든 · hero 렌더 핫픽스 테스트 무수정 통과** | **통과** |
| E2E 3탭 셸 · blank screen 감시 · 캐러셀↔피드 스크롤 | 통과 |
| 전체 스위트 회귀 | 278 통과 / 20 실패 — **베이스라인과 동일** (전부 기존 실패) |

기존 실패 20건은 fan-boost, feed interleave, brand SVG, weverse token, smart guide camera, landing 위젯으로 v7.0 범위 밖이며, 착수 전 `git stash` 베이스라인 측정에서 동일하게 재현됨을 확인했다.

### 11.4 잔여 리스크 (v7.1 이월)

- `chart_photos` 버킷 public read — UUID 경로 완화만 적용됨 (Q6a).
- 고아 draft 세션 스토리지 GC job 미구현 (`archived` 상태만 확보).
- `promoteLocalShootInbox`는 샵 단위 1회 실행 후 세션 내 재시도하지 않는다. 승격 실패분은 다음 앱 부팅에 재시도된다.

---

**PO 최종 승인 완료 (2026-09-02).** Q1~Q7 종결 · R1~R8 구현 완료.

---

## 12. v7.0.1 핫픽스 — 런타임 결함 4종 (2026-09-02)

첫 실기 검증(`image_8`~`image_15`)에서 드러난 P0 결함을 정리한다.

### 12.1 B1 — PGRST205: 마이그레이션 미적용 내성

**현상.** `Could not find the table 'public.ba_capture_sessions' in the schema cache (PGRST205)`
가 붉은 스낵바로 그대로 노출되고, B/A 등록이 완전히 막혔다.

**원인.** `108_ba_capture_sessions.sql`이 아직 대상 Supabase에 적용되지 않았다.
PostgREST는 스키마를 캐시하므로, 테이블을 만들어도 캐시를 갱신하지 않으면 같은
오류가 계속 난다.

**조치.**

1. `108_ba_capture_sessions.sql` 말미에 `notify pgrst, 'reload schema';` 를 추가했다.
   마이그레이션을 적용하는 것만으로 스키마 캐시가 함께 갱신된다.
2. `lib/utils/supabase_schema_error.dart` — `PGRST205` / `PGRST202` / `42P01` /
   `42883` 를 "일시 장애"가 아닌 "기능 부재"로 분류한다. 재시도로 풀리지 않으므로
   호출자가 폴백으로 내려가야 하는 신호다.
3. `SoriStore.baRemoteReady` 도입. false가 되면 캐러셀 전체가 기존 로컬 촬영 큐
   (`sori_shoot_inbox_*`) 위에서 동작한다. 조회·촬영·밀어두기·이관 4개 경로 모두
   로컬 분기를 가진다. 원장 화면에서는 기능이 그대로 살아 있고, 헤더에
   `이 기기에만 저장 중` 문구만 추가로 뜬다.
4. `promoteLocalShootInbox`는 테이블 부재를 감지하면 **즉시 중단**하고 로컬 큐를
   한 장도 지우지 않는다. 마이그레이션이 적용되는 순간 다음 새로고침에서
   자동으로 서버 승격이 재개된다 (`unique(shop_id, session_token)` 멱등 보장).
5. 스낵바에 PostgrestException 원문 대신 대응 가능한 문구를 노출한다.

**적용 절차 (운영).** Supabase SQL Editor에서 `108_ba_capture_sessions.sql` 전문을
실행한다. 파일이 idempotent(`if not exists` / `create or replace`)하므로 재실행해도
안전하며, 마지막 `notify`가 캐시까지 갱신한다.

### 12.2 B2 — 관리 케이스 UI 디테일

- **뱃지 중복.** `BeforeAfterSlider`가 이미 `_CornerTag('Before'/'After')`를
  `left:10, top:10` / `right:10, top:10`에 그린다. `ManagementCaseCard`가 같은
  좌표에 `_Pill`을 한 겹 더 얹고 있었다. `_Pill`을 제거했다.
- **캡션 시인성.** `caseCaptionSize` 12 → 13, `w600` 지정, 색을 `#8E8E93` →
  `#5B5B60`으로 낮추고 상단 헤어라인(`caseCaptionDivider`)으로 사진과 영역을 끊었다.
  헤더도 15/13으로 올리고 `3 회차` → `3회차`로 붙였다.
- **탭 텍스트.** 전역 `soriTabBarTheme`은 채워진 검정 칩(`#18181B`) indicator를
  쓴다. `_HomeTabBar`가 `indicatorColor`만 지정해 이 칩을 상속했고, 그 위에 검정
  라벨이 얹혀 선택 탭이 통째로 까만 사각형이 됐다. `UnderlineTabIndicator`를
  명시해 테마를 덮어쓰고 라벨이 선명한 `#111111`로 읽히게 했다.

### 12.3 B3 — 관리 케이스 북마크 필터

섹션 헤더 우측에 책갈피 토글을 추가했다. 켜면 `isChartBookmarked`로 소스를 좁히고
페이지네이터를 리셋한다. 필터가 켜진 상태에서 북마크를 해제하면 해당 카드가 즉시
목록에서 빠진다. 빈 상태 문구도 필터 상태에 맞춰 분기한다.

### 12.4 B4 — 고객 차트 트리 구조

**현상.** `image_13`~`image_15`에서 같은 `1회차`가 5~6벌 나열됐다.

**원인.** 저장소에는 동의서 체결·시술 기록·재저장이 각각 별개 row로 쌓이는데,
차트 관리 화면이 이를 **평면 리스트 그대로** 렌더링했다.

**조치.** `lib/models/customer_chart_tree.dart` — 평면 목록을
**[고객 1 → 회차 N → 기록 M]** 트리로 접는 순수 로직을 분리했다.

- `visitNumber`로 group by → 회차 번호는 화면에서 **항상 고유**하다.
- 회차 안에서 `(시술명, 요약, 날짜)`가 같은 row는 한 노드로 병합하고
  `duplicateCount`로 몇 벌이 접혔는지 남긴다.
- 서로 다른 기록(예: `전자 동의서` vs `테라노바`)은 지우지 않고 하위 가지로
  펼쳐 본다. 데이터 손실 없이 목록만 정리된다.
- 대표 기록은 정보량 점수(B/A 완비 > 사진 일부 > 요약/인사이트 > 최신)로 뽑는다.
- 루트에 고객당 고정 차트 번호(`chartCodeFor`, 고객 id 파생)와 총 회차 · 최근
  방문을 보여주는 헤더 카드를 세웠다.

### 12.5 검증

| 게이트 | 결과 |
|--------|------|
| 차트 트리 그룹핑 · 중복 병합 · 대표 선정 (7케이스) | 통과 |
| PGRST205 폴백 (조회 · 촬영 · 이관 · 큐 보존, 4케이스) | 통과 |
| 뱃지 1쌍만 렌더 · 캡션 13sp/w600 고정 | 통과 |
| 선택 탭 밑줄 indicator · 라벨 명도 < 0.2 | 통과 |
| 북마크 필터 토글 E2E | 통과 |
| 골든 (v5.4 · v7.0) | 통과 (캡션 토큰 2종 추가 반영) |
| 전체 스위트 회귀 | 20 실패 — **베이스라인과 동일 집합** |

---

## 13. v7.0.2 — 플립 시계 오버플로우 + 캐러셀 정책 변경 (2026-09-02)

### 13.1 C1 — 플립 시계 초(SS) 오버플로우

**현상.** 메인 플립 시계 우측의 초 단위가 카드 밖으로 밀려나 잘렸다.

**원인.** `_buildClockRow`가 SS를 **음수 offset**으로 배치했다.

```dart
Stack(clipBehavior: Clip.none, children: [
  row,
  Positioned(right: -ssSize * 0.9, bottom: -ssSize * 0.15, child: ssText),
]);
```

`Stack`은 positioned가 아닌 자식(`row`)에만 맞춰 크기를 잡는다. SS는 음수 offset
탓에 그 경계 **밖**에 그려지므로, 부모 `FittedBox(scaleDown)`이 SS 폭을 계산에
넣지 못한다. 결과적으로 시계는 축소되지 않고 SS만 화면 밖으로 잘려 나갔다.

**조치.** SS 자리를 미리 떼어 두고 Stack의 크기를 그 여백까지 포함해 확정한다.

```dart
Stack(children: [
  Padding(padding: EdgeInsets.only(right: gutter), child: row), // 크기 결정
  Positioned(right: 0, bottom: …, width: ssBoxW, height: ssBoxH,
             child: FittedBox(fit: BoxFit.scaleDown, child: ssText)),
]);
```

- `gutter = ssBoxW + ssSize * 0.20` — SS는 항상 안쪽에 놓인다.
- `Positioned`에 `width`/`height`를 못박고 그 안에 `FittedBox`를 둬서, 폰트가
  바뀌어도 SS 박스가 커지지 않는다.
- HH:MM 타일 좌표는 SS 유무와 무관하게 동일하다 (Row로 이어 붙이지 않는다).
- `FittedBox`가 이제 SS 폭까지 포함해 측정하므로 좁은 화면에서는 시계 전체가
  비례 축소된다. 360dp 세로 / 430dp 세로 / 932dp 가로 3종을 회귀 테스트로 고정했다.

동일 코드를 케어 타이머 전체화면(`care_timer_fullscreen_page`)도 공유하므로
같은 결함이 함께 해소된다.

### 13.2 C2 — B/A 캐러셀 렌더링 정책 변경

**기존 규칙 폐기.** "완성(🟢)되면 캐러셀에서 사라진다"를 취소한다.

**새 규칙.** 카드 순서는 **[빈 촬영 슬롯] → [🔴 미완성] → [🟢 완성]** 이며,
완성분도 사라지지 않고 뒤에 남아 가로 스크롤로 전부 훑을 수 있다.

| 지점 | 변경 |
|------|------|
| `BaCaptureSession.showsInCarousel` | `draft && !isComplete` → `status != archived` |
| `BaCaptureSession.carouselOrder` | 1차 키로 `isComplete` 추가 (미완성 우선) |
| `SoriStore.baIncompleteCount` | 캐러셀 길이 → **미완성만** 카운트 (넛지 배지) |
| `refreshBaSessions` | `draftOnly: false` — linked 세션도 함께 읽는다 |
| `bindBaSessionToChart` | 목록에서 제거 → **갱신**해서 🟢로 유지 |
| 로컬 폴백 이관 | 사진은 큐에서 빼되 🟢 카드는 `_localExtraSessions`로 보존 |
| `_BaCard` 이관 애니메이션 | 밖으로 밀어내는 `AnimatedSlide` → 제자리 `AnimatedScale` 확정 |
| `_BaCard` 완성 상태 | 촬영 진입 차단, 탭하면 `onOpen` → 뷰어 |

🟢 카드를 탭하면 연결된 차트의 B/A 비교 뷰어가 열린다. 차트를 찾지 못하는
경우(로컬 폴백 등)에는 피드에서 해당 카드 위치로 스크롤한다.

**부수 수정.** `MemorySoriRepository.upsertBaCaptureSession`이 신규 세션에 id를
발급하지 않아, 서로 다른 세션이 모두 `id: ''`로 저장돼 바인딩 시 엉뚱한 row가
매칭됐다. Postgres의 `default gen_random_uuid()`와 동일하게 id를 발급하도록
고쳤다. 기존에는 "바인딩 후 목록에서 제거" 로직이 이 결함을 가리고 있었다.

### 13.3 검증

| 게이트 | 결과 |
|--------|------|
| SS 경계 내 배치 (360x800 / 430x932 / 932x430) | 통과 |
| SS 유무와 무관한 HH:MM 타일 좌표 | 통과 |
| 홈 hero 안에서 시계가 카드 폭을 넘지 않음 (E2E) | 통과 |
| 🟢 완성 카드 캐러셀 잔류 + 탭 → 뷰어 | 통과 |
| 카드 순서 🔴 → 🟢, 넛지는 미완성만 | 통과 |
| 로컬 폴백 이관 후에도 🟢 잔류 | 통과 |
| 골든 (v5.4 · v7.0) | 통과 |
| 전체 스위트 회귀 | 20 실패 — **베이스라인과 동일 집합** |
