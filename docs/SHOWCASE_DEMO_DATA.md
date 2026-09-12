# 시사회 데모 데이터 — 대표 고객 6상태

`origin/main` `b4fe645` 이후 운영 루프 CTA 기준.
새 테이블·SQL 리셋 스크립트·Timer/Map/AppShell 변경 없이,
**기존 고객·차트·`care_schedule`·카메라 경로만** 써서 상태를 만든다.

비밀값(`.env`, anon key)은 이 문서에 적지 않는다.

## 대표 고객

| 환경 | 대표 고객 | ID | 비고 |
|---|---|---|---|
| 로컬 메모리 시드 | 김민지 | `1` | `MemorySoriRepository.createSeedSnapshot` 첫 고객. 전화 `010-1234-5678` |
| GitHub Pages / 실샵 | 샵에서 미리 고른 **한 명** | `customer_charts.customer_id` | 이름·전화를 시사회 전에 종이에 적는다 |

Pages는 원격 Supabase다. 로컬 시드는 Pages에 올라가지 않는다.
실샵은 아래 **리셋 체크리스트**를 대표 고객 한 명에게 적용한다.

## 6상태 (3쌍)

한 고객이 동시에 6개를 가질 필요는 없다. **시사회 직전에 필요한 쌍만** 맞춘다.

| 상태 | 판정 (코드 SSOT) | 로컬 시드 김민지 기본값 | 맞추는 기존 경로 |
|---|---|---|---|
| 일정 있음 | `CareScheduleReadDensity.todayScheduledSorted`에 이 고객 | 없음 (`care_schedule` 시드 빈 목록) | 차트 `다음 케어 일정 잡기` → 날짜=오늘, 시각=14:00 |
| 일정 없음 | 오늘 `scheduled` 0건 | **기본** | 오늘 일정을 만들지 않거나, 기존 일정을 시사회 고객이 아닌 사람에게 둔다 |
| B/A 가능 | 해당 방문 `hasBeforeImage && hasAfterImage` | **있음** (`chart-1` 1회차 재생케어) | 사진 탭 그 회차 행 탭 → `openBeforeAfterComparePage` |
| After 없음 | `needsAfterPhoto` (Before만) | 시드에 없음 | 아래 After-없음 준비 |
| next care 있음 | `nextUpcomingForCustomer` ≠ null (오늘 0시 이후 `scheduled`) | 없음 | 차트 `다음 케어 일정 잡기` 또는 방문 완료 `다음 케어 일정 잡기` |
| next care 없음 | 위 헬퍼가 null | **기본** | 미래 `scheduled`를 만들지 않는다 |

오늘 일정을 잡으면 그 건이 next care이기도 하다. `일정 있음`과 `next care 있음`을 동시에 켜는 준비는 **오늘 14:00 일정 1건**이면 충분하다.

## After 없음 준비 (기존 카메라만)

1. 원장 `/app/customers/:id` 차트 → FAB `새 방문 기록` (간편 차트 아님).
2. 저장해 방문 row를 만든다.
3. 사진 탭에서 그 회차 `결과 촬영` / Before만 찍고 After는 비운다.
4. 시사회 본편에서 그 행의 `After 촬영`을 쓴다.

이미 Before/After가 있는 회차는 비교용으로 남겨 둔다. 지우지 않는다.

## 시사회 직전 리셋 (실샵 · Pages)

대표 고객 한 명에 대해:

1. **로그인:** 카카오 원장. 웹은 Site URL, 앱은 `sori://login-callback`. 해시 라우트: `https://white-miner.github.io/SORI/#/login`
2. **next care 없음이 필요하면:** 그 고객의 오늘 이후 `scheduled`를 만들지 않는다. (스키마 삭제 금지. 다른 날로 옮기거나 시사회 고객을 바꿔도 된다.)
3. **next care / 오늘 일정이 필요하면:** 차트 outlined `다음 케어 일정 잡기` (`customer-chart-schedule-next`) → 오늘 + 14:00, 라벨은 최근 케어명 또는 `다음 관리`.
4. **B/A:** 사진 탭에 Before+After 회차가 보이는지 확인.
5. **After 없음:** 위 카메라 준비로 Before-only 회차 1건.
6. **고객 Care 탭:** GNB `고객 화면으로 보기`는 **세션 전화번호와 같은 고객**만 연다. 대표 고객 전화 ≠ 원장 카카오 전화이면 고객 계정으로 따로 로그인한다. 원장 차트에서 다른 고객 Care를 열어 내부 note를 보여 주지 않는다.

## 금지

- 새 DB 테이블/컬럼, 마이그레이션 수정
- Payment · Consent · Timer 계산 · Map · AppShell 변경으로 “데모 데이터” 만들기
- 고객 Care에 `care_schedule.note` · 전화 노출
- 로컬 시드 김민지(id `1`) 이름·ID 변경 (기존 테스트 기준점)
