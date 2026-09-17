# Cursor Agent 마스터 실행 지시서 — SORI 상권분석·목표매출 기능

> 이 문서는 Cursor Agent에 그대로 전달하는 실행 지시서다.
> 전제: 리포지토리, 개발 환경, 권한, 데이터 계약, 지도 공급자 키, 배포 환경은 준비되어 있다고 가정한다.
> 원칙: 없는 것은 찾아서 만들고, 연결되지 않은 것은 연결하고, 테스트되지 않은 것은 테스트를 만들고 통과시켜라. 질문으로 작업을 멈추지 말고 합리적인 기본값을 선택해 구현하라.

---

## 0. Agent에게 전달할 프롬프트

```text
당신은 SORI의 Staff-level Product Engineer, UX Engineer, Data Engineer, QA Engineer 역할을 동시에 수행한다.

현재 리포지토리에 “상권분석 + 목표매출 + 매출감소 진단 + 실행계획” 기능을 프로덕션 품질로 완성하라.

중요 전제:
- 필요한 권한, API 키, 데이터 접근, 지도 제공자, DB, 스토리지, 배포 환경은 모두 준비되어 있다고 가정한다.
- 기능 구현에 필요한 파일, 폴더, 타입, 테이블, 마이그레이션, API, UI, 테스트, 목업 데이터, 문서가 없다면 직접 만든다.
- 질문을 던져 작업을 멈추지 마라. 기존 코드베이스의 패턴을 먼저 탐색하고, 없거나 모호하면 본 지시서의 기본값을 채택한다.
- 현재 코드가 불완전하더라도 기능을 작은 단위로 완성한다. TODO만 남기고 종료하지 않는다.
- 어떤 화면도 빈 화면, 깨진 로딩, 하드코딩된 가짜 운영 수치, 설명 없는 오류로 남기지 않는다.

제품 목표:
1. 예비 원장이 월 목표 매출, 고정비, 목표 이익, 객단가, 변동비, 영업일을 입력하면 필요한 월/일 방문 수, 공헌이익률, 필요 매출을 계산한다.
2. 예비 원장이 업종·위치·반경을 선택하면 경쟁 밀도, 인구/유동, 시장 추이 등의 상권 지표를 지도와 차트로 본다.
3. 예비 원장이 최대 3개 후보 상권을 동일 조건에서 비교하고, 목표 매출 관점의 전략 가설과 현장 조사 계획을 만든다.
4. 기존 원장이 내부 매출·고객수·객단가·재방문 지표와 외부 상권 변화를 함께 보고, 매출 감소의 가능한 원인과 검증 가능한 회복 행동을 받는다.
5. 사용자가 인사이트를 액션 플랜으로 저장하고, 오늘/이번 주/30일 단위로 완료·성과를 추적한다.

반드시 지킬 제품 원칙:
- 성공 가능성, 매출, 이익을 보장하거나 단정하지 않는다.
- “성공 지역”, “매출 보장”, “원인은 확실히 X” 같은 문구를 만들지 않는다.
- 모든 외부 시장 지표에는 출처, 기준 기간, 갱신일, 지리 단위를 UI에 표시한다.
- 데이터가 부족하거나 시점/공간 단위가 다르면 결과보다 경고와 한계를 먼저 표시한다.
- 경쟁업체의 비공개 매출 또는 개인 데이터를 추정하거나 노출하지 않는다.
- 개인정보, API 키, 토큰, 고객 식별 정보는 로그·오류·분석 이벤트·fixture에 남기지 않는다.
- 경쟁 업소 정보는 공개/계약 데이터의 참고용 분포이며, 오분류/폐업 가능성이 있음을 UI에서 알린다.

기본 기술 선택 규칙:
- 기존 리포지토리의 프레임워크·UI 시스템·ORM·테스트 도구·지도 SDK를 우선 사용한다.
- 해당 기반이 없다면 Next.js App Router + TypeScript + Tailwind + shadcn/ui + PostgreSQL/PostGIS + Prisma + TanStack Query + Zustand + Recharts/ECharts를 생성한다.
- 지도는 기존 SDK가 있으면 이를 사용한다. 없으면 adapter interface를 만들고, 개발 환경에서 동작하는 mock provider와 provider 교체 지점을 함께 구현한다.
- 실제 상권 데이터 adapter가 없으면 정규화된 seed/mock dataset을 만들고, 데이터 상태를 “데모 데이터”로 명확히 레이블링한다. 운영 데이터처럼 위장하지 않는다.

작업 프로토콜:
1. 리포지토리 구조, package scripts, 환경 변수 스키마, DB/ORM, 기존 디자인 시스템, 인증·권한 모델, 테스트 도구를 탐색한다.
2. 구현 계획을 체크박스 목록으로 작성하고 작업 로그 파일 `docs/market-analysis-implementation-log.md`에 기록한다.
3. 아래 P0 작업을 의존성 순서대로 구현한다. 각 작업은 코드, 로딩/빈 상태/오류 상태, 접근성, 테스트를 포함해야 완료다.
4. 각 작업 후 반드시 lint, typecheck, 관련 unit/integration test를 실행한다.
5. 최종적으로 production build와 핵심 E2E 흐름을 실행한다.
6. 실패하면 오류 원인을 읽고 최소 변경으로 고친다. 동일 근본 원인에 대해 최대 3회 자동 수정한다.
7. 3회 내 해결 불가한 외부 차단 요인만 다음 형식으로 문서화한다: 차단 원인 / 재현 명령 / 시도 내용 / 필요한 환경값 또는 권한 / 안전한 대체 구현. 단, 대체 구현 가능한 경우에는 대체 구현을 끝낸다.
8. 데이터 삭제, 파괴적 마이그레이션, 프로덕션 배포, 유료 서비스의 한도 상향은 수행하지 않는다. 그 외 개발·테스트·로컬 마이그레이션·seed·문서화는 적극적으로 수행한다.

완료 보고 형식:
- 완료한 사용자 플로우
- 추가/변경한 파일과 역할
- 데이터 모델·API 변경점
- 실행한 검증 명령과 결과
- 남은 외부 의존성 및 현재 작동하는 대체 경로
- 수동 QA 체크리스트

이제 코드베이스를 탐색하고, P0부터 구현하라.
```

---

## 1. 기능 명세

### 1.1 목표 매출 계산

#### 입력

```ts
export type FinancialGoalInput = {
  targetRevenue?: number;
  fixedCost: number;
  targetProfit: number;
  averageTicket: number;
  variableCostPerVisit?: number;
  variableCostRate?: number;
  operatingDays: number;
  industry: BeautyIndustry;
};

export type BeautyIndustry =
  | 'HAIR'
  | 'BARBER'
  | 'NAIL'
  | 'ESTHETIC'
  | 'MAKEUP'
  | 'LASH_BROW'
  | 'TATTOO'
  | 'WAXING'
  | 'MULTI_BEAUTY';
```

#### 계산

```ts
export type FinancialGoalResult = {
  contributionMarginPerVisit: number;
  contributionMarginRate: number;
  requiredRevenue: number;
  requiredVisitsPerMonthRaw: number;
  requiredVisitsPerMonth: number;
  requiredVisitsPerDayRaw: number;
  requiredVisitsPerDay: number;
  targetRevenueGap: number | null;
  assumptions: string[];
  warnings: string[];
};

export function calculateFinancialGoal(input: FinancialGoalInput): FinancialGoalResult {
  const variableCostPerVisit = input.variableCostPerVisit
    ?? Math.round(input.averageTicket * (input.variableCostRate ?? 0));

  const contributionMarginPerVisit = input.averageTicket - variableCostPerVisit;
  const contributionMarginRate = contributionMarginPerVisit / input.averageTicket;

  if (input.fixedCost < 0 || input.targetProfit < 0) {
    throw new Error('고정비와 목표 이익은 0 이상이어야 합니다.');
  }
  if (input.averageTicket <= 0) {
    throw new Error('평균 객단가는 0보다 커야 합니다.');
  }
  if (input.operatingDays < 1 || input.operatingDays > 31) {
    throw new Error('월 영업일은 1일 이상 31일 이하여야 합니다.');
  }
  if (variableCostPerVisit < 0 || variableCostPerVisit >= input.averageTicket) {
    throw new Error('방문당 변동비는 0 이상이며 객단가보다 작아야 합니다.');
  }

  const requiredContributionMargin = input.fixedCost + input.targetProfit;
  const requiredRevenue = requiredContributionMargin / contributionMarginRate;
  const requiredVisitsPerMonthRaw = requiredContributionMargin / contributionMarginPerVisit;
  const requiredVisitsPerMonth = Math.ceil(requiredVisitsPerMonthRaw);
  const requiredVisitsPerDayRaw = requiredVisitsPerMonth / input.operatingDays;
  const requiredVisitsPerDay = Math.ceil(requiredVisitsPerDayRaw);

  return {
    contributionMarginPerVisit,
    contributionMarginRate,
    requiredRevenue: Math.ceil(requiredRevenue),
    requiredVisitsPerMonthRaw,
    requiredVisitsPerMonth,
    requiredVisitsPerDayRaw,
    requiredVisitsPerDay,
    targetRevenueGap: input.targetRevenue ? Math.ceil(requiredRevenue - input.targetRevenue) : null,
    assumptions: [
      '객단가와 변동비가 기간 동안 일정하다고 가정합니다.',
      '필요 방문 수는 소수점 올림 기준입니다.'
    ],
    warnings: []
  };
}
```

#### 필수 테스트

```text
- 고정비 600만원, 목표이익 300만원, 객단가 9만원, 변동비 2.7만원, 영업일 25일
  → 월 143회, 하루 6회, 공헌이익 6.3만원, 공헌이익률 70%
- 변동비율 기반 입력 정상 계산
- 음수 비용, 0 객단가, 변동비 >= 객단가, 영업일 범위 오류
- 결과의 소수점 방문 수 올림
- targetRevenue가 있으면 차이 표시
```

### 1.2 상권 탐색

#### 사용자 입력

```ts
export type MarketSearchInput = {
  latitude: number;
  longitude: number;
  radiusMeters: 1000 | 3000 | 5000 | 10000;
  industry: BeautyIndustry;
  period?: { start: string; end: string };
};
```

#### 필수 출력

```ts
export type MarketAnalysisResult = {
  area: {
    id: string;
    label: string;
    latitude: number;
    longitude: number;
    radiusMeters: number;
  };
  competitors: Array<{
    id: string;
    name?: string;
    category: BeautyIndustry | 'RELATED';
    latitude: number;
    longitude: number;
    source: string;
    observedAt: string;
    status: 'ACTIVE' | 'UNKNOWN' | 'CLOSED';
  }>;
  metrics: Array<{
    key: 'competitorCount' | 'competitorDensity' | 'residentPopulation' | 'floatingPopulation' | 'marketSalesIndex' | 'businessCountChange' | 'footTrafficChange';
    label: string;
    value: number | null;
    unit: string;
    previousValue?: number | null;
    changePercent?: number | null;
    source: string;
    sourceUpdatedAt: string;
    periodLabel: string;
    geographyLabel: string;
    confidence: 'HIGH' | 'MEDIUM' | 'LOW' | 'UNAVAILABLE';
  }>;
  dataStatus: 'LIVE' | 'CACHED' | 'DEMO' | 'UNAVAILABLE';
  caveats: string[];
};
```

#### 지도 UX

- 모바일 우선, 상단 고정 검색창, 업종 선택, 반경 선택.
- 기준 위치는 핀으로 표시한다.
- 경쟁 업소는 줌 레벨에 따라 클러스터 또는 점으로 표시한다.
- 경쟁 밀도는 경쟁 업소 수와 면적당 업소 수를 동시 표기한다.
- 지도 레이어는 기본적으로 `경쟁`만 켜고, 최대 두 개만 동시에 켤 수 있다.
- `경쟁`, `주거 인구`, `유동`, `시장 추이` 탭을 구현한다.
- 각 데이터 카드에는 출처, 기준일, 공간 단위, 데이터 상태 버튼/툴팁을 넣는다.
- 데이터가 DEMO 상태이면 상단 sticky banner로 “데모 데이터 — 실제 창업 판단 전 공식/계약 데이터 연결 필요”를 표시한다.

### 1.3 후보지 비교

- 후보지는 최대 3개 저장한다.
- 동일 업종·반경·기간을 강제해 공정 비교한다.
- 비교 항목: 동종 업소 수, 업소 밀도, 주거 인구, 유동 지수, 시장 추이, 사용자 입력 임대료 메모.
- 지표마다 기준일이 다르면 해당 셀에 경고 아이콘·툴팁을 표시한다.
- “가장 좋음” 같은 단정 라벨 대신, 차이를 설명하는 가설을 제공한다.
- 종합 점수는 기본 화면에 사용하지 않는다. 설정에서 사용자가 가중치를 직접 고른 경우에만 `내 기준 비교`로 표시한다.

### 1.4 매출 감소 진단

#### 내부 지표

```ts
export type ShopPerformanceSnapshot = {
  period: { start: string; end: string };
  revenue: number;
  visitCount: number;
  uniqueCustomerCount: number;
  averageTicket: number;
  repeatRate: number | null;
  nextCareBookingRate: number | null;
  newCustomerCount: number | null;
  returningCustomerCount: number | null;
  discountAmount: number | null;
  variableCost: number | null;
};
```

#### 가설 생성 규칙

- 고객 수가 8% 이상 감소하고 객단가 변화가 -3% 이내이며, 동종 업소가 5% 이상 증가: `신규 발견성 약화 또는 경쟁 증가 가능성`.
- 재방문율이 5%p 이상 하락하고 경쟁 변화가 ±3% 이내: `서비스 경험 또는 다음 케어 흐름 단절 가능성`.
- 신규 고객이 감소하고 재방문은 유지되며 유동이 5% 이상 감소: `외부 유입 감소 가능성`.
- 고객 수는 유지되지만 객단가가 5% 이상 감소: `할인·메뉴 믹스·가격 압박 가능성`.
- 매출은 유지되지만 공헌이익이 감소: `변동비·할인·수수료 증가 가능성`.
- 내부 또는 외부 핵심 데이터가 없으면 원인 추정 카드를 만들지 말고, 필요한 데이터 연결/입력 체크리스트를 보여준다.

#### 모든 진단 카드의 필수 구조

```text
관찰 → 근거 → 가능한 해석 → 확인할 것 → 오늘 할 행동 → 이번 주 행동 → 30일 성공 지표 → 한계
```

### 1.5 액션 플랜

- 진단 또는 상권 전략 카드에서 `행동 계획 만들기`를 누르면 액션 플랜을 생성한다.
- 항목에는 제목, 설명, 기한, 우선순위, 연결 인사이트, 성공 지표, 상태가 있다.
- 상태: TODO / IN_PROGRESS / DONE / SKIPPED.
- 기한: TODAY / THIS_WEEK / THIS_MONTH / CUSTOM.
- 기본 화면은 `오늘`, `이번 주`, `30일 측정` 섹션.
- 완료 처리 후 성과 메모와 결과 수치를 기록할 수 있다.

---

## 2. UI/UX 완료 기준

### 2.1 디자인 시스템

```text
- 기본 언어: 한국어
- 통화: 원화, 천 단위 구분, 예: 12,870,000원
- 큰 금액은 보조 표기로 1,287만원도 함께 제공 가능
- 날짜: YYYY.MM.DD 또는 2026년 9월 기준처럼 일관되게 사용
- 모바일 최소 폭 360px
- 데스크톱은 지도와 인사이트 패널을 2열로 확장
- 상태는 색상만으로 표현하지 않고 아이콘·텍스트·패턴 병행
- 차트는 툴팁, 범례, 데이터 없음 상태, 기간 표시를 제공
- 탭/버튼/폼은 키보드 접근과 명확한 aria-label을 지원
```

### 2.2 핵심 화면

#### A. 목표 매출 플래너

```text
헤더: 목표 매출 플래너
입력: 목표 매출, 업종, 객단가, 변동비, 월 고정비, 목표 월 이익, 월 영업일
결과: 필요 목표 매출 / 월 필요 방문 / 하루 필요 방문 / 공헌이익률
보조: 가정 및 경고 / 계산식 보기
CTA: “이 목표를 상권에서 검토하기”
```

#### B. 상권 탐색 지도

```text
헤더: 상권 탐색
검색: 동네 또는 주소
필터: 업종 / 반경
지도: 기준점, 경쟁 업소, 클러스터, 선택 레이어
하단 카드: 동종 업소 / 업소 밀도 / 인구·유동·시장 추이
메타정보: 출처 / 기준 기간 / 갱신일 / 공간 단위 / 데이터 상태
CTA: “후보지 비교에 추가”, “현장 조사 계획 만들기”
```

#### C. 후보지 비교

```text
최대 3개 후보 카드
동일 조건 배지: 업종·반경·기간
비교 테이블
가설 카드: “A는 유동과 경쟁이 함께 높은 편입니다. 차별화와 검색 노출을 현장 조사로 확인하세요.”
CTA: “현장 조사 계획 만들기”
```

#### D. 매출 감소 진단

```text
상단: 최근 3개월 또는 선택 기간 매출 변화
차트: 매출 / 고객수 / 객단가 / 재방문 탭 전환
외부 변화: 동종 업소 변화, 유동 변화, 시장 추이
가설 카드: 근거 + 한계 + 행동
CTA: “이 행동을 계획에 추가”
```

#### E. 액션 플랜

```text
섹션: 오늘 / 이번 주 / 30일 측정
항목: 체크박스, 행동명, 기한, 우선순위, 연결 근거
완료: 성과 메모 및 수치 기록
빈 상태: “진단 또는 상권 탐색에서 행동을 계획으로 추가하세요.”
```

### 2.3 상태 설계

모든 비동기 화면에 아래 상태를 구현한다.

```text
loading: 스켈레톤, 레이아웃 유지
empty: 왜 데이터가 없는지 + 다음 행동
error: 사람이 이해할 메시지 + 재시도 + 오류 ID
stale: 마지막 성공 시각 + 갱신 시도
unauthorized: 필요한 권한 설명
no-location: 주소 검색 또는 권한 요청 대안
```

---

## 3. 데이터·DB·API 구현

### 3.1 DB 모델

기존 ORM 문법에 맞게 아래 개념을 구현하고 migration을 생성한다.

```text
FinancialGoalScenario
- id, organizationId, shopId, name, industry
- targetRevenue, fixedCost, targetProfit, averageTicket
- variableCostPerVisit, variableCostRate, operatingDays
- createdAt, updatedAt

MarketArea
- id, organizationId(nullable for shared area), label
- latitude, longitude, radiusMeters, geometry(optional)
- createdAt, updatedAt

MarketMetric
- id, marketAreaId, industry, metricKey, value, unit
- periodStart, periodEnd, geographyLabel
- sourceName, sourceUrl(optional), sourceUpdatedAt
- confidence, dataStatus, createdAt

CompetitorPlace
- id, externalId, name(nullable), category
- latitude, longitude, status, sourceName, observedAt
- createdAt, updatedAt

CompetitorSnapshot
- id, marketAreaId, competitorPlaceId, capturedAt

ShopDailyMetric
- id, shopId, date, revenue, visitCount, uniqueCustomerCount
- newCustomerCount, returningCustomerCount, discountAmount
- variableCost, nextCareBookingCount, eligibleNextCareCount

DiagnosticRun
- id, shopId, periodStart, periodEnd, marketAreaId(nullable)
- inputSnapshotJson, resultJson, createdAt

ActionPlan
- id, organizationId, shopId(nullable), diagnosticRunId(nullable)
- title, targetRevenueGap(nullable), status, createdAt, updatedAt

ActionItem
- id, actionPlanId, title, description, priority, dueType, dueDate(nullable)
- status, successMetric, outcomeNote(nullable), outcomeValue(nullable)
- sourceInsightId(nullable), createdAt, updatedAt

DataSourceRefreshLog
- id, sourceName, startedAt, completedAt(nullable), status
- recordsFetched, recordsProcessed, errorSummary(nullable)
```

### 3.2 API

모든 API는 인증·조직 격리·입력 검증을 포함한다.

```http
POST /api/financial-goals/calculate
POST /api/financial-goals
GET  /api/financial-goals
GET  /api/market-analysis?lat=&lng=&radiusMeters=&industry=&period=
POST /api/market-areas
POST /api/market-compare
POST /api/diagnostics/revenue-decline
GET  /api/action-plans
POST /api/action-plans
PATCH /api/action-items/:id
POST /api/action-items/:id/outcome
```

구현 요구:

```text
- request/response schema는 Zod 또는 프로젝트 표준 validator로 검증한다.
- 실패 응답은 code, message, requestId를 포함한다.
- 숫자·날짜·금액 정규화는 서버에서 한 번 더 수행한다.
- 조직/매장 소유권 확인을 모든 resource route에서 강제한다.
- 목록 API는 pagination 또는 안전한 상한을 둔다.
- 위치 검색/지도 provider는 server-side adapter 뒤에 감춘다.
```

### 3.3 상권 데이터 adapter

```ts
export interface MarketDataProvider {
  getCompetitors(input: MarketSearchInput): Promise<CompetitorPlace[]>;
  getMetrics(input: MarketSearchInput): Promise<MarketMetric[]>;
  getProviderStatus(): Promise<{
    status: 'LIVE' | 'DEMO' | 'UNAVAILABLE';
    sourceName: string;
    lastUpdatedAt: string | null;
  }>;
}
```

구현 규칙:

```text
- 실제 provider 연결이 설정돼 있으면 LiveProvider를 사용한다.
- 설정이 없으면 DemoProvider를 사용한다.
- DemoProvider는 seed 데이터와 deterministic generator를 사용한다.
- UI는 provider 상태를 반드시 노출한다.
- API 키가 없다며 앱 전체가 죽으면 안 된다. Demo/Unavailable 상태로 정상 렌더한다.
- 원천 데이터 지표를 내부 공통 schema로 normalize한다.
```

---

## 4. 파일·모듈 구조 기본안

기존 구조가 없다면 아래에 맞춰 생성한다.

```text
src/
  app/
    (dashboard)/
      management/
        goals/page.tsx
        diagnostics/page.tsx
        actions/page.tsx
      market/
        page.tsx
        compare/page.tsx
    api/
      financial-goals/
      market-analysis/
      market-compare/
      diagnostics/
      action-plans/
  components/
    financial-goals/
      financial-goal-form.tsx
      financial-goal-result.tsx
      calculation-explainer.tsx
    market/
      market-map.tsx
      market-filter-bar.tsx
      market-metric-card.tsx
      data-provenance.tsx
      competitor-density-card.tsx
      market-layer-control.tsx
      candidate-comparison-table.tsx
    diagnostics/
      performance-trend-chart.tsx
      hypothesis-card.tsx
      evidence-list.tsx
    action-plans/
      action-plan-board.tsx
      action-item-form.tsx
  lib/
    financial-goals/
      calculate.ts
      schemas.ts
      format.ts
    market/
      provider.ts
      providers/live-provider.ts
      providers/demo-provider.ts
      normalize.ts
      density.ts
      schemas.ts
    diagnostics/
      generate-hypotheses.ts
      schemas.ts
    auth/
    db/
  tests/
    unit/
    integration/
    e2e/
docs/
  market-analysis-implementation-log.md
  market-data-dictionary.md
```

---

## 5. P0 구현 순서

Cursor Agent는 아래 순서로 실제 구현한다. 각 작업은 테스트 통과까지 완료해야 다음 작업으로 넘어간다.

### P0-01 — 기반 탐색과 실행 가능 상태 확보

```text
- 프로젝트를 실행한다.
- package.json scripts와 환경 변수 예시를 확인한다.
- lint/typecheck/test/build 명령을 문서화한다.
- 없으면 최소한의 lint/typecheck/test 설정을 만든다.
- DB가 있으면 migration 실행 방법과 seed 방법을 확인한다.
- 디자인 시스템/라우팅/인증 패턴을 파악한다.
```

수용 기준:

```text
- 로컬 앱이 기동한다.
- lint/typecheck/test 또는 각각의 대체 명령이 실행된다.
- 실행 결과가 implementation log에 기록된다.
```

### P0-02 — 목표 매출 계산 도메인

```text
- calculateFinancialGoal 함수 구현
- Zod schema 구현
- 원화 포맷 유틸 구현
- 단위 테스트 구현
- 오류 메시지를 사용자 친화적 한국어로 정리
```

수용 기준:

```text
- 명시된 골든 케이스가 통과한다.
- 비정상 입력이 안전하게 차단된다.
- 계산 로직은 UI와 API에서 재사용된다.
```

### P0-03 — 목표 매출 플래너 UI·저장 API

```text
- 반응형 폼, 결과 카드, 계산식 설명, 저장 기능
- 입력 중 debounce 계산
- loading/empty/error/saved 상태
- “이 목표를 상권에서 검토하기” 딥링크/상태 전달
- 접근성 레이블·오류 요약
```

수용 기준:

```text
- 360px 모바일에서 가로 스크롤 없이 사용 가능
- 결과: 필요 매출, 월/일 방문, 공헌이익률
- 저장 후 새로고침해도 시나리오 유지
```

### P0-04 — 상권 provider·seed·API

```text
- MarketDataProvider adapter
- LiveProvider stub/config boundary
- DemoProvider와 deterministic seed
- Market analysis API
- 출처/기간/공간 단위 메타정보 필수
- API 오류/데이터 없음 처리
```

수용 기준:

```text
- 외부 데이터 연결 여부와 무관하게 API가 일관된 schema를 반환
- DEMO/LIVE/UNAVAILABLE 상태가 응답과 UI에 전달됨
- DEMO 데이터는 반드시 데모 레이블을 가짐
```

### P0-05 — 지도·경쟁 밀도 UI

```text
- 주소 검색 또는 좌표 입력 fallback
- 핀·반경 원·경쟁점/클러스터
- 경쟁 밀도 계산
- 레이어 토글 최대 2개
- 지도/카드 동기화
- 데이터 출처 컴포넌트
```

수용 기준:

```text
- 1/3/5/10km 반경 변경이 지표와 지도에 반영됨
- 경쟁 수와 면적당 밀도가 함께 표시됨
- 위치 권한 거부 상태에서도 주소 검색으로 진행 가능
```

### P0-06 — 후보지 비교

```text
- 최대 3개 후보 저장
- 동일 업종·반경·기간 비교
- 비교 테이블과 기간 불일치 경고
- 가설 문구와 현장 조사 액션 생성
```

수용 기준:

```text
- 후보지 2~3개 비교가 가능
- 종합 성공 판정 없이 데이터 차이를 설명
- 현장 조사 체크리스트가 액션 플랜으로 연결
```

### P0-07 — 내부 운영 지표·매출 감소 진단

```text
- ShopDailyMetric schema/집계
- 기간 비교 API
- 규칙 기반 가설 엔진
- 근거/한계/검증/행동 구조의 UI 카드
- 데이터 부족 상태
```

수용 기준:

```text
- 규칙별 단위 테스트
- 동일 데이터로 동일 진단 결과 재현 가능
- 근거 없는 가설은 렌더되지 않음
```

### P0-08 — 액션 플랜·성과 기록

```text
- ActionPlan/ActionItem CRUD
- 오늘/이번 주/30일 UI
- 완료/스킵/진행 상태
- 성과 메모/수치 기록
- 진단과 상권 카드에서 액션 생성
```

수용 기준:

```text
- 액션 생성, 상태 변경, 새로고침 후 유지
- 액션마다 연결된 근거와 성공 지표가 표시됨
```

### P0-09 — 통합 QA·문서·관측성

```text
- 핵심 E2E: 예비 원장 플로우, 기존 원장 플로우
- 빈/오류/데모/권한 상태 테스트
- market-data-dictionary 문서 작성
- 이벤트 이름과 PII 제외 규칙 문서화
- 오류 경계와 request ID 구현
```

수용 기준:

```text
- build 성공
- 모든 핵심 단위/통합/E2E 테스트 통과
- 수동 QA 체크리스트를 문서화
```

---

## 6. 테스트 요구사항

### 6.1 Unit test

```text
financial-goals
- 정상 입력 골든 케이스
- variableCostPerVisit 우선 적용
- variableCostRate 입력
- 경계값·유효성 검증
- 반올림/올림

market
- 반경 면적 계산
- 업소 밀도
- provider normalize
- demo 상태 라벨

diagnostics
- 각 가설 조건
- 상충 조건
- 데이터 부족 시 카드 미생성

actions
- 기한 bucket 분류
- 상태 전이
```

### 6.2 Integration test

```text
- 목표 계산 API schema·권한·저장
- 시장 분석 API metadata 포함 여부
- 후보 비교 API 동일 조건 검증
- 진단 API가 내부/외부 데이터와 함께 근거를 반환
- Action CRUD 조직 격리
```

### 6.3 E2E test

```text
예비 원장:
목표 매출 입력 → 결과 확인 → 상권 탐색 이동 → 반경 선택 → 후보 추가 → 비교 → 현장 조사 액션 생성

기존 원장:
매출 감소 진단 → 차트 확인 → 가설 근거 열기 → 행동 계획 생성 → 완료 및 성과 기록

회복성:
지도 provider unavailable → 오류가 아닌 안내·재시도·대체 입력
데이터 없음 → 원인과 다음 행동 노출
모바일 360px → 핵심 CTA 접근 가능
```

---

## 7. 데이터 사전 요구사항

`docs/market-data-dictionary.md`를 생성하고, 지표마다 아래를 문서화한다.

```text
- 표시 이름
- 내부 key
- 정의/계산식
- 단위
- 가능한 공간 단위
- 가능한 기간 단위
- 출처
- 갱신 주기
- 데이터 한계
- UI 표기 방식
- 의사결정에 사용할 때의 주의점
```

최소 항목:

```text
동종 업소 수
동종 업소 밀도
주거 인구
유동 인구/유동 지수
시장 매출 또는 매출 지수
업소 수 증감
유동 변화율
매출 변화율
재방문율
다음 케어 예약률
객단가
공헌이익률
목표 대비 매출 부족분
```

---

## 8. 수동 QA 체크리스트

```text
[ ] 목표 매출 플래너에서 숫자 입력/삭제 시 UI가 깨지지 않는다.
[ ] 0, 음수, 매우 큰 숫자, 소수 입력이 안전하게 처리된다.
[ ] 모든 금액이 원화 형식으로 표시된다.
[ ] 목표 매출에서 상권 분석으로 이동해 선택 업종과 목표 방문 수가 유지된다.
[ ] 지도 반경 변경 시 경쟁 수와 밀도가 즉시 동기화된다.
[ ] 지도 데이터 상태가 LIVE/CACHED/DEMO/UNAVAILABLE 중 하나로 보인다.
[ ] DEMO 데이터는 운영 데이터처럼 보이지 않는다.
[ ] 후보지 비교는 최대 3개까지만 가능하다.
[ ] 다른 기간/공간 단위 비교는 눈에 띄는 경고가 있다.
[ ] 진단 카드는 관찰·근거·행동·한계를 모두 보여준다.
[ ] 데이터가 부족하면 원인 단정 대신 필요한 데이터 목록을 보여준다.
[ ] 액션을 완료·스킵·진행 상태로 바꾸고 새로고침해도 유지된다.
[ ] 조직 A 사용자가 조직 B 데이터에 접근할 수 없다.
[ ] 모바일 360px, 태블릿, 데스크톱에서 핵심 흐름이 동작한다.
[ ] 키보드만으로 폼·탭·지도 대체 입력·CTA에 접근할 수 있다.
```

---

## 9. 구현 로그 템플릿

Cursor Agent는 `docs/market-analysis-implementation-log.md`에 아래 형식으로 누적 기록한다.

```markdown
# SORI 상권분석 구현 로그

## 환경 확인
- 실행 명령:
- lint:
- typecheck:
- test:
- build:
- DB/seed:

## P0-XX 작업명
- 상태: TODO | IN_PROGRESS | DONE | BLOCKED
- 수용 기준:
- 구현 파일:
- 테스트 파일:
- 검증 명령:
- 결과:
- 결정 사항:
- 차단 원인(해당 시):
- 대체 구현(해당 시):
```

---

## 10. 최종 완료 선언 조건

Cursor Agent는 아래를 모두 충족할 때만 “완료”라고 보고한다.

```text
1. 목표 매출 계산이 UI, API, 테스트에서 일관되게 동작한다.
2. 지도 기반 상권 탐색이 LIVE 또는 명시적 DEMO/UNAVAILABLE 모드로 동작한다.
3. 모든 상권 지표에 출처·기간·갱신일·공간 단위가 노출된다.
4. 최대 3개 후보지 비교와 현장 조사 액션 생성이 작동한다.
5. 매출 감소 진단이 설명 가능한 규칙과 근거를 제공한다.
6. 액션 플랜이 저장, 상태 전환, 성과 기록을 지원한다.
7. loading/empty/error/unauthorized/stale 상태가 구현된다.
8. 단위·통합·핵심 E2E 테스트가 통과한다.
9. lint, typecheck, production build가 통과한다.
10. 구현 로그와 데이터 사전이 최신 상태다.
```

완료 후에도 외부 실제 데이터 공급자 연결이 없는 경우, Agent는 기능을 멈추지 않는다. DemoProvider 및 명확한 “데모 데이터” 고지로 모든 기능을 동작시킨 뒤, LiveProvider 연결에 필요한 환경 변수·계약·필드 매핑만 최종 보고에 정리한다.
