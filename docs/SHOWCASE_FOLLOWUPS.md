# 시사회 후속 작업 (오늘 밤 제외)

시사회 5분 루프와 실샵 당일 사용을 막지 않는 항목만 적는다.
본편 동선은 `docs/SHOWCASE_DEMO_SCRIPT.md`, 데이터 준비는 `docs/SHOWCASE_DEMO_DATA.md`.

## 오늘 밤 고의로 미룬 것

| 항목 | 이유 | 다음 작업 |
|---|---|---|
| Deploy 30 콘텐츠 후보함 정렬 | 상태 라벨·empty는 이미 있음. 시사회 본편에 후보함은 없음 | queued/ready를 생성일 기준으로 정렬 |
| 후보함 copy/share 패키징 | SNS 발행·AI 카피 금지 | 제목/요약 확인만, 별도 PR |
| After 없음 촬영 맥락 안내 | 카메라 플로우 변경 금지 | 기존 CTA 카피만 |
| 우리 지역 상권 점수/공공 매출 | P2 · 신규 데이터 파이프라인 | 보류 |
| 원장 운영 지능 dashboard | P2 · 새 priority 엔진 금지 | 오늘 홈 미완료 큐(Deploy 28)로 충분 |
| 시각 polish / 레거시 화면 정리 | 루프를 막지 않음 | 시사회 후 |

## 확인만 하고 코드로 안 연 것

- 로그인·Pages·customer/visit context·차트 사진 탭·next care CTA는 기존 route가 살아 있음
- 오늘 홈 미완료 기록 큐(`home-today-followup-queue`)는 본편 5분에 필수가 아님
- 차트 헤더 `customer-chart-latest-change`는 본편 보조 시선

## 넣지 말 것

새 DB, Timer 산식, FlutterMap/RegionMapExploreSheet, AppShell, 결제, 자동 SNS, AI 카피.
