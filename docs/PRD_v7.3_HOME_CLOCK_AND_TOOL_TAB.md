# PRD v7.3 — 홈 플립시계 실시간 + Timer/Tool 탭 평가

- 문서 성격: **평가 + 기획**. PO 컨펌 전까지 `lib/` 무수정.
- 상위 헌법: `docs/PRD_v7.0_MY_FEED_HOME_ARCHITECTURE.md` §4.1 히어로, Q1(b) Timer 탭 이관.
- 작성일: 2026-09-03.

---

## §0 Executive Summary

**시계는 못 가는 게 아니라, 안 돌리고 있다.** 실시간 매칭은 가능하다. My Feed에서 시계를 빼거나 타이머만 남기는 처방은 오진이다.

**Timer → Tool 개명은 지금 하지 않는다.** 3번째 탭의 현장 충분조건은 이미 케어 타이머(2탭 시작, 풀스크린 1초 틱, 진행 중 초록 점)다. 날씨·계산기·외부환경 OS를 이번에 새로 쌓으면 반제품이 된다.

| 항목 | 판정 |
|---|---|
| 홈 플립시계 실시간 | **가능 · 필수 수정** (이관 누락) |
| 시계 제거 | **비권고** |
| Timer 탭 집중 | **현행 유지** (현장 충분조건 충족) |
| Tool 개명 + 환경 대시보드 | **후속**. 기존 카드 탑재만으로 충분, 신기능 불필요 |

---

## §1 현상

홈 탭 My Feed 상단 플립시계(HH:MM + 우하단 초)가 **당겨서 새로고침해야만** 숫자가 바뀐다. 화면을 가만히 두면 초와 분이 멈춘다.

원장 체감: "시계가 장식이다."

---

## §2 원인 (파일 근거)

`FlipClockDisplay`는 시계 엔진이 아니다. `totalSeconds`를 받아 플립 타일을 그리는 **StatelessWidget**이다 (`lib/features/operation/widgets/flip_clock_display.dart`).

홈 히어로는 그 값을 이렇게 넣는다.

```70:73:lib/features/visit/widgets/home_hero_card.dart
  int _wallClockSeconds() {
    final now = DateTime.now();
    return now.hour * 3600 + now.minute * 60 + now.second;
  }
```

```178:188:lib/features/visit/widgets/home_hero_card.dart
                    final clock = isCount
                        ? CountdownFlipZone(controller: ctrl)
                        : FlipClockDisplay(
                            totalSeconds: _wallClockSeconds(),
                            hero: true,
                            homeHero: true,
                            showSeconds: false,
                            showCornerSeconds: true,
```

`_wallClockSeconds()`는 **build가 일어날 때만** `DateTime.now()`를 읽는다. HomeHeroCard의 rebuild 트리거는 다음뿐이다.

- `HomeDashboardController.notifyListeners` (달력, 카운트, 툴 하이라이트)
- `SoriStore` 알림
- My Feed pull-to-refresh → `_load(force: true)` (`visit_launcher_page.dart`)

**1초 루프가 없다.** 그래서 새로고침이 "틱"처럼 느껴진다.

같은 코드베이스에서 1초 틱은 이미 세 곳에서 돈다.

| 위젯 | 틱 | 결과 |
|---|---|---|
| `SmartFlipTimerHero` | `Timer.periodic(1s) → setState` (`smart_flip_timer_hero.dart:54`) | 구 상담 히어로 초가 움직임 |
| `VisitTimerStore` | `_tickTimer` 1s (`visit_timer_store.dart:611`) | 케어 풀스크린 타이머 정상 |
| `HomeDashboardController` | `_countTickTimer` 1s (`home_dashboard_controller.dart:130`) | 카운트다운 모드만 움직임 |
| **HomeHeroCard 벽시계** | **없음** | **정지** |

v7.0은 히어로를 `HomeHeroCard`로 옮기면서 **표시 스펙(132dp, corner SS)만 가져오고, SmartFlipTimerHero의 티커를 두고 왔다.** 플랫폼 제약이 아니라 이관 누락이다.

실시간 매칭은 가능하다. 고치는 규모는 HomeHeroCard에 구 히어로와 같은 `Timer.periodic`을 되돌리는 수준이다 (약 15줄). 앱 `paused` 때 틱을 멈추고 `resumed` 때 `DateTime.now()`로 재동기하면 배터리와 점프를 같이 막는다.

---

## §3 시계에 대한 선택지

### A. 티커 복구 (권고)

- `HomeHeroCard` `initState`에서 1초 틱, `dispose`에서 cancel.
- `WidgetsBindingObserver`로 백그라운드 정지 / 복귀 재동기 (런처 페이지에 이미 observer가 있다).
- 카운트다운 모드(`CountdownFlipZone`)와 벽시계 틱이 겹치지 않게, 벽시계일 때만 돌린다. 카운트는 컨트롤러 틱이 SSOT.
- 히어로 카드·스케줄러 스트립·PRD v7.0 §4.1 시안을 유지한다.

### B. My Feed에서 시계 제거 / 타이머만 남김 (비권고)

- 버그를 제품 후퇴로 닫는다.
- 카운트다운이 같은 히어로 자리를 빌려 쓴다. 벽시계를 들어내면 그 시각 언어가 사라진다.
- "실시간 불가"가 전제인데, 전제가 거짓이다.

**PO가 A를 고르면 구현으로 바로 간다.** B는 이 리포트의 권고를 뒤집는 결정이다.

---

## §4 Timer 탭 현황 (Tool 개명 평가의 바닥)

홈 GNB: `HomeTab { myFeed, program, timer }` — 라벨 `My Feed` / `Program` / `Timer` (`visit_launcher_page.dart:53, 933-939`).

Timer 본문 (`_buildTimerPane`)은 v5.4 자산 3종을 시각 스펙 변경 없이 모은 것이다 (PRD v7.0 Q1(b)).

| 자산 | 위치 | 완성도 | 현장 |
|---|---|---|---|
| 케어 타이머 풀스크린 | 타이머 아이콘 / 케어 시작 | 실사용 | **충분조건** |
| 프리셋 퀵픽 | 탭 본문 | 실사용 | 높음 |
| 진행 중 초록 점 | Timer 탭 라벨 | 실사용 | 높음 |
| 카운트다운 | **My Feed 히어로** | 실사용 | 자리 분리. Tool로 옮기지 말 것 |
| 계산기 | 툴박스 → 하단 시트 | 사칙연산만 | 얇음 |
| 날씨·기온·UV 아이콘 | 툴박스 3칸 | 1시간 KMA 캐시, 탭→임상 시트 | 조회 |
| `EnvironmentWidgetCard` | 상담 위젯 보드 | **홈에 미탑재** | 자산만 있음 |

기후 서비스는 1시간 클라이언트 캐시다 (`shop_climate_service.dart` `_cacheTtl = Duration(hours: 1)`). 초 단위 "조작" 대상이 아니다.

계산기는 회원권·패키지 단가와 연결되지 않는다. Program 산수(`ProgramPricing`)와 섞으면 세일즈 OS를 오염시킨다.

---

## §5 Tool 탭 기획 — 충분 vs 반제품

원장 제안: Timer 대신 Tool을 두고 케어 타이머 / 계산기 / 날씨 / 외부환경 데이터를 모은다.

### 에이전트 판정

**현장에서 유용한 모양새는 이미 타이머에 있다.** 원장이 케어를 2탭으로 시작하고, 진행 중이면 탭에 점이 뜨고, 풀스크린 플립이 1초로 간다. 이 경로를 다시 설계할 이유가 없다.

**이름만 Tool로 바꾸면 허명이다.** 본문이 케어 실행기인 동안 원장은 대시보드를 기대하고 아이콘 한 줄을 만난다.

**환경·계산기를 이번에 새로 설계하면 반제품이다.** 카드(`EnvironmentWidgetCard`)와 시트(`QuickCalculatorSheet`, `showClinicalAssistantSheet`)는 이미 있다. 없는 것은 조립이다. 새 프로바이더·새 계산 엔진은 이번 스프린트 범위가 아니다.

### 후속 슬라이스 (Q3가 yes일 때만)

1. Timer 본문 상단에 기존 `EnvironmentWidgetCard`를 붙인다. 새 날씨 API 없음.
2. 툴박스 6아이콘은 유지한다. 계산기 시트는 사칙연산으로 둔다 (Program 단가 금지).
3. 그때 탭 라벨을 `Tool`로 바꾼다. 진행 중 초록 점은 유지.
4. 카운트다운은 My Feed 히어로에 남긴다.

이 조립이 되기 전에는 **탭 이름을 Timer로 둔다.**

---

## §6 구현 슬라이스 (컨펌 후)

| 슬라이스 | 내용 | 완료 판정 |
|---|---|---|
| **C1** (P0) | HomeHeroCard 벽시계 1초 틱 + paused/resumed 재동기 | My Feed를 열어 둔 채 초가 바뀌고, 앱을 내렸다 올리면 분·초가 맞다. 새로고침 불필요 |
| **C2** (P0) | 카운트다운·케어 타이머와 틱 분리 | 카운트 중 히어로는 카운트 SSOT만 쓰고, 케어 풀스크린은 VisitTimerStore만 쓴다 |
| **T1** (후속) | EnvironmentWidgetCard를 Timer 본문에 탑재 | 툴박스 아래 환경 카드 1장. 배너 없음 |
| **T2** (후속, T1 이후) | 탭 라벨 Timer → Tool | 초록 점 유지 |

C1/C2만 이번 컨펌 범위다. T1/T2는 Q3.

---

## §7 PO 결정 요청

**Q1 — My Feed 플립시계**
- (a) 살리고 1초 틱을 복구한다 (**권고**)
- (b) 히어로에서 시계를 빼고 타이머/카운트만 남긴다

**Q2 — 3번째 탭 이름**
- (a) Timer 유지 (**권고**, 본문이 케어 실행기인 동안)
- (b) 지금 Tool로 개명한다 (허명 감수)

**Q3 — 환경 카드**
- (a) 후속. 이번엔 시계만 (**권고**)
- (b) 기존 EnvironmentWidgetCard를 Timer 본문에 바로 올린다 (새 API 없이)

권고 묶음은 **Q1(a) + Q2(a) + Q3(a)** 다. 승인되면 C1/C2만 구현한다.

---

*작성: 코드 조사 기준 `main` @ 2145a41 이후 워크트리. `lib/` 변경 0.*
