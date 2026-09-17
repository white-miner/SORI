# SORI 현재 아키텍처 · 기능 인벤토리

**용도:** Perplexity 마스터 계획서 / 단계별 UI·UX 문서 작성 전 사실 기준선  
**기준 브랜치:** `origin/main` @ `9d207ea` (2026-09-12, PR #8 squash)  
**작성일:** 2026-09-12  
**범위:** 조사·문서화만. 본 파일 외 코드·CONTRACTS·테스트 기대값·Secret 값은 변경하지 않음.

> 기능을 “있을 것”으로 추정하지 않았다. 아래 LIVE/PARTIAL/STUB/NOT BUILT는 `lib/` · `supabase/migrations` · `test/` 에 존재하는 경로만 본다.  
> `docs/DATABASE_SCHEMA.md`는 초기 설계안이다. 런타임 계약은 `docs/CONTRACTS.md`가 우선한다.

---

## 0. 한 줄 제품 정의

sori는 **1인 샵(에스테틱·케어) 원장용** 고객관리 · 방문 기록 · 전후사진 · 커뮤니티 앱이다.  
철학: 모든 기록은 리뷰이며 소통으로 완성된다.  
운영 URL: `https://white-miner.github.io/SORI/` (`--base-href /SORI/`, 해시 라우팅 `/#/...`).

핵심 도메인 3축 (CONTRACTS + AGENTS):

1. **상담차트** — 최초 상담 · 니즈 · 동의 · 목표 (`AdminChartWriterPage` 등). Visit로 흡수하지 않는다.
2. **고객차트** — 고객 1명의 영구 컨테이너.
3. **방문(Visit)** — 그날의 이용·사진·상태기록. **물리 테이블은 `visits`가 아니라 `public.customer_charts`의 row**다. 별도 `consultations` / `photos` / `visits` 테이블은 없다.

---

## 1. 앱 셸과 화면 지도

### 1.1 라우터 SSOT

- 파일: `lib/routing/sori_router.dart`
- 생성: `createSoriGoRouter`
- 레거시 헬퍼: `lib/routing/app_router.dart` (실제 네비게이션은 go_router)
- 루트 키: `rootNavigatorKey`

가드: `SoriStore.authHydrating` 중 리다이렉트 보류. 온보딩 미완료면 `/app/*` → `/onboarding` 또는 `/login`.  
딥링크(`/review`, `/care-report`, `/care-request`, `/chart`, `/customer/.../profile`, `/seminar/...`)는 셸 밖.

레거시 `/app/cases` → `/app/community`. `/app`·`/admin` → `/app/home`.

### 1.2 StatefulShellRoute 탭 (index 0–4)

`AppShellPage` (`lib/views/app_shell_page.dart`)가 `StatefulNavigationShell`을 감싼다.

모바일(`width < 800`): `Scaffold(extendBody: true)` + `FloatingPillNav`.  
PC(`width >= 800`): 사이드바 Row, **pill nav 없음** (`SoriShellInsetScope.pillNavVisible: false`).

| Index | Path | 원장 (`activeMode == director`) | 고객 |
|---:|---|---|---|
| 0 | `/app/home` | `VisitLauncherPage` — 오늘/프로그램/타이머 | `UnifiedHomeFeedPage` `FeedSurface.home` |
| 1 | `/app/customers` | `DirectorCustomerHubPage` | `CustomerCareTab` |
| 1 nested | `/app/customers/:customerId` | `CustomerChartPage` (셸 **안**) | 동일 경로 |
| 2 | `/app/review` | `ShootHubPage` (촬영 허브) | `CustomerReviewDashboardPage` |
| 3 | `/app/community` | `UnifiedHomeFeedPage` `FeedSurface.community` | 동일 |
| 4 | `/app/my` | `MyPage` → `DirectorMyPageView` | `MyPage` → `CustomerMyPageView` |

`AppPaths.appShoot` 상수는 주석상 브랜치 2와 동일 의미이나, 실제 원장 촬영 탭 path는 `/app/review`다.

**FloatingPillNav 라벨** (`lib/widgets/floating_pill_nav.dart`):

| | 0 | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|
| 원장 | 홈 | 고객 | 촬영 | 커뮤니티 | 책상 |
| 고객 | 홈 | 케어 | 리뷰(또는 샵 리뷰 라벨) | 커뮤니티 | 마이 |

고객 홈·커뮤니티 탭은 피드 휠 마진 `FeedWheelMarginSurface`를 켠다.

### 1.3 rootNavigator push vs 셸 내부 push

SSOT 헬퍼: `lib/utils/sori_nav.dart` — `pushRootPage` / `pushRootRoute` = `Navigator.of(context, rootNavigator: true)`.

| 방식 | pill nav | 예시 |
|---|---|---|
| `StatefulShellRoute` 브랜치 `go` / `goBranch` | **유지** | 5탭, 고객 상세 `/app/customers/:id` |
| `Navigator.of(context).push` (root 아님) | **유지** | `ShootHubPage` → `VisitSessionPage`; `VisitLauncherPage`의 일부 시트/페이지 |
| `parentNavigatorKey: rootNavigatorKey` GoRoute | **사라짐** | 아래 1.4 루트 라우트 |
| `pushRootPage` / `rootNavigator: true` | **사라짐** | 설정, B/A 비교 페이지, 타이머 풀스크린, 리뷰 작성, 세미나 탭 상세 등 |

**함정:** Visit 세션은 촬영 허브에서 **셸 내부 push**라 하단 pill이 가린다. P0-2a inset이 그 전제다. 타이머 풀스크린은 root push라 pill이 없다.

### 1.4 주요 화면 파일 (실제 경로)

**셸 밖 (pill 없음)**

| Route | 파일 |
|---|---|
| `/` | `lib/views/splash_page.dart` |
| `/login` | `lib/views/entry_home_page.dart` (카카오 단일 로그인) |
| `/onboarding` | `lib/views/onboarding_page.dart` |
| `/review?token=` | `lib/views/customer_review_page.dart` |
| `/care-report/:chartId` | `lib/views/care_report_page.dart` |
| `/care-request/:shopId` | `lib/features/crm_today/care_schedule_lead_page.dart` |
| `/chart/create`, `/chart/:customerId` | `lib/views/admin_chart_writer_page.dart` |
| `/app/biz-dashboard` | `lib/views/biz_dashboard/biz_dashboard_page.dart` |
| `/customer/:id/profile` | `lib/views/customer_profile_page.dart` |
| `/seminar/:classId` | `lib/views/seminar_class_detail_page.dart` |

**셸 안**

| 화면 | 파일 |
|---|---|
| 원장 홈 | `lib/features/visit/visit_launcher_page.dart` |
| 고객 홈 피드 | `lib/views/unified_home_feed_page.dart` |
| 탐색 그리드 | `lib/views/home_explore_tab.dart` |
| 우리 지역 맵 | `lib/views/community/region_nearby_map_section.dart` |
| 원장 고객 허브 | `lib/views/director_customer_hub_page.dart` |
| 고객 차트 | `lib/views/customer_chart/customer_chart_page.dart` |
| 촬영 허브 | `lib/views/shoot_hub_page.dart` |
| Visit 세션 | `lib/features/visit/visit_session_page.dart` |
| 스마트 가이드 카메라 | `lib/views/smart_guide_camera_page.dart` |
| 원장 마이 | `lib/views/director_my_page_view.dart` |
| 고객 마이 | `lib/views/customer_my_page_view.dart` |
| 설정 | `lib/views/app_settings_page.dart` |
| 타이머 스테이지 | `lib/features/visit/widgets/home_timer_stage.dart` |
| 타이머 풀스크린 | `lib/features/operation/widgets/care_timer_fullscreen_page.dart` |
| B/A 비교 | `lib/views/before_after_compare_page.dart` · `before_after_compare_sheet.dart` |
| 프로그램 판매 | `lib/features/program/program_pane.dart` |

---

## 2. 도메인 모델과 데이터 소유권

런타임 Visit = **`customer_charts` row**. `visit_sessions`는 그날의 운영 세션(페이즈 머신)이며 `chart_draft_id → customer_charts(id)`다.

사진은 PhotoSet 신설이 CONTRACTS상 P1 예정이다. **현재 LIVE 경로는 `customer_charts.before_image_url` / `after_image_url` / `photo_meta` + Storage `chart_photos`.** `chart_photo_records`는 Expand만 (117).

Payment(현금 유입)와 선불권(CreditLedger)을 한 테이블로 합치면 안 된다. 고객차트 Payment 탭은 **차트 row 누적·회원권 잔여 표시**이지 PG 결제가 아니다.

| 객체 | Model | Store / service / repo | DB / local | 식별자 · 상태 전이 |
|---|---|---|---|---|
| SessionUser | `lib/models/session_user.dart` | `SoriStore.session`, `SoriAuthService`, `SoriAuthCoordinator` | `profiles` ↔ `auth.users`; 모드 `active_mode` | `id`=auth uuid; `role` director/customer/guest; `activeMode` 토글. 카카오만 로그인 |
| Shop | `lib/models/shop.dart` | `SoriStore.shop` | `shops` | `id`; owner `owner_user_id`; 주소·lat/lng; `naverPlaceUrl` 등. 공개 프로필/지도 중심 |
| Customer | `lib/models/customer.dart` | `SoriStore.customers`, `chartsForCustomer` | `customers` | `id`, `shop_id`, phone 정규화. 회원권 횟수 SSOT는 고객 row(차트에 잔여를 두지 않음) |
| VisitSession | `lib/visit_kernel/models/visit_session.dart`, `VisitStore` | `SoriStore.visit` | `visit_sessions` (097+) | `id`; `chart_draft_id`; phase `shoot→consult→plan→consent→publish→done` (+hold) |
| CustomerChart (Visit 기록) | `lib/models/customer_chart.dart`, `chart_db_columns.dart` | `SoriStore.saveChartAndConfirmVisitAsync`, `ensureTodayShootChart`, `chartsForCustomer` | `public.customer_charts` (앱 별칭 `chart_records`) | `id`; `unique(customer_id, visit_number)`; `visitChecked` 저장 시 true. 홈 숨김=`home_hidden_at` (caseShared 불변) |
| B/A photo | URL 필드 + `BaCaptureSession` `lib/models/ba_capture_session.dart` | `ChartPhotoStorage.uploadWebp`, `bindBaSessionToChart`, `discardBaSession` | Storage `chart_photos`; 테이블 `ba_capture_sessions`; Expand `chart_photo_records` | 경로 `{shopId}/{customerId}/{id}_{stamp}_{before\|after}.webp`. 세션: draft→linked→archived |
| Source / pair | `buildVisitPhotoSlots` in `before_after_compare_sheet.dart` | 비교 뷰어가 차트 리스트로 슬롯 구성 | 별도 photos 테이블 없음 | before/after URL 쌍. PhotoSet 미도입 |
| Consent / Publish | 차트 동의 필드 + `lib/utils/consent_publish_gate.dart` | `canPublishBa`; Visit Consent phase; `unpublishBaFromCommunity` | 차트 컬럼 `consent_*`, `signature_url`, `caseShared` | 게이트: 서명·마케팅 동의. 공개 중단=`caseShared=false`, **사진 URL 유지** |
| Payment | 고객차트 `_PaymentTab`; 프로그램 `program_quote_payments`; 세미나 체크아웃 UI | 수기 원장 / Echo 포인트 RPC. **외부 PG 발명 금지** | `program_quotes`+`program_quote_payments` (113). 회원권=`customers` ticketing | 프로그램: unpaid/partial/paid/refunded. 세미나 UI는 card/kakaoPay 타일+에스크로 카피 |
| Timer | `VisitTimerStore` `lib/features/operation/visit_timer_store.dart` | 입구 `startCare`/`jumpToStep`/`resumeCare` → `_ensureTicking` → `Timer.periodic` **`_onTick()`** | 로컬+`visit_sessions` 연동 컬럼(103/106). 병렬 시계 금지 | 구간 잔여. 오버타임은 카운트업. TTS `CareTimerTtsService` |
| Seminar | `seminar_class.dart`, `seminar_enrollment.dart`, `seminar_application.dart` | `SoriStore` + `SeminarClassDetailPage` | `seminar_classes` 등 (042+) | classId 라우트. 신청·체크아웃 시트. 정산은 `sori_cash_balance` / 인사이트 리뷰 후 에스크로 카피 |
| Community post | `community_post.dart`, `unified_feed_item.dart` | `refreshUnifiedCommunityFeed`, `UnifiedFeedEngine` | `community_posts` (049, whisper 065) | `FeedQueryConfig`로 홈/커뮤니티 슬라이스. Boost는 커뮤니티만 |
| Public-data / 상권 | `lib/services/shop_market_service.dart` | Edge `get-shop-market` | 서버 시크릿 SBIZ/MOIS/Kakao REST. 클라 키 번들 금지(잠금) | `resolve_address` → 행정동; ZONE 3 벤치마크. **국세청 홈택스 연동 코드 없음** |
| Nearby / region map | `region_nearby_map_section.dart`, `region_map_tile_candidates.dart` | flutter_map; 샵 lat/lng; 지역 피드 필터 | 타일: MapTiler Pastel(`MAPTILER_API_KEY`) 또는 OSM 폴백 | 커뮤니티「우리 지역」탭. 홈 surface는 지역 탭 숨김 |

Repository 이원화: `SoriRepository` ← `MemorySoriRepository` | `SupabaseSoriRepository`. UI 파사드 `SoriStore`.

---

## 3. 현재 가능한 사용자 기능

범례: **LIVE** 운영 경로로 동작 · **PARTIAL** 화면/저장은 있으나 외부 연동·삭제·정산이 불완전 · **STUB** UI·mock·카피만 · **NOT BUILT** 코드 경로 없음.

### 로그인/온보딩 — LIVE (카카오만)

- Entry: `/login` → `EntryHomePage`; `/onboarding` → `OnboardingPage`
- 파일: `sori_auth_service.dart` `signInWithOAuth(OAuthProvider.kakao)`
- 행동: 카카오 → Site URL 또는 `sori://login-callback` → 온보딩 후 `/app/home`
- 막힘: 이메일 매직링크/네이버·구글 로그인은 enum만 있고 진입은 카카오 단일

### 고객 등록·검색·고객 차트 — LIVE

- Entry: `/app/customers`, `/app/customers/:id`, `/chart/create`
- 파일: `director_customer_hub_page.dart`, `customer_chart_page.dart`, `admin_chart_writer_page.dart`
- 행동: 검색·등록·타임라인·본기록 FAB. 저장은 `saveChartAndConfirmVisitAsync`
- 막힘: 상담차트↔고객차트 통째 재설계 금지. 병합 위저드는 별도 (`customer_merge_*`)

### 방문 상담·Visit 차트 — LIVE (R1 위계)

- Entry: 촬영 허브 진행 중 카드 / 런처에서 `VisitSessionPage` (셸 내부 push)
- 파일: `visit_session_page.dart`, `visit_store.dart`
- 행동: 10초 요약+기록완료 펼침; 이야기/관찰/다음관리는 접힘; 완료 후 고객상세 primary · 다음일정(있을 때만) · **자동 홈 금지**
- 막힘: 사진 없이도 `visitChecked && hasSummary`면 완료. SOAP 4칸 기본 펼침 아님

### 메뉴/코스 제안 — PARTIAL

- Entry: 원장 홈「프로그램」탭 `program_pane.dart`
- 행동: 견적·수기 입금 원장(`program_quote_payments`). 미수 배지
- 막힘: 외부 PG 없음. 「오늘 받을 돈」과 「받은 돈」분리(PRD v7.2). 방문 차트와 Payment 테이블 미통합이 계약

### B/A 촬영·동일 포즈·비교·갤러리 — LIVE / PARTIAL

- Entry: `/app/review`(원장 촬영), `SmartGuideCameraPage`, 비교 페이지
- 파일: `shoot_hub_page.dart`, `smart_guide_camera_page.dart`, `before_after_compare_page.dart`, `ba_capture_session.dart`
- 행동: 가이드 카메라 WebP 업로드; 동일 포즈 고스트; 미연결 큐 `ba_capture_sessions`; 차트 바인드 RPC `bind_ba_session_to_chart`
- 막힘: PhotoSet 미도입. 갤러리 워크스페이스 PRD v7.5는 허브·캐러셀 수준. `chart_photo_records` 읽기 이중화 미완료(Expand)

### 사진 삭제 — PARTIAL / STUB (단계별)

| 단계 | 상태 | 실제 행동 |
|---|---|---|
| Staging (`BaCaptureSession` draft / 로컬 인박스) | PARTIAL | `discardBaSession`이 세션 row·로컬 큐 제거. **`ChartPhotoStorage`에 delete API 없음** → Storage 객체 잔존 가능 |
| 차트 저장 후 (URL이 `customer_charts`에 붙음) | STUB / NOT BUILT | URL 컬럼을 비우는 전용 삭제 UX·RPC를 이 조사에서 확인하지 못함. 컬럼 삭제 자체는 계약상 영구 금지 |
| 공개 후 (`caseShared`) | PARTIAL | `unpublishBaFromCommunity`: 커뮤니티 공개만 중단, **차트·사진 URL 유지**. 원본 파기 아님 |

### Timer·추가 시간 — LIVE (오버타임) / PARTIAL (추가 분 버튼)

- Entry: 원장 홈 타이머 탭, 풀스크린
- 파일: `visit_timer_store.dart`, `home_timer_stage.dart`, `flip` 표시
- 행동: 구간 잔여 카운트다운, 오버타임 카운트업, `jumpToStep`, TTS. 웹은 제스처 안 `primeFromUserGesture`
- 막힘: 원장이 N분을 **추가 구매/입력**하는 별도 상품 플로우는 없음. `_onTick` 산식·병렬 시계 변경 금지. R5 chrome 보류

### Consent·Publish — LIVE

- Entry: Visit Consent phase; 발행 레일; 샵 포스트 허브
- 파일: `consent_publish_gate.dart`, Visit consent pad, `shop_posts_hub_sheet.dart`
- 행동: 서명·마케팅 동의 없으면 발행 차단. 공개 중단은 커뮤니티만
- 막힘: 동의 자동 체크 금지. 홈 숨기기(`home_hidden_at`)와 공개 중단은 **다른 축**

### 고객 보고·다음 관리·재방문 — LIVE

- Entry: `/care-report/:chartId`, Visit 완료 시트, 케어 일정 리드 `/care-request/:shopId`
- 파일: `care_report_page.dart`, `visit_end_pipeline.dart`, `care_schedule_lead_page.dart`
- 행동: 방문 리포트 생성·공유 링크; 다음 일정 패널; 재방문 트랙
- 막힘: 알림톡 실발송은 mock RPC (아래)

### 홈·커뮤니티·우리 지역 — LIVE

- Entry: `/app/home`(고객), `/app/community`
- 파일: `unified_home_feed_page.dart`, `home_explore_tab.dart`, `feed_query_config.dart`
- 행동: 홈=glance+추천≤3, Boost·탐색·지역 탭 숨김. 커뮤니티=추천 PTR, 탐색 PTR, 우리 지역(맵, **PTR 없음**)
- 막힘: 하단 iOS식 bounce는 웹에서 강제하지 않음(PR #7 revert). 맵 pan과 피드 스크롤 충돌로 지역 탭 PTR 없음

### 세미나·참여·결제·정산 — PARTIAL

- Entry: `/seminar/:classId`, 마이 세미나 탭, `SeminarCheckoutBottomSheet`
- 행동: 상세·신청·체크아웃 UI(card/kakaoPay 타일), 수강 후 인사이트 태그→에스크로 카피, 원장 cash 잔액
- 막힘: **merchant-of-record / 실PG 연동 코드 없음.** 정산 출금은 포인트 지갑 UI+RPC 수준

### 경영 탭·공공데이터·국세청 매출 — PARTIAL / STUB / NOT BUILT

- Entry: `/app/biz-dashboard` (root, pill 없음), 책상 경영 Peek
- 파일: `biz_dashboard_page.dart`, `shop_market_service.dart`, `ai_shop_report_page.dart`
- 행동: 시간당 수익 등 샵 데이터 헤드라인; Edge `get-shop-market`으로 상가·행정동 인구
- 막힘: AI 리포트는 **MOCK**. **국세청/홈택스 매출 연동 없음.** 클라에 Kakao REST를 넣는 `shop_geocoding_service`는 잠금(Edge secret only)과 충돌 가능 → 마스터 계획에서 경로 정리 필요

### 콘텐츠/SNS export — PARTIAL

- 파일: `instagram_quick_post.dart`, `sori_share.dart`, `case_kakao_share_button.dart`
- 행동: 캡션 복사, `share_plus`로 이미지/링크 공유, 리뷰 QR 링크
- 막힘: 인스타 Graph API 직접 게시 아님. 네이버 플레이스 URL은 샵 필드·외부 브라우저

### 알림·마케팅 메시지 — PARTIAL / STUB

- Entry: 설정 → 알림함 → `MessageHistoryPage` (`lib/views/message_history_page.dart`)
- 파일: `kakao_alimtalk_actions.dart`, `send_kakao_alimtalk_mock` RPC, `SoriPlatformAlimtalk` 템플릿 코드 상수
- 행동: 인앱 알림 목록, 리뷰 요청 이벤트, **mock 알림톡 insert**
- 막힘: 카카오 비즈메시지 실채널 발송 아님. 개별 샵 채널 금지(플랫폼 공식 채널 구조만)

---

## 4. 보호 계약

출처: `docs/CONTRACTS.md`, `docs/PRD_v7.9_PERFECT_DEV_LOCK.md`, 런타임 코드.  
`DATABASE_SCHEMA.md`는 초기 ER이며 `visits` 테이블을 만들지 말라는 CONTRACTS와 충돌하므로 **설계 참고만**.

| 계약 | 이유 | 변경 가능 조건 | 관련 파일/테스트 |
|---|---|---|---|
| Visit = `customer_charts` row. `visits`/`photos`/`consultations` 신설 금지 | 운영 스키마가 이미 이 모델 | Expand만 (nullable 컬럼). 별도 visits 테이블은 승인된 다단계 마이그레이션+PO | CONTRACTS §1; `097_visit_sessions.sql`은 **세션**이지 Visit 기록 대체 아님 |
| `customer_charts` 컬럼 삭제·타입변경·NOT NULL 추가 금지. `unique(customer_id, visit_number)` 유지 | 매일 쓰는 저장 경로 | Expand 후 2주+ Contract만 | `customer_chart.dart`, `chart_db_columns.dart` |
| `before_image_url` / `after_image_url` 영구 유지 | 파생 캐시로 강등 예정이어도 컬럼 제거 금지 | PhotoSet 이중 기록 안정화 후 Contract | `ChartPhotoStorage`; migration 117 Expand |
| `saveChartAndConfirmVisit` / `saveChartAndConfirmVisitAsync` 이름·시그니처 | 저장=확정 진입점 | 내부 분리만 허용 | `sori_store.dart`, `supabase_sori_repository.dart`; `test/contracts_p0_characterization_test.dart` |
| `visitChecked` (+ `visitCheckedAt`) 저장 부수효과 | 현재 저장=확정+회원권 차감 한 트랜잭션 | 자동 visitChecked 금지(R1). 분리하려면 특성화 테스트 먼저 | CONTRACTS 플로우 10; P0 테스트 #1+#10 |
| `chartsForCustomer` 반환 `List<CustomerChart>` · visitNumber 내림차순 | UI 읽기 SSOT | 타입 변경 금지 | `sori_store.dart` |
| `ensureTodayShootChart` 당일 재사용 | 같은 row | P3까지 현행 | CONTRACTS 플로우 3 |
| Consent/Publish `canPublishBa` | SNS 공개는 서명+마케팅 동의 | 게이트 우회·자동 동의 금지 | `consent_publish_gate.dart`, `test/consent_publish_gate_test.dart` |
| B/A 공개 중단 ≠ 원본 파기 ≠ 홈 숨기기 | 커뮤니티 내리기 / 홈 숨김 / 파일 삭제 축 분리 | `unpublishBaFromCommunity`는 URL 유지; `home_hidden_at`만 홈 제외 | `test/ba_unpublish_phase_b_test.dart`, `test/home_case_hide_test.dart`, `119_customer_charts_home_hidden_at.sql` |
| `bind_ba_session_to_chart` RPC 시그니처 | 미연결 큐 연결 | 시그니처 변경 금지 | `108_ba_capture_sessions.sql` |
| Payment 발명 금지 / Payment≠CreditLedger | 매출 vs 부채 | 수기 원장·Echo는 별 축. 외부 PG는 PO+계약 신청 | `113_program_payment_state.sql`; 고객차트 `_PaymentTab` |
| Timer SSOT `_onTick` / FlipClock 잔여 / 병렬 시계 금지 | 현장 타이머 신뢰 | chrome-only는 R5 보류. 산식 변경 금지 | `visit_timer_store.dart`, `test/visit_timer_sync_v52_test.dart`, `test/flip_clock_split_flap_test.dart` |
| `customer_charts` CASCADE 자식 | 차트 삭제 시 리뷰·북마크·photo_records 등 종속 | 차트 물리 삭제 UX 자체를 함부로 열지 말 것 | 001 reviews; 083 bookmarks; 117 photo_records; 037 tier 등 `ON DELETE CASCADE` |
| Secrets / API keys 커밋·로그 금지 | 유출 | GitHub Secrets + dart-define. `.env` gitignore | `env.dart`, `.env.example`, `deploy.yml` |
| MapTiler 키 클라 하드코딩 금지 | CORS·과금 | Secret `MAPTILER_API_KEY` 없으면 OSM 폴백 | `deploy.yml`, `region_map_tile_candidates.dart` |
| Kakao OAuth만 | 로그인 단일화 | Site URL / `sori://login-callback` | `entry_home_page.dart`, `sori_auth_service.dart` |
| Kakao REST·SBIZ·MOIS는 Edge secret | 번들 금지 (잠금 문서) | 클라 `dotenv['KAKAO_REST_API_KEY']` 지오코딩은 잠금과 불일치 → 계획에서 정리 | `get-shop-market/index.ts`, `shop_geocoding_service.dart` |
| Naver | 플레이스/예약 URL·공유. Maps SDK 아님 | 네이버 로그인 없음 | `Shop.naverPlaceUrl` |
| 기존 라우트 삭제·경로 변경 금지 | 딥링크 | 추가만 | `sori_router.dart` `/chart/create`, `/app/customers/:id` |
| 마이그레이션 001–108 파일 수정 금지 | 이력 | 새 번호 추가만 (109+) | `supabase/migrations/` |
| 글로벌 `SoriScrollBehavior` / `main.dart` / `web/index.html` overscroll | 셸·맵·타이머 부작용 | 피드 로컬 physics만 예외 (P0-3a) | `app_scroll_behavior.dart` |
| R2 홈 vs 커뮤니티 | 홈에 Boost/작성 강조 금지 | `FeedQueryConfig` | `test/feed_query_config_test.dart`, `test/feed_r23_home_chrome_test.dart` |
| filled primary CTA 1 / glass=floating | DESIGN LAWS | 새 surface부터 `brand` | `SORI_DESIGN_LAWS.md` |

보호 플로우 6+4 (깨지면 롤백): 차트 저장, 촬영 부착, 당일 차트 재사용, Visit 워크플로, 타임라인 순서, 고객 케어 내역, B/A 슬롯, BA 바인드, 인박스 연결, 저장 부수효과.

---

## 5. UI 시스템

### 5.1 토큰 (`lib/theme/sori_tokens.dart`)

| 심볼 | 값 | 의미 |
|---|---|---|
| `background` | `#F4F6F9` | 캔버스 |
| `primary` | `#18181B` charcoal | **레거시 CTA.** 전면 purple 치환 금지 |
| `brand` | `#6D4A77` | DESIGN LAWS purple — 새 primary 행동 |
| `onBrand` | white | |
| `semanticBlue` | `#2563EB` | 위치·지도 |
| `semanticGreen` | `#15803D` | 완료·성공 (`success`는 아직 `primary` 별칭) |
| `semanticYellow` | `#CA8A04` | 확인 필요 |
| `semanticCoral` | `#D96462` | 세미나 marker |
| `destructive` / `systemRed` | `#FF3B30` | 삭제·오류 |
| `cameraYellow` | `#FFD60A` | 뷰파인더 전용 |

`success` 필드는 charcoal `primary`와 같다. 성공 의미색은 `semanticGreen`을 써야 한다.

### 5.2 로고 SSOT

- 벡터: `assets/images/logo_sori.svg`
- 코드: `SoriBrandAssets.logoSoriSvg`, 위젯 `SoriLogo`
- ColorFilter/틴트 금지. 테스트: `test/sori_logo_svg_test.dart`, `test/sori_brand_assets_test.dart`

### 5.3 Design laws / glass

- `docs/SORI_DESIGN_LAWS.md` — 화면당 목적 1, CTA 1, 색=언어, glass=떠 있는 도구만
- `docs/SORI_GLASS_PERFORMANCE.md` — BackdropFilter 화면당 1–3, sigma 8–12, 리스트 row blur 금지
- 구현: `lib/widgets/glass/sori_glass_overlay.dart`, `sori_glass_tokens.dart`, `sori_glass_app_bar_cluster.dart`, `sori_glass_chip.dart`, `sori_glass_fab.dart`, `sori_glass_icon_button.dart`, `sori_glass_action_dock.dart`

### 5.4 공용 컴포넌트 (일부)

`SoriPressable`, `SoriLogo`, `FloatingPillNav`, `SoriScrollBehavior`, 포스트 `sori_post_medium`/`mini`, `ExploreRichInfoCard`, Visit glass widgets (`visit_kernel/widgets`), `CategoryPresentationMap`

### 5.5 하단 scroll inset SSOT

파일: `lib/utils/sori_shell_insets.dart` (`scrollBottomInset`).

- Occupancy 공식(scope 밖): `64 + 12 + viewPadding.bottom + 20`
- AppShell body 안: Scaffold가 `viewPadding.bottom`을 0으로 만들면 **nav 위젯 높이(`padding.bottom`) + 20** (PR #8)
- 키보드 `viewInsets` 더하지 않음
- PC occupancy 0

**적용 (P0-1/2a):** Timer 스페이서, Visit phase list, Consent/Hold 고정 CTA, 피드 추천/지역 리스트 패딩, 탐색 browse, ShootHub list.

**미적용·하드코드 잔여 (main 코드 기준):** 원장 마이 일부 `140`/`120`/`110`, 고객 마이 `120`, 일부 시트 `kSoriFloatingNavClearance`. 맵 캔버스는 inset 대상 아님(보호).

피드 physics: 전역 Always+Clamping. 피드만 `soriFeedScrollPhysics` = Bouncing+Always (PTR용). custom ScrollPosition 없음.

### 5.6 Accessibility / semantics

전용 `*_semantics_test.dart` **없음**. 위젯 단위 `Semantics(`는 카메라, 맵, 로고 로그인, 프리셋, 글래스 칩, 프로필 CTA 힌트 등에 산재. `test/profile_showcase_test.dart`가 hint 존재만 검사. WCAG 스위트는 없음. 골든 AA 허용은 별도 CI 관용(히스토리).

---

## 6. 테스트·배포

### 6.1 테스트 구조

- 명령: `flutter test` (CI 전체) + 골든 두 파일 재실행
- 특성화 SSOT: `test/contracts_p0_characterization_test.dart` (플로우 1–7·저장 부수효과)
- 셸 inset: `sori_shell_scroll_reachability_test.dart`, `sori_shell_scroll_rollout_p02a_test.dart`, `sori_feed_reachability_p03b_test.dart`
- 피드 PTR: `sori_feed_bounce_refresh_p03a_test.dart`
- Visit/Timer: `visit_session_r11_chrome_test.dart`, `visit_timer_*`, `care_timer_*`
- 동의/공개: `consent_publish_gate_test.dart`, `ba_unpublish_phase_b_test.dart`, `phase2_publish_rail_test.dart`
- 골든: `home_dashboard_v54_golden_test.dart`, `my_feed_v70_golden_test.dart`

npm 스크립트는 이 Flutter 레포의 검증 기준이 아니다.

### 6.2 GitHub Actions

| Workflow | 트리거 | 하는 일 |
|---|---|---|
| `.github/workflows/test.yml` | `push`/`pull_request` → `main` | `flutter test` + golden 2개 |
| `.github/workflows/deploy.yml` | **`push` to `main` only** | web release `--base-href /SORI/` → Pages artifact → `deploy-pages` |

PR은 테스트만. 프리뷰 Pages 없음. **main 직접 기능 푸시 금지** — PR squash 머지가 배포 조건.

### 6.3 Production

- URL: `https://white-miner.github.io/SORI/`
- `SITE_URL` dart-define 동일
- 캐시 버스트: `SORI_BUILD_ID` → run number

### 6.4 환경변수 · Secret **이름만**

클라/CI: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `OPENAI_API_KEY`, `SITE_URL`, `MAPTILER_API_KEY`, `SORI_ASSET_V`(빌드)

Edge (코드 주석): `SBIZ_STORE_SERVICE_KEY`, `MOIS_POP_SERVICE_KEY`, `KAKAO_REST_API_KEY`

값은 기록하지 않음.

### 6.5 브랜치 · PR (조사 시점)

- `main` = `9d207ea` (PR #8 merged, Pages 배포 성공)
- **open PR: 없음** (`gh pr list --state open`)
- 원격에 남은 토픽 브랜치 (머지 여부와 별개로 존재): `nightly/design-reconstruction-2026-09-11`, `feat/ui-customer-chart`, `cursor/one-click-banner-progress-e536`, 완료된 P0 `fix/p0-*` / `revert/p0-3b-custom-pointer-bounce`, `feature/github-pages-deploy`
- 로컬 워크스페이스 `nightly/...`는 main과 **다른 dirty 트리**. 마스터 계획은 **main**을 기준. nightly 전용 문서는 §7 주석

---

## 7. 문서 충돌 지도

`origin/main`의 `docs/`만 A/B/C. 워크스페이스에만 있는 파일은 맨 아래.

### A — 계약·현재 방향 (마스터 계획 전 필수)

| 문서 | 왜 |
|---|---|
| `docs/CONTRACTS.md` | 스키마·시그니처·10 플로우 |
| `docs/PRD_v7.9_PERFECT_DEV_LOCK.md` | R1–R6 PO Yes, 홈/커뮤니티, Whisper, Timer chrome 보류 |
| `docs/SORI_DESIGN_LAWS.md` | UI 헌법 |
| `docs/SORI_GLASS_PERFORMANCE.md` | glass/GPU |
| `docs/SORI_DESIGN_RECONSTRUCTION_INVENTORY.md` | 화면 재구성 체크포인트 (완료/미완 표시) |
| `docs/PRD_v7.9_UI_UX_BRIEF.md` | v7.9 UX 브리프 |
| `AGENTS.md` / `.cursor/rules/00-core-guardrails.mdc` | 에이전트 작업 프로토콜 (레포 루트) |

### B — 기능 PRD (해당 도메인 쓸 때)

| 문서 | 주제 |
|---|---|
| `PRD_v6.0_VISIT_END_CUSTOMER_REPORT.md` | 방문 종료 리포트 |
| `PRD_v7.0_MY_FEED_HOME_ARCHITECTURE.md` | 마이 피드/홈 |
| `PRD_v7.1_PROGRAM_SALES_OS.md` / `PRD_v7.2_PROGRAM_SALES_FUNNEL_AUDIT.md` | 프로그램·수기 결제 |
| `PRD_v7.4_BA_COMPARE_VIEWER.md` / `PRD_v7.5_BA_GALLERY_WORKSPACE.md` | B/A |
| `PRD_v7.6_PUBLIC_DATA_DIRECTOR_INSIGHT.md` | 공공데이터 경영 |
| `PRD_v7.7_NEARBY_SHOP_EXPLORER.md` | 근처 샵 |
| `PRD_v7.8_COMMUNITY_IA.md` | 커뮤니티 IA |
| `PRD_v7.9_HOME_CASE_HIDE.md` | 홈 케이스 숨김 |
| `PRD_v7.9_MY_PAGE_MASTER.md` / `PRD_v7.9_MY_PAGE_REDESIGN_BRIEF.md` | 마이/책상 |
| `PRD_v7.9_REGION_MAP_UPGRADE.md` + `CS1_BASEMAP` + `CS1_COMPARE_LOG` | 지역 지도 타일 |
| `PRD_v7.9_BUGFIX_TRIAGE_PERPLEXITY.md` | 버그 트리아지 |
| `UI-SPEC-CUSTOMER-CHART.md` | 고객차트 UI |
| `prd_sponsorship_gift_economy.md` / `prd_special_supporter_vip.md` / `prd_ecosystem_three_stakeholders_masterplan.md` | 후원·VIP·이해관계자 |
| `prd_ai_tool_split_micro_phase1.md` | AI 툴 과금 |

### C — 과거·참고 (현재와 충돌 가능 — 인용 시 CONTRACTS로 검증)

| 문서 | 주의 |
|---|---|
| `DATABASE_SCHEMA.md` | 초기 users/charts 명명. **visits 테이블 설계 문장 있음 → 구현하지 말 것** |
| `PRD_v5.2_TIME_MANAGEMENT_UI.md` `v5.3` `v5.4` | 홈/타이머 구버전. Timer SSOT는 핸드오프가 우선 |
| `HOTFIX_home_blank_screen.md` | 일회 핫픽스 |
| `PRD_v7.9_PERFECT_DEV_MATERIALS_REQUEST.md` / `PERPLEXITY_*` | 요청·연구 원문. LOCK이 흡수본 |

**main에 없음 (nightly/워크스페이스 전용 — 마스터 계획 기본 소스에서 제외하거나 ‘미머지’로 표기):**  
`SORI_AGENT_HANDOFF.md`, `CURSOR-PROMPTS.md`, `MIGRATION-PLAN.md`, `P5B-SPEC-AMOUNT.md`, `PRD_v7.3_HOME_CLOCK_AND_TOOL_TAB.md`

---

## 8. Master Plan 작성 전 제품 질문 (최대 10)

코드만으로 닫히지 않는 결정. 예/아니오 또는 선택지.

1. **B/A staging 삭제**  
   `discardBaSession`이 지워야 할 범위는?  
   (A) 세션 row·로컬 큐만 (현재) (B) 함께 Storage 객체 영구 삭제 (C) 30일 후 배치 파기만

2. **차트 저장 이후 전/후 사진 삭제**  
   원장이 방문 기록의 사진을 지울 수 있게 할 것인가?  
   (A) 금지 — URL 컬럼은 비우지 않음 (B) URL만 null, 파일은 남김 (C) URL+Storage 삭제, Visit 기록은 유지

3. **공개 이후 원본**  
   커뮤니티 공개 중단(`unpublish`) 다음에 원본 파기가 필요한가?  
   (A) 불필요 — URL 유지가 계약 (B) 고객 요청 시에만 파기 워크플로 (C) 공개 중단 시 자동 파기

4. **세미나 결제 merchant-of-record**  
   (A) SORI 에스크로가 가맹점 (B) 원장 개별 PG (C) 수기 확인만 — 실PG 없음 (현재 UI에 가깝)

5. **공공데이터 「매출」의 출처**  
   경영 탭 매출/상권 숫자의 정본은?  
   (A) SBIZ 상가+행정동 인구 추정만 (현재 Edge) (B) 원장 수기 (C) 국세청/홈택스 API (코드 없음 — 새로 계약 필요)

6. **공공데이터 갱신 주기·집계 단위**  
   (A) 조회 시 실시간 Edge (B) 일 1회 샵 캐시 (C) 월 배치. 단위는 행정동 / 반경 m / 업종 중 무엇을 잠글지

7. **고객 앱의 공개 사례 열람 범위**  
   (A) 팔로우·후원 샵만 (B) 우리 지역 반경 (C) 전국 커뮤니티 추천 (현재 커뮤니티 피드는 C에 가깝고 홈은 가벼운 추천)

8. **VisitSession과 pill nav**  
   (A) 현재처럼 셸 내부 push — pill 유지+inset (B) root push — 풀스크린 Visit, pill 숨김

9. **Timer 「추가 시간」**  
   (A) 오버타임 카운트업만 (현재) (B) 원장이 +N분 버튼을 누름 (산식 변경은 Timer 계약 신청 필요)

10. **알림톡**  
    (A) mock RPC+인앱 알림함 유지 (B) 카카오 비즈메시지 공식 채널 실발송 (템플릿 승인·사업자 필요)

---

## 부록. 조사 방법

- `git fetch origin main`; HEAD `9d207ea`
- `lib/routing/sori_router.dart`, `app_shell_page.dart`, `CONTRACTS.md`, `PRD_v7.9_PERFECT_DEV_LOCK.md`, migrations 097/108/113/117/119, `deploy.yml`/`test.yml`, `gh pr list`
- 값을 출력·복사한 Secret 없음
)
