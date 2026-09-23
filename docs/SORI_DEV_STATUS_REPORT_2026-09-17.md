# SORI 개발 현황 · 데이터 상태 리포트

**대상:** 외부/동료 개발자 의견 수렴용  
**기준 시점:** 2026-09-17  
**배포 tip:** `origin/main` @ `c22ba3e`  
**웹:** https://white-miner.github.io/SORI/ (`--base-href /SORI/`)  
**저장소:** https://github.com/white-miner/SORI.git  
**작업 브랜치:** `nightly/design-reconstruction-2026-09-11` (= main과 동일 tip)

> 이 문서는 “있을 것” 추정이 아니라, 현재 `lib/` · `supabase/migrations` · 배포된 `main` 기준 사실만 적는다.  
> 런타임 계약 우선순위: `docs/CONTRACTS.md` > 초기 ER `docs/DATABASE_SCHEMA.md`.

---

## 1. 제품 한 줄

**sori**는 1인 샵(에스테틱·케어) **원장용** 고객관리 · 방문 기록 · 전후(B/A) 사진 · 커뮤니티 앱이다.  
철학: 모든 기록은 리뷰이며 소통으로 완성된다.  
로그인: **카카오 OAuth만** (웹 Site URL / 앱 `sori://login-callback`).

### 도메인 3축 (불변)

| 축 | 의미 | 구현 메모 |
|---|---|---|
| 상담차트 | 최초 상담·니즈·동의·목표 | `AdminChartWriterPage` 등. **Visit로 흡수하지 않음** |
| 고객차트 | 고객 1명의 영구 컨테이너 | `Customer` + 타임라인 |
| 방문(Visit) | 그날의 이용·사진·상태 | **물리 테이블 `visits` 없음.** Visit = `public.customer_charts` row |

---

## 2. 앱 셸 · 원장 홈 구조 (현재 UI)

### 하단 5탭 (StatefulShell)

| Index | Path | 원장 | 고객 |
|---:|---|---|---|
| 0 | `/app/home` | `VisitLauncherPage` | 통합 홈 피드 |
| 1 | `/app/customers` | 고객 허브 → 고객차트 | 케어 탭 |
| 2 | `/app/review` | 촬영 허브 | 리뷰 대시보드 |
| 3 | `/app/community` | 커뮤니티 피드 | 동일 |
| 4 | `/app/my` | 원장 마이(책상) | 고객 마이 |

### 원장 홈 스테이지 탭 (Desk / Chart / Programs / Flow)

`VisitLauncherPage` 내부 4단:

| 탭 | 라벨 | 역할 | 상태 |
|---|---|---|---|
| Desk | Desk | 퀵액션 · B/A 캐러셀 · 관리 케이스 | **LIVE** — 상단 플립시계·스케줄러·「지금 처리할 일」은 `86be793`에서 **제거됨** |
| Chart | Chart | `ChartWorkspacePage` — 서랍→파일→방문 3단 가로 레일 | **LIVE** (로컬 UI SSOT). 구 FileCabinetShell은 삭제됨 |
| Programs | Programs | 프로그램 견적·수기 입금 원장 | **PARTIAL** (외부 PG 없음) |
| Flow | Flow | 케어 타이머 Standby (플립시계·프리셋·고객 연결) | **LIVE** (타이머 SSOT) |

---

## 3. 메인 기능 현황 (개발자용 매트릭스)

범례: **LIVE** 운영 경로 · **PARTIAL** 화면/저장 있으나 외부연동·완성도 부족 · **STUB** UI/mock · **NOT BUILT** 경로 없음 · **WIP** 로컬만(미커밋/미적용)

| 영역 | 상태 | 핵심 진입 | 비고 / 막힘 |
|---|---|---|---|
| 카카오 로그인·온보딩 | LIVE | `/login` | 이메일/네이버/구글 진입 없음 |
| 고객 등록·검색·차트 | LIVE | `/app/customers`, `/chart/create` | 상담↔고객 통째 재설계 금지 |
| Visit 세션 기록 | LIVE | 촬영 허브 → `VisitSessionPage` | 저장 SSOT `saveChartAndConfirmVisitAsync` |
| Chart 워크스페이스(3레일) | LIVE | 홈 Chart 탭 | No.N 표시·디지트 팔레트·동의 아카이브 복원. DB 파일번호 Expand는 아래 WIP |
| B/A 스마트 가이드 카메라 | LIVE | `/app/review`, 허브/차트 | `c22ba3e`: **멀티샷 세션 + After 거치 + 타이머/마법봉 통합**. 대표 1장만 차트 URL 반영 (`session.primary`) |
| B/A 미연결 큐·바인드 | LIVE | Desk 캐러셀 / RPC | `ba_capture_sessions` + `bind_ba_session_to_chart` |
| B/A 비교 뷰어 | LIVE | 관리 케이스 / 비교 페이지 | PhotoSet 미도입. URL 쌍 기반 |
| 사진 Storage 삭제 | PARTIAL | staging discard | 차트 저장 후 URL 컬럼 삭제 UX 미완. Storage 객체 잔존 가능 |
| Consent · 커뮤니티 발행 | LIVE | Visit consent / 발행 레일 | 서명+마케팅 동의 게이트. 공개중단 ≠ 원본삭제 ≠ 홈숨김 |
| 케어 타이머 · TTS | LIVE | Flow 탭 / 풀스크린 | `VisitTimerStore` → `_onTick` → FlipClock. 병렬 시계 금지. 웹은 제스처 안 TTS prime |
| 프로그램 판매 OS | PARTIAL | Programs 탭 | 견적·쿠폰·멤버십·수기 입금(109–116). **실PG 없음** |
| 방문 종료 고객 리포트 | LIVE | `/care-report/:id` | 공유 링크 |
| 케어 일정 | PARTIAL | `care_schedule_entries` | Desk 스케줄 UI는 제거됨. 데이터·시트 헬퍼는 코드에 잔존 |
| 커뮤니티 피드 | LIVE | `/app/community` | 홈/커뮤니티 `FeedQueryConfig` 분리 (Boost는 커뮤니티) |
| 우리 지역 맵·상권 | LIVE / PARTIAL | 커뮤니티「우리 지역」 | flutter_map + 로컬 스냅샷/반경/카테고리. Edge `get-shop-market`. **국세청 연동 없음** |
| 세미나·체크아웃 | PARTIAL | `/seminar/:id` | UI+포인트/에스크로 카피. merchant-of-record 없음 |
| 경영 대시보드 | PARTIAL / STUB | `/app/biz-dashboard` | 헤드라인 LIVE. AI 리포트 MOCK |
| 알림톡 | STUB | 설정 알림함 | mock RPC. 비즈메시지 실채널 아님 |
| SNS 직접 게시 | PARTIAL | share/caption | Graph API 직접 게시 아님 |
| 고객 파일번호·방문일 Expand | WIP | migration `121` | **로컬 untracked.** remote DB 적용·앱 읽기 미연동 추정 |

---

## 4. 데이터 상태

### 4.1 런타임 핵심 모델

```
auth.users 1—1 profiles
profiles 1—0..1 shops (owner)
shops 1—* customers
customers 1—* customer_charts     ← Visit 기록(SSOT)
customer_charts ← visit_sessions.chart_draft_id   ← 운영 세션(페이즈)
ba_capture_sessions → bind RPC → customer_charts.before/after_image_url
Storage bucket chart_photos: {shopId}/{customerId}/{id}_{stamp}_{before|after}.webp
```

| 객체 | 물리 저장 | 앱 SSOT |
|---|---|---|
| Visit 기록 | `customer_charts` | `SoriStore.chartsForCustomer` / `saveChartAndConfirmVisitAsync` |
| 운영 세션 | `visit_sessions` | `VisitStore` / phase 머신 |
| B/A 사진(현재) | 차트 URL 컬럼 + Storage | `ChartPhotoStorage.uploadWebp` |
| B/A 사진(Expand) | `chart_photo_records` (117) | **읽기 이중화 미완료** |
| 회원권 잔여 | `customers` ticketing 컬럼 | 차트에 잔여를 두지 않음 |
| 프로그램 매출 | `program_quotes` + `program_quote_payments` | Payment ≠ CreditLedger |
| 케어 일정 | `care_schedule_entries` | 096+ |
| 홈 숨김 | `customer_charts.home_hidden_at` | 119 — 공개중단과 별축 |

### 4.2 마이그레이션 번호대

| 구간 | 내용 | 배포/적용 메모 |
|---|---|---|
| 001–108 | 코어·피드·Visit 세션·타이머·리포트·BA 세션 등 | **파일 수정 금지** (CONTRACTS) |
| 109–116 | 프로그램 판매 OS (견적·프로모·결제상태·쿠폰·멤버십·accept RPC) | 코드 경로 LIVE/PARTIAL |
| 117 | `chart_photo_records` Expand | PhotoSet 전 단계. 앱 이중 읽기 미완 |
| 118 | region content bookmarks | LIVE |
| 119 | `home_hidden_at` | LIVE |
| 120 | market strategy | 지역/상권 |
| **121** | `customers.customer_file_no`, `last_visit_number`, `customer_charts.visit_date` | **Expand SQL만 로컬 존재.** backfill·UNIQUE·앱 연동 **의도적으로 제외**. 원격 적용 여부 확인 필요 |

### 4.3 CONTRACTS상 절대 금지 (요약)

- `visits` / `photos` / `consultations` 테이블 신설
- `customer_charts` 컬럼 삭제·타입변경·`unique(customer_id, visit_number)` 제거
- `before_image_url` / `after_image_url` 제거
- `saveChartAndConfirmVisit*` · `chartsForCustomer` 시그니처 파괴
- 기존 마이그레이션 파일 수정 / force push

보호 플로우(깨지면 롤백): 차트 저장, 촬영 부착, 당일 차트 재사용, Visit 워크플로, 타임라인, 고객 케어, B/A 슬롯, BA 바인드, 인박스 연결, 저장 부수효과(visit_checked+회원권).

---

## 5. 최근 배포된 변경 (개발 재구성 축)

| 커밋 | 요약 |
|---|---|
| `c22ba3e` | 카메라 멀티샷 세션 · After 거치 · 타이머/자동촬영 통합 · 호출부 `.primary` |
| `86be793` | Desk 상단 플립시계·스케줄러·지금 처리할 일 제거 |
| `38c291d` | 고아 FileCabinetShell 삭제 |
| `c7a68e2`…`fb7b280` | Chart 3단 가로 레일 · No.N · paper 문법 · 디지트 팔레트 |
| `cd60e9f` 등 | 우리 지역 맵·상권 전략 일괄 |

기술 스택: Flutter (`sori`) · Supabase · GitHub Actions → Pages · Edge Functions(`ai-case-story`, clinical trends, shop weather/climate/market).

---

## 6. 개발자에게 묻고 싶은 의견 (체크리스트)

아래는 기획/현장 기준으로 열려 있는 판단 포인트다. **답변·우선순위·리스크**를 부탁한다.

### A. 데이터 모델

1. Visit = `customer_charts` row 모델을 **장기 유지**할지, PhotoSet·`visit_date`·파일번호 Expand 후 **Contract 단계 타임라인**을 어떻게 잡을지.
2. migration **121**을 호스티드 DB에 언제 Expand할지, backfill 전략(기존 `visit_number` / `custom_chart_no`와의 관계).
3. `chart_photo_records`(117) 읽기 이중화 vs URL 컬럼 단일 경로 — 다음 스프린트 범위.

### B. 카메라 · 미디어

4. 멀티샷 세션에서 **거치되지 않은 샷**의 보관 정책(세션 종료 시 discard vs Storage 영속 vs 갤러리 P1).
5. Staging discard 시 Storage 객체 삭제 API를 언제 넣을지(잔존 blob 리스크).

### C. 원장 홈 IA

6. Desk에서 스케줄/지금할일 제거 후, **일정 시작 CTA**의 정식 입구(고객 탭? Programs? 알림?)를 어디로 둘지.
7. Chart 3레일이 현장 작성 속도에 충분한지, 레거시 `AdminChartWriterPage`와의 역할 분리.

### D. 매출 · 외부 연동

8. 프로그램 수기 원장 → 실PG 도입 시점과 Payment/CreditLedger 경계 유지 방법.
9. 알림톡 mock → 플랫폼 공식 채널 실발송의 선행 조건.
10. 상권 Edge vs 클라 지오코딩 키 경로 정리(잠금 문서와 코드 불일치 여부).

### E. 품질 · 배포

11. 웹 우선(GitHub Pages)과 네이티브 앱 릴리스 게이트를 어떻게 나눌지.
12. 보호 플로우 10개 중 자동 E2E 커버리지가 약한 구간과 보강 우선순위.

---

## 7. 참고 문서 (저장소 내)

| 문서 | 용도 |
|---|---|
| `docs/CONTRACTS.md` | 보호 계약 SSOT |
| `docs/SORI_CURRENT_ARCHITECTURE_AND_CAPABILITY_INVENTORY.md` | 2026-09-12 기능 인벤토리(이후 Chart/카메라/Desk 변경은 본 리포트가 갱신) |
| `docs/SORI_AGENT_HANDOFF.md` | 타이머·배포·환경 운영 |
| `docs/AGENTS.md` / `.cursor/rules` | 에이전트 작업 프로토콜 |
| PRD v7.0–v7.9 시리즈 | 홈/프로그램/B/A/지역 등 기획 |

---

## 8. 회신 형식 제안

가능하면 아래 형식으로 회신해 주시면 다음 스프린트에 바로 반영한다.

```
우선순위 (Must / Should / Later): …
동의·반대·대안 (섹션 A–E 번호 인용): …
리스크 / 롤백 조건: …
다음 2주 제안 범위 (파일·마이그레이션 번호 포함): …
```

— 작성: SORI 기획·에이전트 작업 트리 기준 / tip `c22ba3e`
