# CONTRACTS.md — 보호 대상 계약 (실제 런타임 기준)

에이전트가 **승인 없이 절대 변경할 수 없는** 것들. 실제 조사 결과를 반영한 확정본이다.

> **전제 정정:** sori의 Visit은 `visits` 테이블이 아니라 **`public.customer_charts`의 row**다.
> 별도 `consultations` / `photos` / `visits` 테이블은 존재하지 않으며, 신설하지 않는다.
> `docs/MIGRATION-PLAN.md`를 반드시 함께 읽을 것.

---

## 1. DB 스키마 계약

| 테이블 | 보호 대상 | 상태 |
|---|---|---|
| `public.customer_charts` | `id`, `customer_id`, `visit_number`, `before_image_url`, `after_image_url`, `photo_meta`, `unique(customer_id, visit_number)` | 🔒 **수정·삭제·이름변경 전면 금지** |
| `public.visit_sessions` | `id`, `chart_draft_id → customer_charts(id)` | 🔒 FK 방향 변경 금지 |
| `public.ba_capture_sessions` | `bind_ba_session_to_chart` RPC 시그니처 | 🔒 고정 |
| Storage 버킷 `chart_photos` | 경로 규칙 `{shopId}/{customerId}/{id}_{stamp}_{before\|after}.webp` | 🔒 고정 |
| `public.chart_photo_records` | — | 🆕 P1에서 신설 |
| `public.photo_sets` | — | 🆕 P1에서 신설 |
| `customer_charts.visit_session_id` | — | 🆕 P3에서 nullable 추가 |
| `customer_charts.note_*` (SOAP 4) | — | 🆕 P5에서 nullable 추가 |

### 마이그레이션 규칙
- 기존 마이그레이션 `001` ~ `108` 파일은 **읽기 전용**. 절대 수정하지 않는다.
- 신규는 `109` 이후 번호로 **추가만** 한다.
- `alter ... drop column`, `alter ... alter type`, `drop constraint` 는 승인 없이 금지.
- 신규 컬럼은 전부 nullable + 기본값.

---

## 2. Dart 코드 계약

### 시그니처 고정 (변경·삭제 금지, 추가만 허용)

| 심볼 | 파일 | 비고 |
|---|---|---|
| `CustomerChart` (필드 전체) | `lib/models/customer_chart.dart` | 필드 제거·리네임 금지. 추가만 |
| `chart_db_columns.dart` 의 키 맵 | 동일 | 앱 이름 `chart_records` ↔ 물리 `customer_charts` 매핑 유지 |
| `SoriStore.chartsForCustomer` | `lib/services/sori_store.dart` | **UI 읽기 SSOT.** 반환 타입·정렬 순서 고정 |
| `SoriStore.ensureTodayShootChart` | 동일 | 삭제 금지. 내부 위임은 허용 |
| `SoriStore.saveChartAndConfirmVisitAsync` | 동일 | 이름·시그니처 고정. 내부 분리는 허용 |
| `SupabaseSoriRepository.saveChartAndConfirmVisit` | `lib/data/supabase_sori_repository.dart` | 동일 |
| `updateCustomerChartFields` | 동일 | 부분 패치 경로. 필드 화이트리스트 축소 금지 |
| `buildVisitPhotoSlots(List<CustomerChart>)` | `lib/views/before_after_compare_sheet.dart` | **인자 타입 고정.** 내부 소스 변경만 허용 |
| `VisitSession.chartDraftId` | `lib/visit_kernel/models/visit_session.dart` | 필드 유지. `visitSessionId` 역방향 추가는 허용 |
| `ChartPhotoStorage.uploadWebp` | `lib/services/chart_photo_storage.dart` | 반환 URL 계약 고정 |

### 라우트 고정

| 경로 | 대상 |
|---|---|
| `/chart/create` | `AdminChartWriterPage` |
| `/app/customers/:id` | `AdminChartPage` |

`lib/routing/sori_router.dart`의 기존 경로는 변경·삭제 금지. 추가만 허용.

---

## 3. 보호 플로우 (E2E / 특성화 테스트로 고정)

| # | 플로우 | 진입 → 출구 | 상태 |
|---|---|---|---|
| 1 | 원장 차트 작성 저장 | `AdminChartWriterPage` → `saveChartAndConfirmVisitAsync` → `chartsForCustomer` 렌더 | 🔒 |
| 2 | 촬영 → 사진 부착 | `shoot_hub_page` → `ChartPhotoStorage` → 차트 URL 컬럼 | 🔒 |
| 3 | 당일 차트 재사용 | `ensureTodayShootChart` 2회 호출 → **같은 row** | 🔒 P3까지 현행 유지 |
| 4 | Visit 워크플로 | `startVisitSession` → `chartForVisitSession` → 동의·리포트 패치 | 🔒 |
| 5 | 고객차트 타임라인 | `AdminChartPage` / `ChartManagementPage` — `visitNumber` 순서 | 🔒 |
| 6 | 고객 모드 케어 내역 | `CustomerCareTab` / `CareHistoryDetailPage` | 🔒 |
| 7 | B/A 비교 | `buildVisitPhotoSlots` → 슬롯 매핑 | 🔒 |
| 8 | BA 세션 바인드 | `bind_ba_session_to_chart` RPC → URL coalesce | 🔒 |
| 9 | 미연결 큐 연결 | `bindShootInboxToCustomer` → `ensureTodayShootChart` | 🔒 |
| 10 | 저장 부수효과 | `visit_checked` + 회원권 차감 + 고객 upsert가 한 트랜잭션 | 🔒 P6까지 현행 유지 |

**이 10개 중 하나라도 깨지면 배포 중단, 즉시 롤백.**

---

## 4. 절대 금지 목록 (이 저장소 전용)

- `customer_charts` 의 컬럼 삭제 / 타입 변경 / NOT NULL 추가
- `unique(customer_id, visit_number)` 제약 제거 — 승인 없이 금지
- `before_image_url` / `after_image_url` 컬럼 제거 — **영구 유지 대상**(파생 캐시로 강등)
- `chartsForCustomer` 의 반환 타입을 `List<CustomerChart>` 외의 것으로 변경
- `visits` / `photos` / `consultations` 테이블 신설
- `saveChartAndConfirmVisit` 이름 변경 또는 삭제
- 기존 마이그레이션 파일(`001`~`108`) 수정
- `AdminChartPage` / `ChartManagementPage` / `CareHistoryDetailPage` 를 "새 구조에 맞춰" 재작성

---

## 5. 계약 변경 신청 절차

계약을 바꿔야 한다면 에이전트는 코드 수정 전에 다음을 제출하고 승인을 기다린다.

```
변경할 계약: (위 표의 어느 행)
변경 이유:
영향 받는 호출부 전체 (grep 결과 첨부):
하위 호환 유지 방법:
롤백 방법:
어느 단계인가: P1 / P2 / P3 / P4 / P5 / P6
```
