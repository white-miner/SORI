# P5-b — 방문 금액 기록

목적: 견적을 거치지 않는 **현장 단회 결제**를 기록해, 「고객 누적 결제」와 「이번 달 매출」을
단일 소스로 계산할 수 있게 한다.

전제(조사 확정): sori에는 이미 결제 인프라가 있다.
`program_quote_payments`(입금 원장) · `program_packages.list_price_krw`(정가) ·
`program_memberships.paid_krw` / `expires_at`(선불권). **새로 만들 필요 없다.**
빠진 것은 `customer_charts`의 금액 칸과 `shop_menus`의 정가뿐이다.

---

## 설계 원칙

### 차트 = 현금 유입의 단일 창구

회원권 판매도 그날 방문 차트에 `amount_received_krw` 로 기록한다.

| 상황 | received | service_value | method |
|---|---|---|---|
| 단회 시술 15만 카드 | 150,000 | 150,000 | `card` |
| 10회 패키지 45만 판매 (1회차 시행) | 450,000 | 45,000 | `card` |
| 위 패키지 2~10회차 | 0 | 45,000 | `credit` |
| 서비스 무료 제공 | 0 | 45,000 | `free` |
| 네이버 선결제 | 150,000 | 150,000 | `naverpay` |

**결과**
- 고객 누적 결제 = `sum(charts.amount_received_krw)` — 단일 쿼리, 중복 없음
- 이번 달 매출(현금 흐름) = 이번 달 차트의 `received` 합계
- 이번 달 서비스 제공액 = 이번 달 차트의 `service_value` 합계
- 미소진 선불권 부채 = 선불권 판매액 − 누적 `service_value` (credit 방식분)

### 기존 테이블의 역할 재정의 (스키마 변경 없음)

| 테이블 | 역할 |
|---|---|
| `customer_charts` | 🆕 현금 유입 + 서비스 제공 가치의 SSOT |
| `program_memberships` / `membership_tickets` | 잔여 횟수 · 유효기간 관리 전용 |
| `program_quote_payments` | 견적 경로의 상세 입금 원장 (그대로 유지) |
| `program_packages.list_price_krw` | 패키지 정가 마스터 (그대로 유지) |

---

## 스키마 (Expand only)

`supabase/migrations/1XX_chart_amounts.sql` — 번호는 현재 최대값+1

```sql
alter table public.customer_charts
  add column amount_received_krw integer,
  add column service_value_krw   integer,
  add column payment_method       text;

alter table public.customer_charts
  add constraint chart_payment_method_check
  check (payment_method is null or payment_method in
    ('card','cash','naverpay','transfer','credit','free'));

create index customer_charts_amount_idx
  on public.customer_charts (shop_id, visited_at)
  where amount_received_krw is not null;
```

```sql
alter table public.shop_menus
  add column price_krw integer;
```

- 전부 nullable. 기존 row는 null → 화면에서 금액 줄을 숨긴다 (0원 표기 금지)
- `NOT NULL` 추가 금지. 과거 데이터는 영구히 null로 남는다
- RLS 정책 신규 생성 없음 (기존 테이블 정책 그대로 적용됨)
- `shop_id` / `visited_at` 컬럼명은 실제 스키마 확인 후 맞춘다

---

## 입력 UX — 1탭이 목표

입력이 3탭을 넘으면 사장님은 안 쓴다. 안 쓰면 컬럼만 있고 데이터는 비는 최악이 된다.

1. 시술 선택 → `shop_menus.price_krw` 가 **자동으로** `received` · `service_value` 양쪽에 채워진다
2. 결제 수단 버튼 5개 중 1탭: `카드` `현금` `네이버` `선불권 차감` `무료`
3. `선불권 차감` 을 누르면 `received = 0` 으로 자동 전환 (`service_value` 유지)
4. `무료` 를 누르면 `received = 0`
5. 금액이 다를 때만 숫자를 수정한다

**기본값이 곧 정답**이 되게 만드는 것이 이 기능의 전부다.
`price_krw` 가 비어 있으면 금액 입력란을 빈 칸으로 두고 포커스만 준다.

---

## 단계

### P5b-1 — 스키마 + 정가 입력
- 위 두 마이그레이션 적용
- 시술 메뉴 관리 화면에 정가 입력란 추가 (기존 메뉴 화면에 필드 1개 추가)
- 차트 화면은 아직 안 바꾼다

### P5b-2 — 차트 작성기에 금액 입력
- 금액 · 결제수단 UI를 차트 작성기와 「1초 간편 차트」에 추가
- 자동 채움 + 5버튼 규칙 구현
- 저장 경로는 기존 `saveChartAndConfirmVisit` 그대로 사용. **차감 로직은 건드리지 않는다**

### P5b-3 — 고객 차트 요약 바에 「누적 결제」 복원
- `ChartSummary` 에 `totalReceived` 추가 → 요약 바 3칸 → 4칸
- 값이 전부 null 인 고객은 칸을 숨긴다 (신규 도입 초기 대비)

### P5b-4 — 결제 탭
- 회차별 `received` / `service_value` / `method` 리스트
- 상단에 누적 결제 · 이번 달 받은 금액 · 잔여 선불권

---

## 금지

- `program_quote_payments` · `program_memberships` · `membership_tickets` 스키마 변경
- 기존 회원권 차감 로직 수정 — P5-b는 **금액을 적기만** 한다
- PG 결제 연동 · 네이버 예약 API 연동 (범위 밖)
- `customer_charts` 금액 컬럼에 `NOT NULL` 부여
- 금액 null 인 회차에 「0원」 표기

---

## P8 백로그 — 회원권 3중 저장 (지금 건드리지 않음)

같은 개념이 세 곳에 있다. 화면마다 「잔여」 숫자가 다를 수 있다.

| 소스 | 파일 |
|---|---|
| `customers.memberships` jsonb + 미러 컬럼 | `008` |
| `membership_tickets` | `016`, `022`, `071` |
| `program_memberships` | `115` |

**당면 조치:** UI가 「잔여」를 표시할 때 사용하는 소스를 **`Customer.membershipRemainingVisits` 하나로 고정**하고 문서에 명시한다. 다른 소스를 섞어 읽지 않는다.

**향후 P8:** 셋 중 하나를 SSOT로 정하고 나머지를 파생/캐시로 강등. 별도 조사·계획 필요.
