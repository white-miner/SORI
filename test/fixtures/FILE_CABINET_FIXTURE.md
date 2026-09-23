# 파일 위계 UI fixture

테스트 전용. `test/fixtures/` 에만 있다. production `lib/`, live DB, Storage, seed SQL 과 무관하다.

시계: `kFileCabinetSeoulToday` = 2026-09-14 (서울 달력일).

## 모델

`FixtureShop` → `FixtureDrawer[]` → `FixtureCustomer[]` → `FixtureConsent[]` + `FixtureVisitChart[]`

- Consent id ≠ VisitChart id. 동의 추가가 `visit_number` 를 늘리지 않는다.
- Today = `visitDate == Seoul today` 인 방문의 표시 라벨. 별 record 아님.
- 서랍은 No 구간만. VIP/성별/시술로 나누지 않는다.

## 서랍

| 서랍 | No |
|---|---|
| A | 1–100 |
| B | 101–200 |
| C | 201–300 |
| (없음) | 301–400. No301 고객 row 없음. `simulateCreateCustomer(301)` → `drawerNotFound` |

## 고객

| No | 이름 | 전화 | 서랍 | 동의 | 방문 | Today |
|---|---|---|---|---|---|---|
| 1 | 픽스처 신규 | 010-0001-0001 | A | 0 | v1 오늘 | v1 |
| 25 | 픽스처 이력 | 010-0001-0025 | A | 3 (400일 / 200일 / 10일) | v1–v4 | v4 |
| 98 | 픽스처 만료 | 010-0001-0098 | A | 1 (400일, 만료) | v1 과거 | 없음 |
| 100 | 픽스처 에이끝 | 010-0001-0100 | A 끝 | 0 | 0 | 없음 |
| 101 | 픽스처 비시작 | 010-0001-0101 | B 시작 | 0 | v1 오늘 | v1 |
| 147 | 픽스처 장문 | 010-0001-0147 | B | 1 유효 | v1–v12, 날짜 전부 다름, v6 B/A | **v12 = Today** |
| 199 | 픽스처 사진 | 010-0001-0199 | B | 1 촬영 유효 | v1 Before만, v2 B/A | **없음** |
| 200 | 픽스처 비끝 | 010-0001-0200 | B 끝 | 0 | 0 | 없음 |
| 201 | 픽스처 씨시작 | 010-0001-0201 | C 시작 | 0 | v1 오늘-14일 | **없음** |

만료 공식: `signedAt + 365일 < Seoul today`. No25의 200일 전 동의는 이 공식상 **아직 유효**다. 최신(10일)도 유효. 만료는 400일 전 1건.

## 사진

`kFixturePngBefore` / `After` / `Signature` 는 테스트용 1×1 PNG data URL. 라이브 PDF·서명·Storage URL 없음.

## Consent-1

`CustomerConsentArchive` 는 레거시 `CustomerChart.signature_url`/`consent_pdf_url` 을 읽는다. 이 fixture 를 `CustomerChartPage` runtime 으로 쓰지 않는다.
