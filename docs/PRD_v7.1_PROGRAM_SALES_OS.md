# PRD v7.1 — Program 탭 세일즈 아키텍처 (상담/세일즈 OS)

**Status:** Approved · PO 마인드 Q1–Q7 종결 2026-09-02
**Author:** Expert Lead Engineer & UX/UI Architect
**Requested by:** PO 마인드 · 2026-09-02
**Supersedes:** PRD v7.0 §2 IA의 **My Asset 탭 (Q7 뼈대)** — 재고/기기 관리 기획은 **전면 폐기**
**Does not supersede:** v7.0 My Feed · Timer 탭 · v6.0 리포트 파이프라인 · My Page `ShopAssetTabBody`
**Primary device:** 원장 태블릿 (가로 상담 자세가 본 무대, 세로는 접이식)
**Rule:** 이 탭은 정보가 아니라 **화법**이다. 렌더 순서 = 말 순서.

> **폐기 선언.** v7.0 Q7 「My Asset의 최종 정체」는 본 문서로 종결한다. 재고·기기 관리는 홈 2번 탭에서 영구히 빠지고, 추후 마이페이지 또는 별도 관리 탭으로 이관한다. 기존 `ShopAssetTabBody`(마이페이지 Asset)는 **삭제하지 않는다.**

---

## 0. Executive Summary

| 항목 | v7.0 (현재) | v7.1 목표 |
|------|-------------|-----------|
| 홈 2번 탭 | `My Asset` `_ComingSoonPane` 뼈대 | **`Program`** — 상담/세일즈 OS |
| 탭의 목적 | 미정 (Q7) | **비교군(Decoy)으로 가격 저항을 낮추고, 상위 패키지로 업셀하고, 프로모션으로 클로징** |
| 메뉴 데이터 | `shops.service_menu` jsonb + `shop_menus` (이름·기기·키워드, **가격 없음**) | **카테고리 → 패키지 → 구성 라인** 정규화. 가격·횟수·구성이 SSOT |
| 견적 | `QuickCalculatorSheet` (사칙연산) | **A/B 사이드바이사이드 대조표** + 회당 단가 파생 |
| 클로징 | 없음 (회원권은 결제 후 수동 입력) | **프로모션 바텀시트 → 견적 → 회원권 발급** |
| 고객이 비교하는 대상 | 우리 샵 vs 옆 샵 (앱이 통제 못 함) | **우리 샵 안의 A vs B** (앱이 무대를 만든다) |

**한 문장.** 원장이 태블릿을 고객 쪽으로 돌리는 순간, Program 탭은 메뉴판이 아니라 **기준점 → 완화 → 대조 → 손실회피** 네 박자의 스크립트가 된다.

**핵심 설계 결단 4가지 (본 PRD의 축):**

1. **앵커는 저장하지 않고 파생한다.** Collapsed 카드에 올라가는 패키지는 `is_anchor` 플래그가 아니라 **해당 카테고리 활성 패키지 중 `list_price_krw` 최댓값**이다. 플래그를 두면 원장이 가격을 바꿔도 옛 앵커가 남는 드리프트가 생긴다. v7.0 신호등(`is_complete` generated)과 같은 철학이다.
2. **세일즈 패키지는 운영 메뉴와 다른 테이블이다.** `shop_menus` / `CareProgramTemplate` / `customers.memberships`를 가격판으로 재사용하지 않는다. 전자는 차트·타이머·보유 티켓의 SSOT이고, 후자는 **오늘 이 테이블 앞에서의 화법**이다. 섞는 순간 차트 케어명이 300만 원 패키지명으로 오염된다.
3. **프로모션은 정가를 고치지 않는다.** `list_price_krw`는 불변이다. 클로징은 `benefit_value_krw`( potlatch 가치 )와 `payable_krw`(실제 받을 돈)를 나란히 보여 준다. 정가를 덮어쓰면 다음 상담의 앵커가 무너진다.
4. **홈 2번 탭은 고객을 향한다.** 편집(패키지 등록)은 톱니 아이콘 뒤의 Edit 모드다. Presentation 모드의 카드에는 휴지통·드래그 핸들이 없다. 태블릿이 돌아가는 방향을 코드가 알아야 한다.

---

## 1. 세일즈 심리학 → UI 매핑 (화법 스크립트)

원장의 입에서 나오는 순서와 픽셀 순서를 1:1로 잠근다.

```
[1. 앵커]  "저희 윤곽은 이 과정이 정석입니다."     → Collapsed: A패키지 10회 300만 단독
[2. 완화]  "상황에 맞는 구성도 있습니다."           → Expand: B 150만 · C 100만 등장
[3. 대조]  "둘을 나란히 보시면 차이가 분명합니다."  → Check 2개 → 비교하기 → A/B 뷰어
[4. 손실]  "지금은 이 혜택이 붙습니다."             → 프로모션 시트 → "총 40만 원 추가 혜택"
[5. 닫기]  "이 구성으로 오늘 등록하시면 됩니다."     → 견적 수락 → 회원권 발급
```

| 박자 | 심리 기제 | 금지하는 UI | 허용하는 UI |
|------|-----------|-------------|-------------|
| 1 | Anchoring | 세 가격을 처음부터 격자 나열 | 최고가만 큰 숫자. 나머지 `display: none` (opacity 0이 아님 — 레이아웃에 자리도 없음) |
| 2 | Decoy / Relief | "할인" 배지, 빨간 SALE | 정가 그대로. B·C가 **A 아래에서** 작게 나타남 |
| 3 | Internal comparison | 외부 샵 가격, "타샵 대비" | 우리 패키지 2개의 구성·횟수·회당 단가 대조 |
| 4 | Loss aversion | 가짜 카운트다운, 재고 부족 거짓말 | 원장이 **사전 세팅한** 혜택의 원화 환산합 |
| 5 | Commitment | 결제 PG 강제 (이 스프린트 범위 밖) | 견적 스냅샷 + `CustomerMembership` 발급 |

**Decoy의 권장 산수 (카테고리 시드 템플릿).** 고객이 고르도록 남겨 두는 답은 가운데다.

| 역할 (내부) | 노출명 예 | 횟수 | 정가 | 회당 | 고객이 느끼는 것 |
|-------------|-----------|------|------|------|------------------|
| Anchor | A패키지 | 10회 | 3,000,000 | 300,000 | "이 샵의 기준점" |
| Target | B패키지 | 6회 | 1,500,000 | 250,000 | "회당이 더 낫다" ← **닫고 싶은 답** |
| Decoy | C패키지 | 3회 | 1,000,000 | 333,333 | "싼데 회당은 더 비싸다" |

내부 `tier` enum(`anchor`/`target`/`decoy`)은 **분석·시드용**이다. 고객 화면에는 원장이 붙인 이름만 보인다. "미끼"라는 단어를 UI에 쓰지 않는다.

---

## 2. 현행 코드 자산 인벤토리 (재사용 / 재사용 금지 / 갭)

### 2.1 재사용

| 자산 | 경로 | Program에서의 역할 |
|------|------|-------------------|
| 홈 3탭 셸 | `VisitLauncherPage` + `_HomeTabBar` | 라벨만 `My Asset` → `Program`. 셸·스크롤 헌법 유지 |
| CDG 토큰 | `HomeVisualTokens`, `VisitGlassTokens` | 카드 radius 24, canvas `#F4F6F9`, 모션 280ms `easeOutCubic` |
| 바텀시트 검색 패턴 | `showVisitCustomerPickerSheet` | 견적에 고객을 붙일 때 동일 UX |
| B/A 비교 가로 분할 | `BeforeAfterComparePage` 73/27 | **비교 뷰어는 50/50**. 레이아웃 문법(가로=나란히, 세로=스택)만 차용 |
| 회원권 발급 | `CustomerMembership` (`total_visits`, `paid_amount`, `per_session_value`) | 견적 수락의 write-side. 새 지갑을 만들지 않는다 |
| 퀵 계산기 | `QuickCalculatorSheet` | **Timer/히어로에 잔류**. Program의 견적을 대체하지 않음 |
| 서비스 메뉴 칩 | `ServiceMenuChips` | Edit 모드에서 구성 라인 라벨을 고를 때 키워드 팔레트 |
| 마이페이지 Asset | `ShopAssetTabBody` | 재고/팬 자산은 여기에 남김. 홈에서 안 뺌 |

### 2.2 재사용 금지 (오염 방지)

| 자산 | 이유 |
|------|------|
| `shops.service_menu` / `shop_menus` | 가격·횟수 없음. 차트 `care_name`의 소스. 여기에 300만을 넣으면 관리 케이스 제목이 견적서가 된다 |
| `CareProgramTemplate` (프리셋 0–4) | Path C 타이머 슬롯. 분 단위 시술 순서이지 판매 SKU가 아님 |
| `interleavedCaseFeed` / Boost | 외부 노출. Program은 샵 프라이빗 |
| Green `#34C759` | CDG: 케어 **실행**. 결제 CTA에 쓰면 "지금 눕히라"로 읽힌다 |
| Violet `#8B5CF6` | CDG: **신규 고객 진입**. 프로모션 FAB에 쓰면 신규 버튼과 의미가 충돌한다 |
| 재고 수량, 기기 가동률 | 폐기된 My Asset. 구성 라인은 **세일즈 카피**이지 재고 장부가 아님 |

### 2.3 갭

| # | 갭 | 영향 |
|---|-----|------|
| **G1** | 홈 2번 탭이 `_ComingSoonPane` | Program 셸 없음 |
| **G2** | 가격이 붙은 패키지 엔티티 없음 | 앵커/디코이 산수 불가 |
| **G3** | 카테고리 아코디언 없음 | 화법 1박자 불가 |
| **G4** | 패키지 2택 비교 뷰어 없음 | 화법 3박자 불가 |
| **G5** | 프로모션 카탈로그 없음 | 화법 4박자 불가 |
| **G6** | 견적 스냅샷 없음 | 상담 중 숫자를 바꾸면 앵커가 흔들림. 수락 이력 없음 |
| **G7** | Presentation vs Edit 모드 없음 | 고객 앞에서 휴지통이 보임 |

---

## 3. 정보 구조 (IA)

```
VisitLauncherPage
└── HomeTabShell
    ├── TabBar  [ My Feed | Program | Timer ]     ← 라벨 확정
    ├── Tab 0  MyFeedPane                         (v7.0 유지)
    ├── Tab 1  ProgramPane                        [본 스프린트]
    │   ├── Presentation mode (default, 고객 향)
    │   │   ├── ProgramBoard (카테고리 아코디언)
    │   │   ├── CompareDock  (2택 시 하단 고정 칩)
    │   │   ├── ProgramComparePage (A/B 전체화면)
    │   │   └── PromotionCloserSheet (바텀시트)
    │   └── Edit mode (톱니, 원장만)
    │       ├── Category / Package / Line CRUD
    │       └── Promotion catalog CRUD
    └── Tab 2  TimerPane                          (v7.0 유지)
```

**스크롤 헌법 (v5.4 blank screen 재발 방지):**
Program 보드도 탭별 독립 `CustomScrollView`. 카테고리 카드는 `SliverList`. `NestedScrollView` 금지. 비교 뷰어는 **새 라우트**(피드 스크롤과 분리) — B/A 뷰어와 동일하게 `Navigator.push`.

**고객 컨텍스트는 선택.** 보드만 펼쳐 설명하는 순수 메뉴 상담이 1순위다. 견적 수락 시에만 고객 시트가 뜬다. 재방문 플로우에서 Program으로 딥링크할 때는 `customerId`를 들고 들어와 수락 단계를 한 번 줄인다.

---

## 4. 데이터베이스 설계 — migration `109_program_sales_os.sql`

PostgREST 캐시: 파일 끝에 `notify pgrst, 'reload schema';` (v7.0 `108`과 동일. 빼면 PGRST205).

### 4.1 ER (한 샵의 진실)

```
program_categories  1──N  program_packages  1──N  program_package_lines
program_promotions  (샵 전역 카탈로그, 패키지 비종속 — 어떤 견적에도 붙일 수 있다)
program_quotes      N──1  customer?   N──2  packages (left/right)  N──1  chosen package
program_quote_promos  (quote ⨯ promotion, 적용 순번 보존)
```

패키지에 프로모션을 직접 FK로 묶지 않는다. **"이 혜택은 오늘 이 견적에 붙였다"**가 진실이다. 카탈로그를 패키지에 묶으면 원장이 상담 중에 다른 카테고리 혜택을 못 꺼낸다.

### 4.2 `program_categories`

```sql
create table public.program_categories (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null references public.shops(id) on delete cascade,
  name        text not null,                 -- '윤곽 관리'
  subtitle    text not null default '',      -- 한 줄 화법. Collapsed에도 보임
  sort_order  int  not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (shop_id, name)
);
```

### 4.3 `program_packages`

```sql
create table public.program_packages (
  id              uuid primary key default gen_random_uuid(),
  shop_id         uuid not null references public.shops(id) on delete cascade,
  category_id     uuid not null references public.program_categories(id) on delete cascade,
  name            text not null,                 -- 'A패키지'
  visit_count     int  not null check (visit_count > 0),
  list_price_krw  int  not null check (list_price_krw >= 0),
  -- 내부 역할. UI 라벨이 아님. 시드/분석용. 앵커 노출은 가격 max로 파생.
  tier            text not null default 'target'
                  check (tier in ('anchor', 'target', 'decoy')),
  is_active       boolean not null default true,
  sort_order      int  not null default 0,       -- Expand 시 앵커 아래 나열 순서
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index program_packages_category_idx
  on public.program_packages (category_id, is_active, list_price_krw desc);
```

**파생 컬럼은 패키지 row에 두지 않는다.**
- `unit_price_krw = list_price_krw / visit_count` — Dart getter + SQL view.
- `is_board_anchor` — 카테고리 쿼리에서 `distinct on (category_id) ... order by list_price_krw desc`.

```sql
create view public.program_package_metrics as
select
  p.*,
  (p.list_price_krw::numeric / p.visit_count)::int as unit_price_krw,
  p.list_price_krw = max(p.list_price_krw) filter (where p.is_active)
    over (partition by p.category_id) as is_board_anchor
from public.program_packages p;
```

> 동점 앵커: 최고가가 두 개면 `sort_order` 오름차순, 그래도 같으면 `created_at`. 원장에게 "같은 가격 두 개를 앵커로 쓰지 말라"는 Edit 경고를 띄운다.

### 4.4 `program_package_lines` — 비교 뷰어의 행

```sql
create table public.program_package_lines (
  id          uuid primary key default gen_random_uuid(),
  package_id  uuid not null references public.program_packages(id) on delete cascade,
  kind        text not null check (kind in ('step', 'device', 'ampoule', 'perk')),
  label       text not null,            -- '고주파 온열 12분' / '수분 앰플'
  minutes     int,                      -- kind='step'일 때만
  shop_menu_id uuid references public.shop_menus(id) on delete set null,
  sort_order  int  not null default 0
);
```

`shop_menu_id`는 **선택 힌트**다. 라벨은 비정규화해 둔다. 운영 메뉴 이름을 바꿔도 지난 견적 카피가 따라가지 않는다 (견적은 아래 스냅샷이 지킴).

### 4.5 `program_promotions`

```sql
create table public.program_promotions (
  id              uuid primary key default gen_random_uuid(),
  shop_id         uuid not null references public.shops(id) on delete cascade,
  kind            text not null check (kind in (
                    'extra_session',      -- +N회
                    'gift',               -- 현물. 결제액은 안 줄어듦
                    'instant_discount',    -- 오늘 받을 돈에서 차감
                    'next_visit_credit'   -- 다음 결제 바우처. payable은 안 줄어듦
                  )),
  title           text not null,          -- '+1회 추가'
  subtitle        text not null default '',
  value_krw       int  not null default 0 check (value_krw >= 0),  --  potlatch 표시액
  extra_visits    int  not null default 0 check (extra_visits >= 0),
  discount_krw    int  not null default 0 check (discount_krw >= 0),
  is_active       boolean not null default true,
  sort_order      int  not null default 0,
  valid_from      timestamptz,
  valid_until     timestamptz,
  created_at      timestamptz not null default now()
);
```

**표시 공식 (Dart SSOT, 서버 트리거와 동일 수식):**

```
benefit_value_krw = Σ promotion.value_krw
payable_krw       = max(0, list_price_krw − Σ promotion.discount_krw)
membership.total_visits = package.visit_count + Σ extra_visits
```

`gift`와 `next_visit_credit`는 `value_krw`만 키우고 `payable`은 건드리지 않는다. "40만 원 혜택"과 "오늘 결제액"이 다른 숫자인 것이 **의도**다. 한 숫자로 합치면 원장이 할인만 하게 된다.

### 4.6 `program_quotes` — 상담의 동결본

가격을 상담 도중에 바꾸면 앵커가 무너지므로, 비교 화면에 들어가는 순간 **패키지 스냅샷**을 jsonb로 얼린다.

```sql
create table public.program_quotes (
  id                 uuid primary key default gen_random_uuid(),
  shop_id            uuid not null references public.shops(id) on delete cascade,
  author_id          uuid references public.profiles(id) on delete set null,
  customer_id        uuid references public.customers(id) on delete set null,
  left_package_id    uuid references public.program_packages(id) on delete set null,
  right_package_id   uuid references public.program_packages(id) on delete set null,
  chosen_package_id  uuid references public.program_packages(id) on delete set null,
  snapshot           jsonb not null,     -- 양측 name/visits/price/lines/unit_price
  list_price_krw     int  not null,
  benefit_value_krw  int  not null default 0,
  payable_krw        int  not null,
  status             text not null default 'draft'
                     check (status in ('draft', 'presented', 'accepted', 'abandoned')),
  presented_at       timestamptz,
  accepted_at        timestamptz,
  created_at         timestamptz not null default now()
);

create table public.program_quote_promos (
  quote_id      uuid not null references public.program_quotes(id) on delete cascade,
  promotion_id  uuid not null references public.program_promotions(id) on delete restrict,
  sort_order    int  not null default 0,
  primary key (quote_id, promotion_id)
);
```

`accepted` 전이 시 RPC `accept_program_quote(quote_id, customer_id)`:
1. 고객이 없으면 거부.
2. `CustomerMembership` 한 장 insert (`service_name = snapshot.chosen.name`, `total_visits`, `paid_amount = payable_krw`, `per_session_value = payable / visits`).
3. quote.status = accepted. **패키지 정가는 그대로.**

### 4.7 RLS

My Feed와 같이 **원장 프라이빗**. `shop_memberships` 샵 스코프. `select`를 `using (true)`로 열지 않는다 — 가격표가 공개 API로 나가면 옆 샵이 우리 앵커를 베낀다.

```sql
alter table public.program_categories enable row level security;
-- packages, lines, promotions, quotes 동일
create policy program_categories_shop_member
  on public.program_categories for all
  using (shop_id in (select shop_id from public.shop_memberships where user_id = auth.uid()))
  with check (shop_id in (select shop_id from public.shop_memberships where user_id = auth.uid()));
```

---

## 5. UI 렌더링 전략 — CDG를 깨지 않는 세일즈

기존 헌법을 확장한다. **새 색은 하나다: 클로징 charcoal.** Green/Violet은 각각 Timer·신규 고객 소유로 남긴다.

### 5.1 신규 토큰 (`HomeVisualTokens`에 prefix `program`)

| 토큰 | 값 | 의미 |
|------|-----|------|
| `programCanvas` | `canvasBg` `#F4F6F9` | 홈과 동일 |
| `programCardFill` | `heroCardFill` `#F2FFFFFF` | 유리 카드 |
| `programCardRadius` | 24 | 히어로와 동급 |
| `programPriceSize` | 28 / w600 / tabular | 앵커 숫자. `VisitGlassTokens.displayKpi`와 동형 |
| `programUnitSize` | 13 / `#8E8E93` | `회당 30만` |
| `programCloserFill` | `#1C1C1E` | **닫는 버튼**. 실행(Green)·진입(Violet)과 분리 |
| `programCloserOn` | `#FFFFFF` | |
| `programBenefitSize` | 15 / w700 / `#111111` | "총 40만 원 추가 혜택" — 빨강 금지 |
| `programStrike` | `#8E8E93` | 정가 취소선 (할인이 있을 때만) |
| `programCheckFill` | `#111111` | 2택 체크 |
| `programDockH` | 56 | 하단 비교하기 칩 |
| `programExpandDuration` | 280ms `easeOutCubic` | `VisitGlassTokens.calmMotion` |

**금지:** 그라데이션 세일 배너, 깜빡이는 FAB, 이모지 폭죽, `% OFF` 원형 스티커. 선물 아이콘은 closer 칩 **한 곳**에 `Icons.card_giftcard_outlined` 24px charcoal. FAB를 떠 다니게 하지 않는다 — 태블릿을 돌리면 FAB가 고객 턱 밑에 걸린다. **하단 고정 칩**이 헌법이다.

### 5.2 컴포넌트 1 — `ProgramBoard` 아코디언

```
┌ 윤곽 관리                              ∨ ┐   ← Collapsed
│ 가장 높은 기준점                         │
│ A패키지  ·  10회                         │
│ 3,000,000                                │   ← 28px tabular, 유일한 가격
│ 회당 300,000                              │
└──────────────────────────────────────────┘
```

탭 → **같은 카드가 아래로 열린다** (라우트 이동 없음). 동시에 다른 카테고리는 접힌다 (**exclusive accordion**, Q1 권고).

```
┌ 윤곽 관리                              ∧ ┐
│ ● A패키지  10회  3,000,000   회당 30만  ☐│  ← 앵커, 여전히 맨 위
│   고주파 · 수기 윤곽 · 프리미엄 팩        │
│ ○ B패키지  6회   1,500,000   회당 25만  ☐│
│ ○ C패키지  3회   1,000,000   회당 33만  ☐│
└──────────────────────────────────────────┘
```

규칙:
- Collapsed에서 B/C의 가격 문자열은 **위젯 트리에 넣지 않는다.** (스크린샷·어깨 너머 방지)
- Expand 시 앵커는 사라지지 않는다. 기준점이 눈앞에서 빠지면 완화 효과가 죽는다.
- 체크는 Expand 상태에서만. 최대 2. 3번째 탭은 가장 오래된 선택을 밀어내며 토스트 `"비교는 두 가지만 나란히 봅니다"`.
- 카테고리를 접어도 선택은 유지한다. 다른 카테고리 1개를 더 고르면 교차 비교가 된다 (Q2).
- 활성 패키지가 1개면 Expand해도 한 줄. 비교하기는 비활성.

`AnimationController` 280ms. `AnimatedSize` + fade. `ExpansionTile` 사용 금지 (Material 기본 아이콘·디바이더가 CDG를 깨뜨림).

### 5.3 컴포넌트 2 — `ProgramComparePage` (A/B)

`CompareDock`: 2택이 되는 순간 하단에서 슬라이드 업 (280ms).

```
[ A패키지 × ]  [ B패키지 × ]     [ 비교하기 ]
```

전체화면. 가로는 좌우 50/50, 세로는 상하 스크롤 스택. **조작 패널을 사진처럼 우측에 두지 않는다** — 양쪽이 대칭이어야 대조가 된다. 프로모션 칩만 하단 공통.

대조표 행 순서 (고정 — 원장이 못 바꿈. 화법 순서다):

| 행 | 파생 | 강조 |
|----|------|------|
| 이름 | snapshot | |
| 횟수 | `visit_count` | |
| 회당 단가 | `list/visits` | **Target이 더 낮으면 그 칸만 글자 w700** |
| 정가 | `list_price_krw` | tabular 28 |
| 케어 순서 | `kind=step` 라인 | 번호 리스트 |
| 기기 | `kind=device` | 칩 |
| 앰플/제품 | `kind=ampoule` | 칩 |
| 시간 합 | `Σ step.minutes` | |
| 차이 | 우측 − 좌측 | `"150만 원 낮고, 회당 5만 원 이득"` 한 줄. 카드 밖, 하단 공통 |

승자 하이라이트는 색이 아니라 **회당 단가가 낮은 쪽 숫자 weight**. 배경 tint `#F4F6F9`는 선택된 열(나중에 고른 쪽)에만.

상단: 고객 이름(있으면) · `닫기`. 패키지 탭으로 승자를 고르면 그 열이 `chosen`.

### 5.4 컴포넌트 3 — `PromotionCloserSheet`

비교 뷰어 **및** 패키지 상세(Expand 행을 길게 눌러 들어온 단건 화면) 하단에 공통 칩:

```
[ 프로모션 적용 ]     charcoal, h 56, radius 18
```

시트 목록은 활성·유효기간 안인 프로모션만. 멀티 셀렉트. 각 행:

```
+1회 추가                         300,000 상당
10만 원 상당 수분 크림             100,000 상당
다음 결제 10% 크레딧               —  (value_krw로 환산해 둠)
```

적용 즉시 비교 하단 베네핏 바가 교체된다:

```
3,000,000
총 400,000원 추가 혜택 적용됨
오늘 결제  2,900,000     ← instant_discount가 있을 때만 이 줄
```

정가 숫자는 항상 보인다. 혜택 줄이 정가 **아래**에 붙는다 (위가 아님 — 앵커를 가리지 않기 위함).

수락 CTA: `이 구성으로 등록` → 고객 시트(미연결 시) → `accept_program_quote`. 성공 토스트 `김민정님 · 윤곽 B패키지 6+1회 등록`.

### 5.5 Edit 모드 (고객이 보면 안 되는 뒷무대)

탭 바 우측 톱니. 진입 시 앱바 배경이 `canvasBg` 그대로, 텍스트만 `"메뉴 보드 편집"`. 카드에 가격 필드·라인 에디터·프로모션 CRUD. Presentation으로 돌아오는 CTA는 `"고객에게 보이기"`.

시드: 카테고리 0개면 Presentation에 빈 상태 `"아직 메뉴 보드가 없습니다 · 톱니에서 윤곽/웨딩 카테고리를 만드세요"`. 가짜 300만 원 데모 숫자를 고객 화면에 심지 않는다.

---

## 6. 상태 머신

```
Board
  └ expand(category)           exclusive
  └ toggleCheck(package)       cap 2
  └ openCompare                quotes.status = presented, snapshot freeze
       └ applyPromo[]          benefit/payable 재계산
       └ choose(side)
       └ accept                membership insert, status = accepted
       └ close                 status = abandoned (수락 없이 pop)
```

비교를 열기 전에 패키지 가격이 바뀌면 보드가 새 앵커를 파생한다. 비교가 열린 뒤에는 **snapshot만** 본다. 원장이 뒤에서 가격을 고쳐도 고객 앞의 300만은 그 상담이 끝날 때까지 300만이다.

---

## 7. 홈 탭 변경 체크리스트 (회귀)

| 파일 | 변경 |
|------|------|
| `visit_launcher_page.dart` | Tab 라벨, `_ComingSoonPane` → `ProgramPane` |
| `test/my_feed_v70_e2e_test.dart` | `'My Asset'` 어서션 → `'Program'`. 뼈대 테스트는 Program 보드 스모크로 교체 |
| v7.0 My Feed / Timer | **무변경** |

`ShopAssetTabBody` · 재고 모델 · 기기 가동 쿼리는 이 스프린트에서 열지 않는다.

---

## 8. 구현 슬라이스

| ID | 슬라이스 | 산출 |
|----|----------|------|
| **R1** | 탭 리네임 + `ProgramPane` 빈 보드 (CDG 카드 셸) | 라벨 E2E 그린 |
| **R2** | `109` 스키마 + RLS + `notify pgrst` + Dart 모델/게터 (`unitPrice`, `isBoardAnchor`, `benefitSum`) | 유닛 테스트 |
| **R3** | `ProgramBoard` exclusive accordion + 2택 캡 + CompareDock | 위젯 테스트: collapsed에 최고가 외 가격 문자열 0개 |
| **R4** | Edit 모드 CRUD (카테고리/패키지/라인/프로모션) | 원장 혼자 시드 가능 |
| **R5** | `ProgramComparePage` 가로 50/50 · 세로 스택 · 스냅샷 견적 | 회당 단가 강조 테스트 |
| **R6** | `PromotionCloserSheet` + 베네핏 바 공식 | 40만 합산 픽스처 |
| **R7** | `accept_program_quote` → `CustomerMembership` | 수락 후 지갑 회차 일치 |

R1을 R2보다 먼저 올려 탭 이름을 홈에 고정한다. 스키마 없는 R3는 메모리 레포로 위젯 테스트를  Milestones에 넣는다.

---

## 9. 테스트 헌법

| 케이스 | 기대 |
|--------|------|
| 카테고리에 300/150/100만 | Collapsed `find.text('150')` / `'100'` / `'1,500,000'` 없음. `'3,000,000'` 1개 |
| Expand 후 접기 | 다시 최고가만. 선택 상태는 유지 |
| 카메라가 아닌 탭 전환 | Program ↔ My Feed 왕복해도 선택·expand index 유지 (`AutomaticKeepAlive`) |
| 체크 3번째 | 선택 집합 길이 2 |
| 비교 중 원가가 Edit에서 변경 | 뷰어 숫자는 snapshot. 보드로 돌아오면 새 앵커 |
| 프로모션 gift 10만 + extra_session value 30만 | `benefit_value_krw == 400000`, `payable == list` |
| instant_discount 10만 추가 | `payable == list - 100000` |
| 고객 없이 accept | RPC 거부. 시트 오픈 |
| 수락 | membership.total_visits = visits + extra, paid = payable |
| E2E | 탭 텍스트 `Program`, `My Asset` 0 |

Golden: Collapsed 보드 1장 (윤곽 앵커만). Expand 1장 (3행). 비교 가로 1장. 베네핏 바 1장. 이모지·세일 배너 픽셀이 보이면 실패.

---

## 10. 결정이 필요한 질문 (권고 포함)

| ID | 질문 | 권고 | 이유 |
|----|------|------|------|
| **Q1** | 아코디언 exclusive vs 다중 펼침 | **(a) exclusive** | 한 카테고리의 앵커가 다른 카테고리 Expand에 묻히면 1박자가 죽는다 |
| **Q2** | 교차 카테고리 비교 | **(a) 허용, 소프트 경고** | "윤곽 vs 웨딩"을 막는 것은 원장 화법을 코드가 검열하는 것. 경고 칩 `"다른 카테고리입니다"`만 |
| **Q3** | 앵커를 최고가가 아닌 것으로 지정 | **(a) 불가 — 가격 max만** | 플래그 드리프트. 보여주고 싶은 것이 앵커면 가격을 그렇게 매겨라 |
| **Q4** | 프로모션 스택 | **(a) 멀티** | PO 예시가 이미 3종. 합산 공식만 잠그면 된다 |
| **Q5** | 수락 = 인앱 결제? | **(a) 이번엔 회원권 발급만** | PG는 별도 PRD. 오늘 할 일은 숫자가 지갑으로 닫히는 것 |
| **Q6** | 고객 없는 보드 열람 | **(a) 허용** | 상담 시작은 메뉴, 끝은 이름 |
| **Q7** | closer 형태 | **(a) 하단 칩, FAB 금지** | 태블릿 회전 시 FAB는 고객 얼굴에 겹친다 |

Q1–Q7을 본 권고로 채택하면 구현은 R1부터 착수한다. 이견이 있는 ID만 표시해 주면 스키마를 고친다.

---

## 11. 명시적 비범위

- 재고 수량, 기기 예약, 소모품 차감 (폐기된 My Asset)
- 외부 샵 가격 크롤링 / "타샵 대비"
- PG 결제, 카드 단말기
- 고객 앱에 Program 노출 (원장 홈 전용)
- `CareProgramTemplate` 타이머와 패키지 라인 자동 동기화 (원장이 복사하고 싶으면 Edit에서 수동)

---

## 12. 성공 정의

원장이 태블릿을 돌렸을 때 고객이 **옆 샵 가격을 꺼내기 전에** 우리 A의 300만을 보고, 펼쳐진 B의 회당 단가에 안도하고, 나란히 놓인 구성표에서  equip/앰플 차이를 읽고, 혜택 합이 적힌 칩을 본 뒤 이름을 올린다. 그 동선이 코드 경로와 같으면 v7.1은 성공이다.
