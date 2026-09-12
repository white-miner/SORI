# 시사회 5분 스크립트 — 실제 route만

준비는 `docs/SHOWCASE_DEMO_DATA.md`. 이 문서는 **본편 5분**만 적는다.
새 화면·새 도메인을 만들지 않는다. `b4fe645` 루프 CTA를 그대로 탄다.

웹 base: `https://white-miner.github.io/SORI/` (`HashUrlStrategy` → 경로는 `/#/...`).

## 입구

| 분 | 동작 | 실제 경로 / 위젯 |
|---|---|---|
| 0:00 | 카카오 원장 로그인 | `/#/login` → 온보딩이 끝났으면 `/#/app/home` |
| 0:20 | 홈 **오늘** | `/#/app/home` · `VisitLauncherPage` 오늘 탭 |

로그인 실패·온보딩 미완·Pages 5xx는 P0로 즉시 멈춘다. Timer·지도·피드로 우회하지 않는다.

## 본편

### A. 오늘 → 고객

**오늘 일정이 있으면**

1. 홈 스트립 `home-today-next-strip` / 글랜스 행 `home-today-glance-row-{id}` 탭.
2. `CareStartFromSchedule.begin` → 해당 `customerId` 방문 세션. (Timer 숫자를 만지지 않는다. 포커스만.)

**오늘 일정이 없으면**

1. `home-today-empty-start` **재방문 고객으로 시작**, 또는 GNB 고객 `/#/app/customers`.
2. 대표 고객을 골라 `/#/app/customers/{id}` (`AppPaths.customerDetail`).

고객 목록 검색은 기존 CRM이다. 새 picker를 만들지 않는다.

### B. 차트 → B/A 또는 카메라

1. `CustomerChartPage` 기본 탭 타임라인. **사진** 탭으로 이동.
2. **B/A 가능 회차:** 행 `customer-chart-photo-row-{chartId}` 탭 → `BeforeAfterComparePage`.
3. **After 없음 회차:** `customer-chart-photo-capture-{chartId}` **After 촬영** (없으면 **결과 촬영**) → `SmartGuideCameraPage.open` (ShootHub와 동일 카메라).

`/app/review` ShootHub로 돌아가 고객을 다시 고르지 않는다. 차트에 이미 customer/visit이 있다.

### C. 저장 → 차트 복귀

1. 카메라 저장 → `updateCustomerChartFields` / `patchChartAfterImage`.
2. 차트에서 찍었으면 같은 방문으로 `openBeforeAfterComparePage`.
3. ShootHub에서 연결 촬영을 했을 때만 `CustomerChartPage(revealLatestResult: true)` 로 돌아온다. **미연결 큐는 고객 차트에 넣지 않는다.**

저장 실패 스낵바(`촬영 저장 실패`)면 P0. 결제·동의 화면으로 빠져나가지 않는다.

### D. next care 시작 또는 생성

차트 상단:

- **있음:** `customer-chart-next-care` **케어 시작** → `CareStartFromSchedule.begin`.
- **없음:** `customer-chart-schedule-next` **다음 케어 일정 잡기** → 기존 date/time picker → `SoriStore.addManualCareSchedule`.

방문 세션을 끝까지 닫는 시사회면, 완료 시트 `visit-complete-schedule-next`가 같은 생성 경로다.

### E. 고객 Care 탭 (권한 분리)

1. 세션 전화 = 대표 고객 전화일 때만 셸 **고객 화면으로 보기** (`toggleActiveMode`).
2. GNB 두 번째 탭 = `CustomerCareTab`, 경로 여전히 `/#/app/customers` (원장 CRM이 아님).
3. next care 있음: `customer-care-next-visit` (날짜·시간·케어명만).
4. 없음: `customer-care-next-visit-empty` **다음 방문이 아직 없어요**.
5. `care_schedule.note` · 고객 전화 · 원장 전용 필드를 읽어 주지 않는다.

전화가 다르면 이 단계는 **그 고객 카카오 로그인**으로만 한다. 원장 모드에서 타인 Care를 열어 보여 주지 않는다.

## 한 줄 동선

`/#/login` → `/#/app/home` → `/#/app/customers/{id}` → 사진 탭 → 비교 또는 `SmartGuideCameraPage` → 저장 → 차트/비교 → 케어 시작 또는 `addManualCareSchedule` → (권한 맞는 세션만) `CustomerCareTab`.

5분을 넘기면 커뮤니티·지도·경영·회원권 편집을 건너뛴다.
