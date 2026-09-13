# SORI 10시간 연속개발 에이전트 자료패키지

> **저장 위치:** `docs/SORI_10H_CONTINUOUS_DELIVERY_PLAYBOOK.md`  
> **독자:** Cursor Agent 및 SORI 저장소에서 연속 개발을 수행하는 모든 에이전트  
> **목적:** 에이전트가 매 작업마다 사용자에게 같은 질문을 반복하지 않고, 이 문서만으로 제품 철학·우선순위·작업 선택 기준·배포 루프를 찾아 연속적으로 개발하고 배포하게 한다.

---

# 0. Read This First

SORI 개발의 목적은 화면을 예쁘게 꾸미거나 기능 목록을 늘리는 것이 아니다.

> **SORI는 뷰티숍의 상담, 고객 기록, 시술, 전후 촬영, 다음 케어, 재방문, 운영 판단을 하나의 일상 흐름으로 연결하는 운영 OS다.**

SORI는 일반적인 마케팅/예약/CRM 도구가 아니라, 원장과 고객이 매일 의지하는 운영 기반을 만든다.

## 이 문서를 쓰는 법

에이전트는 새 작업을 시작할 때 아래 순서만 따른다.

```text
1. §1 제품 판단 원칙 읽기
2. §4 현재 상용화 루프에서 끊긴 곳 하나 찾기
3. §5 우선순위 알고리즘으로 작업 하나 선택
4. §6 배포 루프로 구현 → 자동 검증 → 배포
5. §7 완료 보고 형식으로 기록
6. 즉시 다음 작업으로 이동
```

**문서 해석에 10분 이상 쓰지 않는다.** 20분 안에 코드 diff가 나오지 않으면, 범위를 절반으로 줄이고 기존 코드 재사용 경로를 택한다.

---

# 1. 제품 판단 원칙

## 1.1 글로벌 표준을 기본값으로 쓴다

사용자는 SORI의 사용법을 새로 배워서는 안 된다.

- iOS, Android, Flutter, browser의 기본 동작을 우선 사용한다.
- Instagram, Facebook, Weverse 등 최상위 제품에서 익숙해진 정보 소비·탐색·전환 패턴을 따른다.
- 커스텀 동작은 표준으로 해결할 수 없고, 실제 뷰티 운영 문제를 명확히 줄일 때만 만든다.
- 새 제스처, 가짜 애니메이션, 독자적인 물리 효과를 “특별함”을 위해 만들지 않는다.

### 즉시 결정 표

| 상황 | 기본 결정 |
|---|---|
| 일반 세로 목록 scroll | Flutter ambient/platform-default behavior |
| 짧은 refresh 목록 | 기존 RefreshIndicator + 필요한 화면의 AlwaysScrollablePhysics |
| 정보가 너무 많음 | 지금 행동에 필요한 정보만 첫 화면에 노출 |
| 다음 행동이 여러 개 | 가장 시간 민감하고 운영 손실이 큰 행동을 1순위 CTA |
| 빈 상태 | 사용자가 즉시 할 수 있는 첫 행동을 한 문장 + 버튼으로 제시 |
| 오류 | 무엇이 실패했는지 짧게 알리고 재시도 경로 제공 |
| 로딩 | 기존 화면 맥락을 유지하며 짧고 명확하게 feedback 제공 |
| 화면 표현 | 기존 SORI glassmorphism을 유지하되 가독성·대비·터치 영역 우선 |
| UX 세부 불명확 | Instagram/Facebook/Weverse의 보편적 최신 패턴 |

## 1.2 조각상 방식으로 만든다

```text
큰 사용자 흐름을 먼저 작동시킨다.
→ 자동 검증한다.
→ 배포한다.
→ 다음 큰 단절을 연결한다.
→ 세부 묘사는 상용화 루프가 돌아간 뒤에 한다.
```

하지 말 것:

- 한 화면의 spacing, bounce, animation, shadow만 수 시간 논의
- 완벽한 아키텍처를 기다리며 사용자 흐름을 미루기
- 현재 라우트에 연결되지 않은 레거시 화면을 선제적으로 재작성
- 추측성 abstraction이나 미래 가능성만을 위한 provider/repository 재설계

## 1.3 사용자 결과가 없는 작업은 뒤로 보낸다

모든 PR은 아래 문장으로 시작해야 한다.

> “이 변경 뒤에 원장/고객은 이전보다 **무엇을 더 빨리 끝낼 수 있는가?**”

답이 한 문장으로 나오지 않으면 PR을 만들지 않는다.

---

# 2. SORI 도메인 모델

## 2.1 SORI가 해결하는 실제 하루

### 원장

```text
오늘 해야 할 일을 본다
→ 고객을 선택한다
→ 상담/방문/시술을 기록한다
→ 전후 변화와 결과를 남긴다
→ 고객의 다음 케어를 정한다
→ 기록이 고객 관계, 콘텐츠, 재방문, 운영 판단으로 축적된다
```

### 고객

```text
내 변화와 최근 관리를 본다
→ 필요한 다음 케어를 이해한다
→ 원장과 신뢰를 쌓는다
→ 재방문/문의/추천 같은 다음 행동으로 이동한다
```

## 2.2 SORI의 핵심 자산

| 자산 | SORI에서의 의미 |
|---|---|
| 고객 차트 | 고객의 변화, 방문, 시술, 상담, 케어 이력을 신뢰 가능한 맥락으로 보존 |
| 상담 정보 | 메뉴/코스 제안과 시술 판단을 위한 대화 기반 기록 |
| 방문·시술 기록 | 원장의 실제 업무가 데이터로 남는 핵심 단위 |
| B/A 사진 및 세션 | 변화의 증거, 고객 신뢰, 콘텐츠의 원천 |
| 다음 케어 | 기록을 재방문·관계·매출로 연결하는 행동 |
| 고객 반응 | 서비스 품질·추천·운영 결정을 위한 근거 |
| 지역 인사이트 | 인근 시장과 기회를 빠르게 판단하는 도구 |

## 2.3 공개 정보와 내부 운영 정보 분리

| 고객에게 보여도 되는 것 | 원장/운영자 내부에만 있어야 하는 것 |
|---|---|
| 서비스 요약, 전후 결과, 홈 케어, 다음 케어 안내 | 내부 운영 메모, 감사 로그, 민감 인사이트, 관리 판단 근거 |
| 고객 본인의 차트·방문 맥락 | 다른 고객 데이터, 내부 분석, staff 운영 정보 |

고객 화면에 내부 메모를 섞지 않는다. 원장 화면에서 고객의 공개 콘텐츠처럼 보이는 정보를 혼동시키지 않는다.

---

# 3. 상용화 정의

상용화는 기능 100% 완료가 아니다.

> **원장이 실제 하루를 SORI에서 시작하고, 고객 한 명을 상담·기록·시술·촬영·후속 케어까지 관리했을 때 기존보다 덜 잊고, 덜 헤매고, 더 빨리 판단할 수 있는 상태다.**

## 최소 상용화 루프

```text
원장 홈 오늘
→ 고객 선택
→ 상담/방문/시술 기록
→ 표준 전후 촬영 또는 결과 기록
→ 고객 차트 반영
→ 다음 케어/재방문 행동
→ 운영 판단에 쓸 데이터 축적
```

이 루프의 한 연결을 복구하는 작업은 높은 우선순위다.

---

# 4. 현재 작업 지도

에이전트는 코드를 먼저 읽고, 아래 지도에서 **현재 라우트로 실제 접근 가능한 화면**만 대상으로 삼는다.

| 영역 | 주 사용자 | 핵심 질문 | 다음 화면/결과 |
|---|---|---|---|
| 원장 홈 · 오늘 | 원장 | 지금 누구에게 무엇을 해야 하는가? | 고객, 방문, 타이머, 촬영, 기록 |
| 고객/CRM 목록 | 원장 | 어떤 고객을 관리해야 하는가? | 고객 차트/상세 |
| 고객 차트 | 원장/고객 | 이 고객에게 어떤 일이 있었고 다음은 무엇인가? | 방문, B/A, 다음 케어 |
| Visit/시술 흐름 | 원장 | 상담과 시술을 어떻게 정확히 남기는가? | 결과 기록, 촬영, 차트 |
| ShootHub/B-A | 원장/고객 | 변화의 증거를 어떻게 남기고 보여주는가? | 고객 차트, 공유/콘텐츠, 케어 |
| 고객 홈 | 고객 | 내 변화와 지금 필요한 행동은 무엇인가? | 차트, 케어, 문의/예약 |
| 커뮤니티/탐색 | 원장/고객 | 무엇을 발견하고 신뢰할 수 있는가? | 프로필, 콘텐츠, 관계 |
| 우리 지역 | 원장 | 주변 시장과 기회는 무엇인가? | 업체/인사이트/행동 |
| 마이/설정 | 원장/고객 | 내 계정과 운영 환경은 정상인가? | 설정/관리 |

## 큰 흐름에 연결되지 않는 작업의 처리

- 현재 라우트에서 도달할 수 없는 레거시 화면: 보류
- 기능은 있으나 CTA/route만 끊긴 상태: 높은 우선순위
- 데이터는 있으나 고객/원장 화면에 안 보임: 높은 우선순위
- 새 데이터 모델이 필요한 대형 기능: 다음 스프린트 후보

---

# 5. 작업 선택 알고리즘

## 5.1 작업 후보를 3개만 만든다

코드 탐색 후 후보를 최대 3개 적는다.

```text
후보 A: 원장 오늘에서 다음 고객 CTA가 실제 방문 흐름으로 안 이어짐
후보 B: B/A 결과가 고객 차트에 안 보임
후보 C: 고객 차트의 빈 상태가 다음 케어 행동을 제시하지 않음
```

## 5.2 점수화

```text
우선순위 =
(매일 사용 빈도 × 운영 손실 감소 × 기존 코드/데이터 재사용 가능성)
÷ (수정 파일 수 × 불확실성)
```

### 높은 점수 작업

- 현재 화면과 기존 데이터가 이미 존재함
- CTA 또는 route 하나가 끊겨 사용자가 다음으로 못 감
- 원장/고객이 매일 만나는 화면임
- 최대 4개 production 파일에서 해결 가능함
- DB schema, 결제, consent 변경 없이 해결 가능함

### 낮은 점수 작업

- 새로운 제품 영역 전체를 만들려 함
- 레거시 또는 라우트 미연결 화면만 관련됨
- 커스텀 animation/physics/design effect 중심임
- 5개 이상의 production 파일이나 대규모 모델 변경이 필요함

## 5.3 선택 규칙

```text
가장 점수가 높은 하나를 즉시 구현한다.
2시간 안에 끝나지 않으면 사용자 결과를 반으로 자른다.
작동하는 절반을 먼저 배포한다.
```

---

# 6. 연속 개발·배포 루프

## 6.1 단일 작업 사이클

```text
[0–10분]  현재 코드·route·store 확인
[10–20분] 사용자 결과 한 문장 확정, 수정 파일 최대 4개 선택
[20–90분] 구현
[90–110분] analyze/test/build 및 실패 수정
[110–120분] PR 생성, CI, preview/staging 배포 요청 또는 실행
[즉시] 다음 작업 후보 선택
```

조사와 설계는 20분을 넘기지 않는다. 설계가 더 필요해 보이면 **기존 구조를 재사용하는 더 작은 결과**를 고른다.

## 6.2 PR 규칙

### 하나의 PR = 하나의 사용자 결과

좋은 제목:

```text
fix(scroll): restore platform default physics
feat(today): open next visit from priority card
fix(chart): show latest BA session in customer timeline
feat(care): surface next care action after visit
```

나쁜 제목:

```text
refactor: cleanup
fix: ui
feat: improvements
```

### 크기

- production 파일: 원칙상 최대 4개
- tests/docs: 필요한 만큼
- 4개를 넘으면 기능을 자른다.
- 제품 구조 전체를 바꾸지 않는다.

## 6.3 자동 검증

모든 작업에서 가능한 범위로 수행한다.

```bash
flutter analyze
flutter test <relevant tests>
flutter build web   # 또는 현재 배포 target build
```

기존 테스트가 없으면, 변경한 사용자 결과를 보호하는 가장 작은 test를 추가한다. 테스트를 만들기 위해 큰 추상화를 추가하지 않는다.

## 6.4 배포 규칙

```text
자동 검증 통과
→ PR 생성
→ CI 통과
→ preview/staging 배포
→ 다음 작업
```

- preview/staging deploy는 개발 루프의 일부다.
- 작은 UI/flow 변경마다 수동 실기기 검수를 강제하지 않는다.
- 여러 사용자 흐름이 묶인 release 후보에서만 실제 기기 점검을 한다.
- 배포 실패 시 배포 설정을 재설계하지 말고, 로그가 지목한 최소 원인만 고친다.

---

# 7. 기술 가드레일

## 7.1 반드시 재사용할 것

- 기존 route와 navigation
- 기존 entity ID와 route arguments
- 기존 store/repository/provider
- 기존 `RefreshIndicator`와 실제 refresh callback
- 기존 `ScrollController`가 기능상 필요한 경우 그 controller
- 기존 `SoriShellInsets`와 bottom navigation safe-area/inset 계약
- 기존 SORI glassmorphism 디자인 토큰과 컴포넌트

## 7.2 만들지 말 것

```text
custom ScrollPosition
custom ScrollPhysics
pointer event reinjection
가짜 Transform bounce
새로운 global state layer
새 database schema
새 payment/auth/consent flow
현재 사용하지 않는 화면의 대규모 refactor
AppShell 구조 개편
```

## 7.3 Scroll 표준 복귀 작업

일반 세로 목록은 플랫폼 기본 behavior를 사용한다.

- `SoriScrollBehavior`는 dragDevices 지원을 유지할 수 있다.
- 전 플랫폼 `ClampingScrollPhysics` 강제는 제거한다.
- PR #10의 custom feed bounce stack이 존재한다면 제거한다.
- 화면마다 iOS bounce를 Android에 강제하지 않는다.
- top refresh는 기존 refresh 가능한 화면에서만 유지한다.
- bottom edge는 network refresh를 실행하지 않는다.

이 작업은 **한 PR로 끝낸다.** 이후 스크롤을 별도 제품 과제로 확대하지 않는다.

## 7.4 손대지 않는 특수 표면

아래는 일반 목록 standardization 범위 밖이다.

```text
camera viewfinder
B/A compare slider
FlutterMap canvas
RegionMapExploreSheet map drag
Timer fullscreen
VisitSession 단계형 입력
Consent/Publish
modal and bottom sheet
horizontal carousel / TabBarView / PageView
NestedScrollView outer
```

---

# 8. 핵심 흐름별 구현 플레이북

## 8.1 원장 홈 ‘오늘’

### 성공 상태

원장이 앱을 열고 5초 안에 아래를 안다.

```text
오늘 가장 먼저 처리할 고객/방문은 무엇인가?
지금 진행 중인 업무는 무엇인가?
한 번 탭하면 어디서 그 일을 끝낼 수 있는가?
```

### 높은 가치 작업 예시

- 다음 방문 카드의 고객/visit detail 진입 연결
- 우선순위 카드에 명확한 CTA 추가
- 진행 중인 세션/미완료 기록의 재개 CTA
- 빈 오늘 화면에서 첫 고객/방문/기록 시작 행동 제시

### 피할 것

- Timer 계산 규칙 변경
- 타이머/FlipClock을 미학적 이유로 재작성
- ‘오늘’ 안에 모든 정보를 한꺼번에 넣기

## 8.2 고객 차트

### 성공 상태

원장/고객이 이 고객의 다음을 이해한다.

```text
최근 어떤 관리가 있었는가?
변화의 증거는 무엇인가?
다음에 해야 할 케어는 무엇인가?
```

### 높은 가치 작업 예시

- 최신 visit/session을 차트 타임라인에서 열기
- B/A 세션을 고객 차트에 연결
- 최근 기록이 없을 때 첫 기록/방문 CTA
- 다음 케어의 명확한 정보/행동 노출

### 피할 것

- 차트 전체 디자인 재작성
- 원장 내부 노트를 고객 화면에 노출
- 새 분석/추천 엔진부터 만들기

## 8.3 방문·시술·상담

### 성공 상태

```text
고객을 선택한다
→ 필요한 내용을 빠르게 기록한다
→ 시술/방문 결과를 저장한다
→ 다음 단계(촬영, 차트, 케어)가 보인다
```

### 높은 가치 작업 예시

- 저장 후 다음 행동 CTA
- visit ID/customer ID가 다음 화면에 끊기지 않도록 route 연결
- 이미 존재하는 기록을 다시 열어 이어서 작성

### 피할 것

- 데이터 모델 전면 재설계
- Consent/서명 규칙 변경
- 시술 흐름에 장식성 화면 추가

## 8.4 B/A 촬영과 기록

### 성공 상태

```text
촬영한다
→ 결과가 고객과 방문 맥락에 저장된다
→ 고객 차트에서 확인된다
→ 필요한 경우 고객 관계/콘텐츠의 재료가 된다
```

### 높은 가치 작업 예시

- 촬영 완료 후 고객 차트/방문으로 돌아가는 CTA
- 최근 B/A 결과를 차트에서 노출
- 촬영 결과가 고립될 때 기존 entity 연결 복구

### 피할 것

- camera control 재발명
- full-screen compare gesture 변경
- 촬영 데이터를 새 포맷으로 대량 변환

## 8.5 다음 케어·재방문

### 성공 상태

기록이 끝난 뒤 데이터가 사라지지 않고 다음 행동을 만든다.

```text
최근 관리
→ 현재 상태/변화
→ 다음 케어 제안 또는 원장 후속 조치
→ 재방문/문의/예약/관계
```

### 높은 가치 작업 예시

- 기존 care schedule을 오늘/고객 차트에 표면화
- 기록 완료 뒤 next-care CTA
- 빈 상태에 첫 케어 계획 행동 추가

### 피할 것

- ML 추천 엔진 선구축
- 가격/결제 정책 변경
- 고객에게 내부 점수/감사 정보를 노출

---

# 9. 멈춤이 필요한 단 네 범주

에이전트는 아래가 아니면 멈추지 않는다.

| 범주 | 예시 | 보고 방식 |
|---|---|---|
| 되돌릴 수 없는 데이터 변경 | 삭제, 대량 변환, destructive SQL | 영향·대상·복구 여부 3줄 |
| 돈 | 결제, 환불, 구독, 가격 | 변경 결과·영향·선택지 2개 |
| 권한/법적 동의 | auth role, consent wording | 바뀌는 사용자 권리·선택지 2개 |
| 비밀/배포 기반 | secrets, credentials, workflow | 필요한 접근/변경 한 줄 |

이 외에는 global standard와 기존 코드로 판단해서 진행한다.

---

# 10. 작업 로그와 핸드오프

## 10.1 매 PR 로그

PR 본문 또는 `docs/agent-log/`에 아래만 남긴다.

```md
## User result
- 원장/고객이 이제 할 수 있는 일:

## Scope
- Production files:
- Reused routes/stores/data:

## Validation
- flutter analyze:
- Tests:
- Build:
- Deploy:

## Next
- 다음 가장 높은 점수 작업:
```

## 10.2 10시간 종료 보고

```md
# 10-hour Continuous Delivery Report

## Deployed
| # | User result | PR | SHA | Environment | Validation |

## Commercialization loop advanced
- Today:
- Customer chart:
- Visit/treatment:
- B/A:
- Next care:

## Deferred intentionally
- Only items that do not block the commercialization loop

## Next 10-hour Top 3
1.
2.
3.
```

금지 문구:

```text
거의 완료
나중에 확인
복잡해서 조사 필요
실기기 검수 전 전체 보류
```

대신 사실만 쓴다.

```text
PR created / not created
CI passed / failed
Deployed / not deployed
Blocked by approval / not blocked
```

---

# 11. 에이전트 최종 명령

```text
SORI를 설명하지 말고 전진시켜라.

이미 있는 글로벌 표준을 사용하라.
기존 코드와 데이터를 재사용하라.
한 번에 하나의 사용자 결과만 완성하라.
작게 구현하고 자동 검증하라.
배포하고 다음 조각으로 즉시 이동하라.

원장과 고객이 실제로 일을 끝내는 최소 상용화 루프를
10시간 동안 계속 더 짧고, 더 분명하고, 더 연결되게 만들어라.

스크롤, 그림자, animation, 추측성 abstraction에 갇히지 마라.
오늘 → 고객 → 기록 → 촬영 → 차트 → 다음 케어라는 길을 계속 전진시켜라.
```
