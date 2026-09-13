# SORI 오늘 밤 연속완수 백로그 및 실행지시

> **저장 위치:** `docs/SORI_OVERNIGHT_DELIVERY_BACKLOG.md`  
> **기준 브랜치:** `origin/main` at `224d366` (Deploy 25 기준; 새 main SHA가 있으면 최신 main을 기준으로 한다)  
> **목표:** 오늘 밤 동안 시사회와 실제 샵 사용을 막는 P0를 먼저 제거하고, 남는 시간에는 이미 구축된 원장 운영·고객 변화·콘텐츠·우리 지역 흐름을 배포 단위로 확장한다.

---

# 1. 현재까지 배포된 기반

## 원장 운영 루프

```text
오늘 홈
→ 다음 고객 또는 재방문 고객 선택
→ 케어 시작/고객 차트 진입
→ next care가 있으면 시작
→ 없으면 addManualCareSchedule로 일정 생성
```

## 기록·변화 루프

```text
고객 차트 사진 탭
→ B/A 비교
→ After/비교 불가면 기존 카메라 경로
→ 연결 촬영 저장
→ 같은 customer/visit의 최신 B/A로 차트 복귀
```

## 콘텐츠 자산 루프

```text
적격 B/A
(B/A 있음 + canPublishBa + 커뮤니티 미발행)
→ 콘텐츠 후보로 만들기
→ 원장 마이 Posts 후보함
→ 카드 상세
→ 발행 준비 완료
```

## 우리 지역 발견 루프

```text
우리 지역 업체 카드
→ 지도에서 보기
→ 기존 지도/Place URL
→ 좌표
→ 주소 검색
→ 업체명 + 지역 검색 fallback
```

---

# 2. 오늘 밤의 유일한 목적

> **시사회에서 원장 한 명과 고객 한 명의 실제 흐름이 멈추지 않고 끝까지 가며, SORI가 기록을 다음 케어·콘텐츠·지역 발견으로 전환하는 앱임을 보여준다.**

오늘 밤에는 완벽함을 만들지 않는다. 각 작업은 다음 중 하나를 달성해야 한다.

1. 시사회 5분 루프의 route/CTA/state 단절 제거
2. 실제 샵에서 원장이 당장 쓸 수 있는 행동 하나 완성
3. 고객이 자기 변화와 다음 케어를 이해하는 행동 하나 완성
4. 이미 생성된 기록을 콘텐츠 또는 지역 판단으로 전환

이 네 가지에 속하지 않는 작업은 `docs/SHOWCASE_FOLLOWUPS.md`로 보낸다.

---

# 3. 남은 개발 전체 목록

아래는 **현재까지 합의된 제품 방향 기준**의 남은 개발 항목이다. 오늘 밤에는 P0 → P1 → P2 순서로 진행하며, 시간 부족 시 현재 PR/배포 단위를 마친 뒤 다음 항목으로 이동한다.

## P0 — 시사회·실제 샵 사용 차단 요소

| ID | 남은 개발 | 사용자 결과 | 완료 판단 |
|---|---|---|---|
| P0-1 | Deploy 26: 우리 지역 탐색 조건 요약 | 사용자가 현재 반경·카테고리·결과 수를 즉시 이해 | 목록 상단에 조건과 결과 수, 0건 empty state가 있음 |
| P0-2 | 0건 결과 회복 CTA | 결과가 없으면 반경을 넓혀 즉시 다시 탐색 | 기존 radius handler로 다음 단계 반경을 적용 |
| P0-3 | 5분 시사회 demo flow smoke | 대표 고객으로 시작해 오늘→차트→B/A/촬영→next care→고객 Care까지 반복 | `docs/SHOWCASE_DEMO_SCRIPT.md`의 모든 step이 실제 route와 맞음 |
| P0-4 | Demo data reset/prep 절차 | 시사회/실샵 테스트 때 같은 고객 상태를 다시 준비 | `docs/SHOWCASE_DEMO_DATA.md`에 준비·복구 절차가 있음 |
| P0-5 | 핵심 루프 blocker 제거 | 로그인, 저장, customer/visit context, CTA, Pages 접근의 실패 제거 | blocker 0 또는 각각 배포된 수정 PR 존재 |
| P0-6 | 고객 공개 범위 smoke | 고객 화면에 내부 note/전화/원장 판단이 보이지 않음 | CustomerCareTab과 결과 surface가 whitelist만 노출 |
| P0-7 | 시사회 운영 문서 | 진행자가 5분 안에 같은 시나리오를 수행 | demo script, demo data, release notes, followups 존재 |

### P0 실행 규칙

- P0-1과 P0-2는 Deploy 26으로 같은 PR에 묶는다.
- P0-3~P0-7은 코드가 아니라 실제 blocker가 있을 때만 코드 변경한다.
- 실제 blocker가 없으면 문서/체크리스트 업데이트 후 즉시 P1으로 간다.
- P0에서 새로운 기능, 신규 DB, AI, 결제, 지도 SDK를 만들지 않는다.

---

## P1 — 시사회 가치를 크게 만드는 다음 기능

| ID | 남은 개발 | 사용자 결과 | 범위 원칙 |
|---|---|---|---|
| P1-1 | 우리 지역 업체 상세 요약 | 카드/상세에서 업체명·업종·거리/주소·지도 CTA를 한 번에 이해 | 기존 데이터만 재사용 |
| P1-2 | 원장 오늘: 미완료 기록/후속 케어 우선화 | 원장이 오늘 놓치면 안 되는 일을 먼저 봄 | 기존 visit/care data만 표면화 |
| P1-3 | 고객 차트 최신 변화 요약 | 최근 시술·B/A·다음 케어를 첫 진입에서 빠르게 파악 | 차트 재설계 금지 |
| P1-4 | 고객 홈/Care 다음 케어 강화 | 고객이 다음 방문과 홈 케어를 쉽게 이해 | whitelist 내 데이터만 |
| P1-5 | 콘텐츠 후보함 상태 명확화 | 초안과 발행 준비 완료가 무엇인지 원장이 이해 | 새 발행 API 없음 |
| P1-6 | 콘텐츠 후보에서 copy/share 준비 | 외부 게시 전 제목/요약/공유 가능한 준비물 확인 | 자동 SNS 발행 없음 |
| P1-7 | After 없음 촬영 진입의 맥락 안내 | 왜 촬영해야 하는지와 저장 후 돌아올 곳을 이해 | camera flow 변경 금지 |
| P1-8 | 핵심 빈 상태/오류 회복 | 원장/고객이 멈추지 않고 첫 행동 또는 재시도 가능 | 한 PR 한 마찰 |

---

## P2 — 상용화 후보 이후 확장

| ID | 남은 개발 | 제품 가치 |
|---|---|---|
| P2-1 | 고객 반응/문의 신호 수집과 원장 follow-up | 관계와 재방문을 데이터로 전환 |
| P2-2 | 콘텐츠 후보의 채널별 패키징 | Instagram/Facebook/YouTube용 자산화 |
| P2-3 | SNS 실제 게시 연동 | 별도 동의·권한·채널 정책 설계 후 |
| P2-4 | 우리 지역 공공데이터 지표 | 연 매출 등 명확한 출처의 시장 판단 |
| P2-5 | 상권 분석/기대값 모델 | 컨설팅 수준의 의사결정 지원 |
| P2-6 | 원장 운영 지능 dashboard | 미완료·후속 케어·재방문·기회 우선화 |
| P2-7 | 대화형 상담 캡처·검색 | 상담 기록을 즉시 찾고 제안에 사용 |
| P2-8 | 메뉴/코스 앵커링 제안 | 합리적 상담과 매출 제안 지원 |
| P2-9 | 팀/스태프 역할·권한 | 샵 운영 확장 |
| P2-10 | 멀티샵/프랜차이즈 | 운영 OS 확장 |
| P2-11 | 결제/정산/구독 고도화 | 비즈니스 확장 |
| P2-12 | 레거시 화면 정리 및 전체 polish | 제품 규모 확장 뒤 일관성 정리 |

---

# 4. 오늘 밤 연속 실행 순서

## Deploy 26 — 우리 지역 탐색 조건과 0건 회복

### 사용자 결과

```text
우리 지역
→ 내 주변 [반경] 안의 [카테고리] 뷰티숍
→ [결과 수]곳 발견
→ 업체 카드
→ 지도에서 보기

0곳
→ 이 조건에서 찾은 뷰티숍이 없어요
→ 반경 넓히기
→ 기존 목록 재탐색
```

### 구현

1. 현재 region/radius/category/result count를 만드는 기존 state/selector 확인
2. 목록 상단에 조건 요약과 결과 수 노출
3. 결과 0건에서만 empty state와 반경 넓히기 CTA 노출
4. 기존 radius state/handler로 다음 허용 반경 단계 선택
5. 다음 반경 단계가 없으면 CTA 숨김
6. 업체 카드의 지도 CTA와 FlutterMap/RegionMapExploreSheet는 변경하지 않음

### 금지

```text
새 map SDK/API
새 backend/search/data collection
공공 매출 데이터
주소 정규화
예약/결제/AI
schema/migration
FlutterMap gesture/RegionMapExploreSheet/AppShell 변경
```

### 완료

```text
analyze → relevant tests → build web → CI → Pages deploy
```

---

## Deploy 27 — 우리 지역 업체 상세 요약

### 사용자 결과

> 사용자는 업체를 선택했을 때 “이곳이 어디이고 무엇을 하는 곳이며, 어떻게 확인할지”를 즉시 안다.

### 구현

- 기존 업체 카드 또는 이미 존재하는 상세 진입점에 아래만 표시
  - 업체명
  - 업종/카테고리
  - 거리 또는 주소(존재하는 값만)
  - 지도에서 보기 CTA
- 데이터가 없는 항목은 억지 placeholder를 만들지 않고 숨김
- 새 상세 화면이 필요하면 기존 bottom sheet/card detail 컴포넌트를 재사용

### 금지

- 지도 화면 재작성
- 신규 업체 데이터 pipeline
- 예약/리뷰/상권 점수
- 신규 DB schema

---

## Deploy 28 — 원장 오늘의 후속 업무 우선화

### 사용자 결과

> 원장이 오늘 화면을 열면, 다음 일정뿐 아니라 **놓치면 안 되는 후속 케어 또는 미완료 기록**을 우선적으로 본다.

### 구현 후보

현재 코드에서 가장 작은 한 가지를 선택한다.

1. 기존 `care_schedule` 중 기한이 가깝거나 오늘 대상인 고객을 priority card로 노출
2. 미완료 visit/record가 있으면 재개 CTA를 노출
3. 오늘 일정이 없을 때 재방문 고객 선택과 next-care creation을 더 가깝게 배치

### 성공 기준

```text
오늘 화면
→ 지금 처리할 고객/후속 행동
→ 한 번 탭
→ 기존 실제 작업 route
```

### 금지

- 새 priority 엔진/AI
- Timer 산식 변경
- 새 DB schema
- 대시보드 전면 재설계

---

## Deploy 29 — 고객 차트의 최신 변화·다음 케어 요약

### 사용자 결과

> 원장과 고객은 차트를 열자마자 최근 변화와 다음 관리를 이해한다.

### 구현 후보

- 차트 상단 또는 기존 탭 header에 최신 visit/service/B-A/next-care의 짧은 summary
- 데이터가 없으면 첫 기록/촬영/케어 CTA 중 기존 경로 하나
- 고객용 surface는 whitelist 정보만 표시

### 금지

- 타임라인 전체 재작성
- 고객에게 내부 note/운영 판단 노출
- 새 분석 엔진

---

## Deploy 30 — 콘텐츠 후보함의 발행 준비 경험 정리

### 사용자 결과

> 원장은 후보가 초안인지 발행 준비 완료인지 즉시 이해하고, 필요한 결과를 다시 찾는다.

### 구현

- 상태 레이블/empty state/정렬 중 가장 작은 한 가지를 고른다.
- 후보 카드의 대표 이미지, 서비스명, 생성일, 상태 외 개인정보·내부 정보는 표시하지 않는다.
- 외부 SNS 발행, AI 카피, 새 동의 흐름은 하지 않는다.

---

## Deploy 31 — 시사회 수렴

### 목적

새 기능이 아니라, 대표 고객 1명으로 다음 루프가 5분 안에 반복되도록 막힘만 제거한다.

```text
/#/login
→ /#/app/home
→ /#/app/customers/{id}
→ 사진 탭
→ B/A 비교 또는 SmartGuideCameraPage
→ 저장
→ 같은 customer/visit 차트 복귀
→ next care 시작 또는 addManualCareSchedule
→ 같은 전화번호 세션에서 CustomerCareTab
```

### 처리 기준

- route, customer/visit context, 저장, CTA, empty state, 로그인, Pages 접근을 막는 것만 수정
- 새 기능 요구와 visual polish는 `SHOWCASE_FOLLOWUPS.md`로 기록

---

# 5. 오늘 밤 시간 배분

시간은 시작 시점부터 종료 시점까지 남은 시간에 맞춰 자동 축소한다. 하나의 단위가 완료되면 즉시 다음으로 이동한다.

| 순서 | 작업 | 목표 시간 | 종료 조건 |
|---:|---|---:|---|
| 1 | Deploy 26 | 60–90분 | Pages 배포 |
| 2 | Deploy 27 | 45–75분 | Pages 배포 |
| 3 | Deploy 28 | 90–120분 | Pages 배포 |
| 4 | Deploy 29 | 90–120분 | Pages 배포 |
| 5 | Deploy 30 | 45–75분 | Pages 배포 또는 불필요 판정 |
| 6 | Deploy 31 | 60–90분 | demo loop 문서/차단 요소 수렴 |
| 7 | 버퍼 | 남은 시간 | CI/Pages failure와 P0 수정 |

## 시간 부족 시 컷 순서

```text
반드시: Deploy 26 → Deploy 28 → Deploy 31
시간이 있으면: Deploy 27 → Deploy 29
가장 마지막: Deploy 30
오늘 밤 제외: P2 전체
```

---

# 6. 배포 루프

각 Deploy는 아래를 반복한다.

```text
기존 route/store/entity/component 탐색: 최대 15분
→ 사용자 결과 한 문장 확인
→ production 파일 최대 4개 구현
→ flutter analyze
→ relevant flutter test
→ flutter build web
→ commit/PR/CI
→ Pages deploy
→ docs/agent-log 또는 PR 본문 기록
→ 즉시 다음 Deploy
```

## 고정 규칙

- 기존 route, entity ID, store/repository, `care_schedule`, ShootHub, external link helper, SORI 디자인 시스템을 먼저 재사용한다.
- 새 기능이 2시간을 넘기면 사용자 결과를 절반으로 쪼개 deploy한다.
- 테스트 실패는 원인을 고치고 진행한다. 테스트를 만들기 위한 대형 abstraction은 만들지 않는다.
- 실기기 검수는 매 배포의 stop gate가 아니다. 시사회 전 release candidate에서만 묶는다.
- PR 생성, CI, Pages 배포 뒤에는 사용자 응답을 기다리지 않고 다음 작업으로 진행한다.

---

# 7. 금지 목록

오늘 밤 아래 작업은 하지 않는다.

```text
custom scroll physics/position/pointer interception
new gesture systems
FlutterMap canvas or RegionMapExploreSheet redesign
camera viewfinder or B/A slider redesign
Timer calculation/_onTick changes
VisitSession consent/completion contract changes
external SNS automatic publishing
consent gate changes
new DB schema/migration
payment/refund/pricing changes
AppShell/FloatingPillNav redesign
legacy screen overhaul
new AI engine
multi-shop/team/franchise
```

---

# 8. 멈출 수 있는 경우

아래 네 경우만 최소 보고 후 승인을 기다린다.

```text
1. 되돌릴 수 없는 고객 데이터 삭제/대량 변환
2. 결제·환불·가격·구독 변경
3. 인증/권한/법적 동의 변경
4. secrets/credential/deployment workflow 실제 변경
```

그 외에는 기본 제품 원칙과 기존 코드로 결정하고 전진한다.

---

# 9. 오늘 밤 종료 보고

```md
# Overnight Delivery Report

## Deployed
| # | User result | PR | SHA | Pages | Analyze/Test/Build |

## Commercialization loop
- Today → customer:
- Record → B/A:
- B/A → chart:
- Chart → next care:
- Customer care:
- Content candidate:
- Our area:

## P0 blockers
- Resolved:
- Remaining:

## Deferred intentionally
- Only P1/P2 items not blocking the showcase or real-shop loop

## Next execution order
1.
2.
3.
```

---

# 10. Cursor Agent Final Command

```text
오늘 밤 SORI를 멈추지 말고 배포 단위로 완수한다.

현재 main에서 Deploy 26부터 시작한다.
우리 지역의 탐색 조건과 0건 회복을 배포한다.
그 다음 업체 정보 이해, 원장 오늘 후속 업무, 고객 차트 최신 변화,
콘텐츠 후보함 정리, 시사회 수렴 순서로 진행한다.

모든 작업은 기존 코드와 글로벌 표준을 재사용한다.
새 바퀴를 만들지 않는다.
한 PR은 하나의 사용자 결과만 만든다.
자동 검증하고 Pages에 배포한 뒤 즉시 다음 작업으로 이동한다.

시사회·실샵 루프를 막는 P0가 아니면 논쟁하지 말고 backlog로 보낸다.
오늘 → 고객 → 기록 → B/A → 차트 → 다음 케어 → 고객 안내,
그리고 기록 → 콘텐츠 후보와 우리 지역 발견까지
SORI의 큰 형태를 계속 배포하라.
```
