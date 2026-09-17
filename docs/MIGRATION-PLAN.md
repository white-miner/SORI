# sori 마이그레이션 계획 — 실제 런타임 기준

조사 결과 반영판. 이전 문서의 "Visit 테이블 신설" 전제는 **폐기**한다.

---

## 핵심 판단: Visit 테이블을 새로 만들지 않는다

조사에서 드러난 사실:

> `customer_charts` 한 row = 한 회차 = 상담 + 사진 + 방문 확인의 중심

즉 **`customer_charts` row가 이미 Visit이다.** 여기에 `visits` 테이블을 새로 만들면
`chartsForCustomer` · `visitNumber` · `chartDraftId` · `buildVisitPhotoSlots` ·
`bind_ba_session_to_chart` RPC가 전부 두 개의 진실을 갖게 된다. 위험도 상 5개 중 3개가 여기서 터진다.

**따라서 전략은 "새 구조로 이사"가 아니라 "지금 구조를 승격"이다.**

| 목표 개념 | 신설? | 실제 처리 |
|---|---|---|
| Visit | ❌ 신설 안 함 | `customer_charts` row를 Visit으로 **인정**. 결속 키만 교체 |
| Consultation | ❌ 신설 안 함 | `visit_number = 1` 또는 `is_consultation` 플래그로 구분 |
| ChartNote (SOAP) | ❌ 별도 테이블 안 만듦 | `customer_charts`에 nullable 컬럼 4개 추가 |
| Photo / PhotoSet | ✅ **유일한 신설** | URL 2컬럼 → N장 지원. 이것만이 진짜 구조적 결함 |
| Payment / CreditLedger | ⏸ 나중 | 지금 건드리지 않는다. 회원권 차감 로직이 저장 경로에 묶여 있어 위험 |

---

## 진짜 고쳐야 할 결함 2개

나머지는 지금 잘 돌아가고 있다. 실제 문제는 이 둘뿐이다.

### 결함 A — 하루 다(多)Visit 충돌 (위험도 상)
`unique(customer_id, visit_number)` + `ensureTodayShootChart`가 **캘린더 날짜**로 row를 재사용한다.
같은 고객이 하루 두 번 오면 사진·동의가 한 row에 섞인다.
→ 결속 키를 **날짜에서 `visit_session_id`로 교체**한다.

### 결함 B — 사진 2장 한계 (위험도 상)
`before_image_url` / `after_image_url` 2컬럼 구조라 회차당 사진이 2장으로 고정된다.
부위별 세트(얼굴 정면 / 우측 45° / 등)도 불가능하다.
→ 사진 테이블을 신설하되, **URL 컬럼은 캐시로 남긴다.**

---

## 단계별 계획

각 단계 = 별도 브랜치 = 별도 배포. 앞 단계가 최소 3일 무사고여야 다음으로 간다.

---

### P0 — 안전망 (코드 수정 0)

특성화 테스트를 먼저 깐다. "옳은 동작"이 아니라 **"지금 동작"**을 박제한다.

| # | 시나리오 | 고정할 것 |
|---|---|---|
| 1 | 차트 작성 → 저장 → 고객차트 렌더 | `chartsForCustomer` 결과 개수·순서·`visitNumber` |
| 2 | 촬영 → before/after URL 부착 | 두 URL 컬럼 값과 Storage 경로 규칙 |
| 3 | `ensureTodayShootChart` 2회 호출 | 같은 날이면 **같은 row 재사용**한다는 현재 동작 |
| 4 | `saveChartAndConfirmVisit` | 차트 저장 + `visit_checked` + 회원권 차감이 **한 번에** 일어남 |
| 5 | `bind_ba_session_to_chart` RPC | URL coalesce 동작 |
| 6 | `buildVisitPhotoSlots` | 차트 리스트 → 슬롯 매핑 결과 |

3·4번은 "이게 문제다"라고 인식된 동작이지만, **그대로 박제한다.** 바꿀 때 무엇이 변했는지 알기 위해서다.

---

### P1 — Expand: 사진 테이블 신설 (읽기는 그대로)

`supabase/migrations/109_chart_photo_records.sql`

```sql
create table public.photo_sets (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  customer_id uuid not null,
  label text not null,              -- '얼굴 정면' / '우측 45°' / '등 상부'
  pose_template jsonb,
  created_at timestamptz default now()
);

create table public.chart_photo_records (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.customer_charts(id) on delete cascade,
  photo_set_id uuid references public.photo_sets(id),
  phase text not null check (phase in ('before','progress','after')),
  url text not null,
  pose_keypoints jsonb,
  ref_photo_id uuid references public.chart_photo_records(id),
  sort_order int default 0,
  created_at timestamptz default now()
);

create index on public.chart_photo_records (chart_id, phase, sort_order);
```

**이 단계에서 하는 것**
- 위 테이블 생성 (RLS는 `019_chart_photos_storage.sql`의 정책을 그대로 복제)
- 업로드 경로에서 **이중 기록**: 기존 URL 컬럼에도 쓰고, 새 테이블에도 한 줄 넣는다
  - `ChartPhotoStorage.uploadWebp` 이후 호출부 3곳: `admin_chart_writer_page`, `shoot_hub_page`, `bind_ba_session_to_chart`
- **읽기는 전혀 바꾸지 않는다.** `buildVisitPhotoSlots`, 비교뷰어, 케어 내역 전부 그대로 URL 컬럼을 읽는다

**절대 안 하는 것**: `before_image_url` / `after_image_url` / `photo_meta` 수정·삭제

---

### P2 — Backfill: 기존 사진 이관

멱등 스크립트. 여러 번 돌려도 안전해야 한다.

```sql
insert into public.chart_photo_records (chart_id, phase, url, sort_order)
select c.id, 'before', c.before_image_url, 0
from public.customer_charts c
where c.before_image_url is not null
  and not exists (
    select 1 from public.chart_photo_records p
    where p.chart_id = c.id and p.phase = 'before' and p.url = c.before_image_url
  );
-- after 도 동일
```

검증 쿼리도 함께 제출한다.

```sql
select
  (select count(*) from customer_charts where before_image_url is not null) as legacy_before,
  (select count(*) from chart_photo_records where phase='before') as new_before;
```

PhotoSet은 이 단계에서 채우지 않는다. 기존 사진은 부위 정보가 없다.
`label = '기본'` 세트 하나를 고객당 만들어 붙이거나, `photo_set_id`를 null로 두고 나중에 사장님이 분류하게 한다.

---

### P3 — 결속 키 교체 (결함 A 해결)

`supabase/migrations/110_chart_visit_binding.sql`

```sql
alter table public.customer_charts
  add column visit_session_id uuid references public.visit_sessions(id);

create unique index chart_per_visit_session
  on public.customer_charts (visit_session_id)
  where visit_session_id is not null;
```

**Dart 쪽**
- `ensureTodayShootChart(customerId)` 는 **삭제하지 않는다.** 시그니처 그대로 남긴다.
- `ensureVisitChart({required visitSessionId, required customerId})` 를 **새로 추가**한다.
- 기존 함수는 내부에서 새 함수로 위임하되, `visitSessionId`가 없으면 예전처럼 날짜 기준으로 동작한다.

```dart
// 기존 호출부는 한 줄도 안 고친다
Future<CustomerChart> ensureTodayShootChart(String customerId) =>
    ensureVisitChart(customerId: customerId, visitSessionId: null);
```

`unique(customer_id, visit_number)` 는 **이 단계에서 건드리지 않는다.**
`visit_number`는 "표시용 회차 번호"로 의미를 강등시키고, 결속은 `visit_session_id`가 담당한다.
두 제약이 충돌하면(하루 두 번 방문) 그때 `visit_number`에 소수점이나 `_2` 접미가 아니라 **다음 정수를 부여**하면 된다 — 회차가 하루에 2 오르는 것은 도메인적으로 맞는 동작이다.

---

### P4 — 읽기 전환 (신규 우선, 구형 폴백)

```dart
List<PhotoSlot> buildVisitPhotoSlots(List<CustomerChart> charts) {
  // 1) chart_photo_records 에 레코드가 있으면 그걸 쓴다
  // 2) 없으면 기존 before/after URL 컬럼으로 폴백
}
```

폴백 분기를 반드시 남긴다. 이게 P2 Backfill이 놓친 데이터의 보험이다.
UI 컴포넌트(`before_after_compare_sheet`, `care_history_detail_page`)는 **시그니처를 바꾸지 않는다.**
여전히 `List<CustomerChart>`를 받고, 내부에서 사진 소스만 바뀐다.

---

### P5 — SOAP 필드 추가

```sql
alter table public.customer_charts
  add column note_subjective text,
  add column note_objective  text,
  add column note_assessment text,
  add column note_plan       text,
  add column next_visit_at   date;
```

별도 `chart_notes` 테이블을 만들지 않는다. 차트 row가 곧 방문이므로 같은 row에 두는 것이 맞다.
기존 자유 텍스트 메모 컬럼은 **남긴다.** 새 4필드가 비어 있으면 기존 메모를 보여주는 폴백을 둔다.

`next_visit_at`이 채워지면 재방문 알림 트리거로 쓴다. 이게 리텐션 기능의 진입점이다.

---

### P6 — 저장/확정 분리 (결함이 아니라 정리)

`saveChartAndConfirmVisit`은 이름과 동작이 묶여 있다. **이름을 바꾸지 않는다.**
내부만 두 함수로 쪼개고, 기존 함수는 둘을 순서대로 부르는 래퍼로 남긴다.

```dart
Future<void> saveChartAndConfirmVisit(...) async {
  final chart = await _saveChartOnly(...);
  await _confirmVisit(chart);   // visit_checked + 회원권 차감
}
```

호출부 0곳 수정. 나중에 "저장만 하고 확정은 Visit 종료 시" 로 바꾸고 싶어지면 그때 `_confirmVisit` 호출 위치만 옮기면 된다.

---

### P7 — Contract: **하지 않는다**

`before_image_url` / `after_image_url` 컬럼은 **제거하지 않는다.**
대신 **파생 캐시 컬럼으로 강등**한다. 사진 저장 시 대표 before/after를 이 컬럼에 계속 동기화한다.

이유:
- 리스트·카드 썸네일에서 join 없이 바로 읽을 수 있다 (성능 이득)
- `bind_ba_session_to_chart` RPC, 미연결 큐, 외부 연동이 계속 동작한다
- 제거해서 얻는 이득이 위험보다 작다

**즉 이 마이그레이션에는 파괴적 단계가 없다.** 롤백은 항상 "새 코드 배포 되돌리기"로 끝난다.

---

## 단계별 위험도 요약

| 단계 | 내용 | 위험도 | 롤백 |
|---|---|---|---|
| P0 | 특성화 테스트 | 없음 | — |
| P1 | 사진 테이블 신설 + 이중 기록 | 낮음 | 새 테이블 무시하면 끝 |
| P2 | Backfill | 낮음 | 새 테이블 truncate |
| P3 | `visit_session_id` 결속 | **중** | 컬럼 null로 두면 기존 동작 |
| P4 | 읽기 전환 | **중** | 폴백 분기만 남기면 즉시 복구 |
| P5 | SOAP 컬럼 | 낮음 | 컬럼 미사용 |
| P6 | 저장/확정 분리 | 낮음 | 래퍼 유지로 호출부 무영향 |
| P7 | 제거 | — | 하지 않음 |

---

## 각 단계 완료 조건

다음 단계로 넘어가기 전에 전부 참이어야 한다.

1. P0의 특성화 테스트 6개 전부 통과
2. 수동 스모크: 차트 작성 → 사진 → 저장 → 고객차트 → 케어 내역 → B/A 비교 (3분)
3. 기존 데이터로 만든 계정에서 과거 회차가 **하나도 사라지지 않음**
4. 배포 후 3일간 사진 미표시 리포트 0건

---

## 추가 트랙 (조사 후 확정)

### P5-b — 방문 금액 기록 → `docs/P5B-SPEC-AMOUNT.md`
`customer_charts`에 `amount_received_krw` / `service_value_krw` / `payment_method` 추가,
`shop_menus.price_krw` 추가. 차트를 현금 유입의 단일 창구로 만든다.
**결제 인프라는 이미 존재**(`program_quote_payments`, `program_packages.list_price_krw`,
`program_memberships.paid_krw`) — 새로 만들지 않는다.
우선순위: 높음. 이것 없이는 매출·경영 지표가 계산되지 않는다.

### P8 — 회원권 3중 저장 정리 (백로그)
`customers.memberships` jsonb / `membership_tickets` / `program_memberships` 에
같은 개념이 중복 존재. 화면마다 「잔여」가 다를 수 있다.
당면 조치는 UI 읽기 소스를 `Customer.membershipRemainingVisits` 하나로 고정하는 것.
구조 통합은 별도 조사 후.

### UI 트랙 → `docs/UI-SPEC-CUSTOMER-CHART.md`
U1~U4. 데이터 층과 독립. 브랜치 `feat/ui-customer-chart`.
