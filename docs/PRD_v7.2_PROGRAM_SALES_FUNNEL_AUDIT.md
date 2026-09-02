# PRD v7.2 — Program 세일즈 퍼널 자체 점검 & 고도화 설계

- 문서 성격: 코드 수정 없는 **감사(Audit) + 설계 제안**. PO 컨펌 전까지 `lib/` 무수정.
- 감사 기준선: `main` 브랜치 현행 코드 (마이그레이션 `109`~`111` 적용 상태).
- 상위 헌법: `docs/PRD_v7.1_PROGRAM_SALES_OS.md` (Q1~Q7 결정 유지).
- 판정 규칙: 파일·라인 근거가 없으면 [충족]을 쓰지 않고 [부분]으로 강등했다.

---

## §0 Executive Summary

### 판정 집계 (18개 체크포인트)

| 판정 | 개수 | 해당 항목 |
|---|---|---|
| **[충족]** | **1** | C3 |
| **[부분]** | **11** | C1, C2, C5, C7, C8, C9, C10, S1, S3, S4, S6 |
| **[미구현]** | **6** | C4, C6, C11, S2, S5, S7 |

### 가장 치명적인 결함 3가지

- **단건(1택) 상담 경로가 아예 없다** — `_openCompare`는 `_selectedIds.length != 2`이면 즉시 `return`하고(`lib/features/program/program_pane.dart:74-77`), 프로모션 시트·혜택 바·[이 구성으로 등록] 버튼은 전부 `ProgramComparePage` 안에만 존재한다(`lib/features/program/widgets/program_compare_page.dart:49-59, 113-166`). 즉 **고객이 A코스 하나만 원하면 견적 자체를 만들 수 없고, 원장은 팔지 않을 패키지를 억지로 하나 더 체크해야 결제 화면에 도달한다.** 현장 전환율을 직접 깎는 구조적 결함이며 P0다.
- **수금(payment) 개념이 스키마와 UI 어디에도 없다** — `program_quotes`에는 `payable_krw`만 있고 `paid`/`payment_method`/`paid_at`이 없다(`supabase/migrations/109_program_sales_os.sql:94-111`). `accept_program_quote`는 돈을 받았는지와 무관하게 `customers.memberships`에 티켓을 무조건 append한다(`110_program_quote_promo_qty.sql:84-95`). 그 결과 **"결제 예정" 고객과 "입금 완료" 고객이 DB에서 완전히 동일**하고, 미수금은 시스템상 존재하지 않는 돈이 된다. P0다.
- **발급된 혜택의 미래가치가 증발한다** — `ProgramPromoKind.nextVisitCredit`은 enum과 체크 제약에만 존재하고(`lib/models/program_sales.dart:40,46,64`, `109_program_sales_os.sql:75`), 이를 소비·조회하는 코드는 저장소 전체에 단 한 줄도 없다(전역 grep 결과 `lib/` 내 참조 0건). "다음 구매 시 20% 할인"을 팔면 **견적이 accepted되는 순간 그 약속은 어떤 테이블에도 남지 않으며**, 재방문 시 고객이 우기면 원장은 기억에 의존해야 한다. P0다.

---

## §1 세일즈 퍼널 1:1 점검표 (C1~C11)

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C1 | 진입 시 전체 관리 메뉴가 한눈에 보이고 '관리 부위'+'관리 명칭'으로 발견·선택 | 카테고리 카드가 전량 세로 리스트로 렌더되어 '전체 조망'은 되나, 부위(body part) taxonomy 컬럼·필터가 모델과 DB 모두에 없다. `ProgramCategory`의 축은 `name`/`subtitle`/`sortOrder` 뿐이다 | `lib/features/program/program_pane.dart:162-184` / `lib/models/program_sales.dart:244-263` / `supabase/migrations/109_program_sales_os.sql:10-20` | **[부분]** |

→ 보완안:
- `program_categories`에 `body_part text`(얼굴/바디/두피/기타)와 `body_part_sort int`를 추가해 **카테고리 위에 부위 세그먼트 1행**을 얹는다. 마이그레이션 `112`에 포함.
- `ProgramPane` 상단에 부위 필터 칩 행(가로 스크롤)을 두고, 선택 시 `programBoards`를 `body_part`로 필터링한다. 아코디언 exclusive 규칙(Q1)은 그대로 둔다.
- 부위는 카테고리의 **속성**이지 새 뎁스가 아니다. 2뎁스 드릴다운을 만들면 상담 중 뒤로가기가 생겨 화법이 끊긴다.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C2 | 코스 구성이 관리 시간 / 사용 기기 / 제품 안내 / 관리 내용 4종 전부 표시 | 표시(read) 측은 4종을 모두 분기해 렌더한다. 그러나 **입력(write) 측이 4종을 만들 수 없다** — 패키지 편집 시트의 '구성' 동적 리스트는 모든 행을 `kind: ProgramLineKind.perk`로 하드코딩하고 `minutes`를 아예 넘기지 않는다. 따라서 원장이 직접 만든 패키지는 영원히 `step/device/ampoule`이 0건이고 '시간 합'은 0분으로 고정된다. `step`/`minutes`가 채워진 데이터는 데모 시드뿐이다 | 렌더: `lib/features/program/widgets/program_compare_page.dart:296-299, 369-399, 401` / 저장: `lib/features/program/widgets/program_editor_sheets.dart:302-316` (특히 `kind: ProgramLineKind.perk` 311행, `minutes` 미지정) / 시드: `lib/models/program_sales.dart:947-1008` | **[부분]** |

→ 보완안:
- 구성 입력 행을 `[종류 드롭다운] + [내용] + [분]` 3열로 바꾼다. 종류는 `ProgramLineKind`의 한국어 라벨(관리 내용/사용 기기/제품·앰플/추가 혜택)을 노출하고, `minutes`는 `step`일 때만 활성화한다.
- `ProgramLineKind`에 `labelKo` getter를 추가한다. `ProgramPromoKind.labelKo`(`lib/models/program_sales.dart:60-65`)와 동일한 원칙 — dbValue를 UI에 절대 노출하지 않는다.
- DB 변경은 불필요하다. `program_package_lines.kind`/`minutes`는 이미 존재하며(`109:48-56`) 저장 경로도 이미 열려 있다(`lib/data/supabase_sori_repository.dart:5718-5734`). **순수 UI 결함이다.**

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C3 | 코스 선택 시 1회 단품 가격과 패키지 가격이 동시 노출 | 아코디언 전개 행이 정가·회당 단가·단품 1회를 한 블록에 함께 렌더하고, 패키지 회당가가 단품보다 쌀 때만 단품 줄에 취소선과 크기 강조를 준다. 단품가는 편집 시트에 입력 필드가 있고 `walk_in_price_krw`로 저장된다 | `lib/features/program/widgets/program_board.dart:195-211` / `lib/features/program/widgets/program_unit_price.dart:22-52` / `lib/features/program/widgets/program_editor_sheets.dart:426-435` / `supabase/migrations/111_program_package_accent_walkin.sql:4-8` | **[충족]** |

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C4 | 패키지 선택 시 고른 정보가 순서대로 요약되고 [프로모션] 버튼 노출 (★1택 단건 요약 화면 존재 여부) | **단건 요약 화면은 존재하지 않는다.** 1택 상태에서 화면에 뜨는 것은 CompareDock 하나이며, 그 안내 문구는 "하나를 더 고르면 비교할 수 있습니다"이고 [비교하기] 버튼은 `compareEnabled == false`로 비활성이다. `_openCompare`는 2택이 아니면 아무 일도 하지 않으며, `presentProgramQuote`는 `left`·`right` 두 패키지를 필수 인자로 요구한다. 프로모션 버튼·혜택 바·등록 버튼은 전부 `ProgramComparePage` 내부에만 있다 | `lib/features/program/program_pane.dart:74-77, 187-206, 284-298, 326-346` / `lib/services/sori_store.dart:6496-6520` / `lib/features/program/widgets/program_compare_page.dart:113-166` | **[미구현]** |

→ 보완안:
- `presentProgramQuote`의 `right`를 nullable로 완화하고, `ProgramQuote`에 단건 모드를 허용한다(`right = left` 복제 대신 `rightPackageId = null`, 스냅샷 `right`는 `null` 허용). DB는 이미 `right_package_id`가 nullable이다(`109:100`).
- `ProgramQuotePage`(단건 요약)를 신설하고, `ProgramComparePage`의 하단 3종(`_AvailablePromos`/`_BenefitBar`/버튼 행)을 **공용 위젯으로 추출**해 단건·비교가 같은 클로징 UI를 공유하게 한다.
- CompareDock의 1택 상태 버튼을 [이 구성으로 진행]으로 바꾸고, 2택이 되면 [비교하기]로 전환한다. 버튼을 비활성으로 두는 현행은 **원장에게 "지금은 아무것도 할 수 없다"는 잘못된 신호**를 준다.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C5 | 프로모션 버튼을 누르면 적용 가능한 옵션이 보이는가 | 시트 자체는 완성도가 높다 — 활성 기간이 유효한 프로모션만 넘기고, 행마다 수량 스테퍼로 같은 혜택을 최대 9장까지 겹칠 수 있으며, 혜택 합계와 건수를 실시간 갱신한다. 다만 **버튼 진입점이 비교 화면 1곳뿐**이라 C4 결함에 종속된다 | 시트: `lib/features/program/widgets/promotion_closer_sheet.dart:60-83, 102-164, 167-184` / 필터: `lib/services/sori_store.dart:6370-6374` / 진입점: `lib/features/program/widgets/program_compare_page.dart:124-144` | **[부분]** |

→ 보완안:
- 시트 로직은 그대로 재사용하고 **호출 지점만 단건 요약 화면에 추가**한다(R2에서 함께 처리).
- 시트에 적용 범위 필터를 넣는다 — 현재는 샵의 모든 활성 프로모션을 무차별로 보여주므로(`liveProgramPromotions`), '윤곽 A패키지 전용' 혜택이 웨딩 패키지 견적에도 뜬다. `112`의 `scope`/`target_id` 도입 후 견적의 `chosen` 기준으로 걸러야 한다.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C6 | 전체(Global) 프로모션 + 개별(Individual) 프로모션이 함께 표시되고 각각 선택 가능 | **`program_promotions`에 scope/target 컬럼이 없다.** 테이블 컬럼은 `kind, title, subtitle, value_krw, extra_visits, discount_krw, is_active, sort_order, valid_from, valid_until`이 전부이며, Dart 모델도 동일하다. 따라서 전체/개별 구분 자체가 표현 불가능하고, UI는 전량을 한 덩어리로 나열한다 | `supabase/migrations/109_program_sales_os.sql:68-87` / `lib/models/program_sales.dart:607-636` / `lib/features/program/widgets/program_compare_page.dart:510-532` | **[미구현]** |

→ 보완안:
- 마이그레이션 `112`에서 `scope text check (scope in ('global','category','package'))`와 `target_id uuid`를 추가한다. `global`이면 `target_id is null`을 CHECK로 강제한다.
- 시트를 **[전체 혜택] 섹션 + [이 패키지 전용] 섹션 2단**으로 나눈다. 전체는 기본 노출, 개별은 선택된 패키지에 걸린 것만 노출.
- 혜택 바 칩에도 전체/전용을 구분하는 미세 라벨을 붙인다(색이 아니라 텍스트로 — 헌법상 색 추가 금지).

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C7 | 선택 항목이 정리되어 구성과 최종 결제 금액이 표시 | 구성(스텝/기기/앰플/시간 합)과 정가·혜택 합·적용 칩은 표시된다. 그러나 **"오늘 결제" 줄이 `hasDiscount`일 때만 렌더**되므로, `gift`·`extra_session`만 붙인 전형적 상담(할인 0원, 혜택 40만 원)에서는 **최종 결제 금액 줄이 화면에서 사라진다.** 고객은 정가만 보고 "그래서 얼마 내나요"를 되묻게 된다 | `lib/features/program/widgets/program_compare_page.dart:547, 601-612` / 산식: `lib/models/program_sales.dart:91-98` | **[부분]** |

→ 보완안:
- `hasDiscount` 조건을 제거하고 **"오늘 결제" 줄을 무조건 렌더**한다. 할인이 없으면 정가와 같은 숫자가 뜨는 것이 정상이며, 이는 헌법(정가≠혜택≠결제액 3분리)에 부합한다.
- 정가 취소선은 `hasDiscount`일 때만 유지한다. 취소선 유무로 할인 여부를 말하고, 결제액 줄은 상시 고정한다.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C8 | 고른 정보를 Freeze한 채 추가 선택 필드가 열려 비교 대상을 고를 수 있는가 (★FIFO 동작 판정) | **Freeze는 되지만 '추가 선택'은 아니다.** 스냅샷 동결은 정상 작동한다 — `presentProgramQuote`가 `toSnapshot()`으로 두 패키지를 jsonb에 얼리고, 이후 `_repriceQuote`는 카탈로그가 아닌 `quote.chosen.listPriceKrw`(스냅샷 값)로만 재계산한다. 그러나 선택 인터랙션은 `_toggleCheck`가 3번째 체크 시 `_selectedIds.removeAt(0)`으로 **가장 먼저 고른 것을 조용히 버리는 FIFO**다. 고객이 "이것도 같이 봐 주세요"라고 하면 앞서 합의한 패키지가 예고 없이 사라진다. 비교 화면 안에서 제3의 대상을 추가하는 필드도 없다 | Freeze: `lib/services/sori_store.dart:6504-6521, 6538-6549` / FIFO: `lib/features/program/program_pane.dart:53-64` | **[부분]** |

→ 보완안:
- 3번째 체크 시 조용히 버리지 말고 **"어느 것을 뺄까요" 선택을 요구**한다(2택 유지가 Q2 결정이므로 슬롯 교체 UI로 처리). 최소한 CompareDock의 칩이 교체되는 애니메이션으로 소실을 시각화한다.
- 단건 요약 화면(R2)에 [비교 대상 추가] 버튼을 두어, **1택 확정 → Freeze → 추가 1택 → 비교**라는 PO 원문 순서를 그대로 재현한다. 이것이 조건의 진의다.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C9 | 비교 후 최종 선택이 종합되어 한 번에 납득 가능하게 재확인 | 비교 화면 하단에 정가·혜택 칩·결제액이 모이지만, [이 구성으로 등록]을 누르면 **재확인 단계 없이 곧바로 고객 선택 시트가 뜨고**, 시트에서 고객을 고르면 그 즉시 회원권이 발급된다. 종합 확인은 발급 **이후** 스낵바 한 줄("A코스 8회 등록")로 대체돼 있다. 관리명(카테고리)·코스·구성·프로모션을 한 화면에 모아 보여주는 확인 뷰는 없다 | `lib/features/program/widgets/program_compare_page.dart:61-70, 148-166` / `lib/features/program/program_accept.dart:13-30` | **[부분]** |

→ 보완안:
- 등록 직전 **확정 시트(Confirm Sheet)** 를 1장 넣는다. 내용: 카테고리명 · 패키지명 · 총 횟수(프로모션 추가분 포함) · 구성 요약 · 적용 혜택 칩 · 정가/혜택/오늘 결제 3줄 · 고객 · 결제 상태 토글(C11).
- 이 시트가 C11(결제 체크)과 C10(신규 고객 퀵 생성)의 자연스러운 그릇이 된다. 세 조건을 한 슬라이스로 묶는 것이 맞다.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C10 | 미등록 신규 고객도 화면 이탈 없이 퀵 생성해 즉시 연동 | `showVisitCustomerPickerSheet`는 **기존 고객 검색·선택 전용**이다. 결과가 없을 때 문구는 "고객을 찾을 수 없어요."로 끝나고 신규 생성 CTA가 없다. 반면 차트 쪽 피커에는 이미 신규 생성 CTA 선례가 있어(`chart_customer_picker_sheet.dart:130-166`) 기술적 장벽은 없다. 저장소·스토어 경로도 이미 열려 있다 | `lib/features/visit/visit_customer_picker_sheet.dart:103-139` (특히 108-118행) / 선례: `lib/views/chart_customer_picker_sheet.dart:130-166` / 경로: `lib/services/sori_store.dart:6916` | **[부분]** |

→ 보완안:
- `showVisitCustomerPickerSheet`에 `allowQuickCreate` 플래그를 추가하고, 검색어가 있을 때 상단에 **"'홍길동' 신규 등록" 인라인 CTA**를 띄운다. 탭 시 이름+연락처 2필드만 받는 미니 폼을 같은 시트 내부에서 push한다(화면 이탈 없음).
- 생성은 `addCustomerAsync`를 재사용하고, 반환된 `Customer`를 그대로 견적 수락에 넘긴다. 신규 고객 색(Violet #8B5CF6)은 이 CTA에만 쓰고 클로징 버튼에는 쓰지 않는다 — 헌법 준수.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| C11 | [결제 완료 / 미결제] 수동 토글이 있는가 | **없다.** `program_quotes`에 결제 상태 컬럼이 없고, `CustomerMembership`에도 `paidAmount`(금액)만 있을 뿐 수금 여부 플래그가 없다. `accept_program_quote`는 조건 없이 `memberships`에 append하므로 미수금 견적과 완납 견적이 DB에서 구분되지 않는다 | `supabase/migrations/109_program_sales_os.sql:94-111` / `supabase/migrations/110_program_quote_promo_qty.sql:84-95` / `lib/models/customer_membership.dart:5-25` | **[미구현]** |

→ 보완안:
- 마이그레이션 `113`으로 `program_quotes`에 `payment_status`(`unpaid`/`partial`/`paid`), `paid_krw`, `paid_at`, `payment_method`를 추가하고 `program_quote_payments` 원장 테이블을 신설한다(분할 결제·계좌이체 대기 대응).
- 확정 시트(C9)에 [결제 완료 / 미결제] 세그먼트 컨트롤과 결제 수단 칩(현금/카드/이체)을 놓는다. 기본값은 **미결제**로 두어 원장이 능동적으로 완료를 찍게 한다.
- PG 연동은 이번에도 범위 밖이다. 수기 체크로 닫는 것이 헌법이다.

---

## §2 설정·프로모션 엔진 점검표 (S1~S7)

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| S1 | 설정창도 상담 흐름과 같은 구조인가 | 카테고리 → 그 아래 패키지 들여쓰기 → 하단 프로모션 섹션이라는 **계층은 상담 IA와 일치**하고, 패키지 타일이 회당 단가와 액센트 점을 상담 화면과 같은 어휘로 보여준다. 그러나 상담의 핵심 문법인 **아코디언(exclusive 접힘)과 앵커 강조가 설정창에는 없어** 전부 펼쳐진 평면 리스트다. 카테고리가 5개를 넘으면 원장이 스크롤로 길을 잃는다 | `lib/features/program/program_edit_page.dart:57-148` / 비교 대상: `lib/features/program/widgets/program_board.dart:42-121` | **[부분]** |

→ 보완안:
- 편집 페이지 카테고리 블록을 `ExpansionTile` 계열로 바꿔 **상담 화면과 동일한 접힘 규칙**을 적용한다. 뒷무대이므로 exclusive까지 강제할 필요는 없다.
- 단, Presentation 모드 카드에 휴지통·드래그 핸들을 넣지 않는 헌법은 유지된다. 삭제 아이콘은 지금처럼 편집 페이지에만 존재해야 한다(`program_edit_page.dart:80-83, 112-115`).

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| S2 | 프로모션을 전체/개별로 나눠 세팅·적용 | 프로모션 시트의 입력 필드는 제목 · 종류(4택 칩) · 혜택 환산액 3개뿐이다. 적용 범위를 고르는 입구가 UI에도, 모델에도, 테이블에도 없다 | `lib/features/program/widgets/program_editor_sheets.dart:609-655` / `lib/models/program_sales.dart:607-636` / `supabase/migrations/109_program_sales_os.sql:68-87` | **[미구현]** |

→ 보완안:
- `112` 마이그레이션의 `scope`+`target_id`를 받은 뒤, 프로모션 시트 최상단에 **[전체 / 카테고리 / 패키지] 세그먼트**를 놓고 카테고리·패키지 선택 시 하위 드롭다운을 노출한다.
- 적용 시점 필터는 `liveProgramPromotions`에 `forPackage(package)` 오버로드를 추가해 견적의 `chosen` 기준으로 거른다.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| S3 | 전체 프로모션을 세팅해두면 가격 정보 표시 단계에서 자동 노출 | 비교 화면에는 '적용 가능 프로모션' 칩 줄이 자동으로 뜬다. 그러나 **가격이 처음 등장하는 단계인 아코디언 보드(collapsed 앵커 · expanded 행)에는 프로모션이 전혀 노출되지 않는다.** 즉 자동 노출은 퍼널 후반에서만 일어나며, 조건이 지목한 '가격 정보 표시 단계'와는 한 스텝 어긋나 있다 | 노출: `lib/features/program/widgets/program_compare_page.dart:112, 488-536` / 미노출: `lib/features/program/widgets/program_board.dart:65-121` | **[부분]** |

→ 보완안:
- 카테고리 카드 collapsed 상태의 앵커 가격 **바로 아래에 전체 프로모션 1줄 요약**(예: "전체 혜택 · 9월 한정 +1회")을 텍스트로 붙인다. 배너·그라데이션·% OFF 스티커는 금지이므로 캡션 톤으로만 처리한다.
- `scope='global'`인 것만 보드에 올린다. 개별 혜택까지 보드에 뿌리면 앵커의 시선 독점이 깨진다.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| S4 | 개별 프로모션에 할인% / 횟수 추가 / 갯수(제품) 추가 옵션 | 셋 중 **하나도 온전하지 않다.** ① 퍼센트 할인: `percent_off` 컬럼 자체가 없고 `discount_krw` 정액만 존재한다. ② 횟수 추가: 종류를 '횟수 추가'로 고르면 `extraVisits`가 **무조건 1로 하드코딩**되어 "+3회"를 만들 수 없다. ③ 제품 갯수: `gift_qty`가 없어 "제품 2개 증정"은 제목 문자열에만 산다. 견적 단위의 `qty` 스택(`110`)은 있지만 이는 '같은 혜택을 여러 장 붙이기'이지 '혜택 자체의 수량 정의'가 아니다 | `lib/features/program/widgets/program_editor_sheets.dart:575-599` (특히 `final extra = _kind == ProgramPromoKind.extraSession ? 1 : 0;` 579행) / `supabase/migrations/109_program_sales_os.sql:68-87` / 스택: `supabase/migrations/110_program_quote_promo_qty.sql:4-12` | **[부분]** |

→ 보완안:
- `112`에서 `percent_off numeric(5,2)`와 `gift_qty int`를 추가하고, `extra_visits`는 이미 있으므로 **UI에서 수량 입력을 열어주기만 하면 된다**(하드코딩 1 제거).
- 퍼센트 할인은 `payable` 산식에 개입하므로 `ProgramPricing.payable`을 확장해야 한다 — **정액 할인 합계를 먼저 빼고 그 다음 퍼센트를 적용**하는 순서를 SSOT로 못 박고(`lib/models/program_sales.dart:94-98`), 동일 규칙을 SQL 쪽 RPC에도 복제한다.
- 퍼센트 결과값은 `payable`에만 반영하고 `list_price_krw`는 절대 건드리지 않는다 — 헌법 준수.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| S5 | 키워드 조립형([범위]+[종류]+[값]) 입력으로 모든 상황 대처 | 현행 입력은 **자유 텍스트 제목 + 4택 enum + 금액 1개**의 고정 폼이다. 범위 축이 없고(S2), 값 축이 금액 단일이라(S4) 조립 문법을 구성하는 3요소 중 2개가 결여돼 있다. "윤곽 A패키지 / +1회" 같은 표현은 원장이 제목 문자열에 손으로 적는 수밖에 없으며, 그렇게 적힌 의미는 시스템이 해석하지 못한다 | `lib/features/program/widgets/program_editor_sheets.dart:575-599, 609-655` / `lib/models/program_sales.dart:607-636` | **[미구현]** |

→ 보완안:
- 프로모션 시트를 **3단 조립기**로 재설계한다. 1단 범위(전체/카테고리/코스/패키지) → 2단 혜택 종류(할인%/정액 할인/횟수 추가/제품 증정/다음 구매 쿠폰) → 3단 값(종류에 따라 % 또는 원 또는 회 또는 개).
- 조립 결과를 **미리보기 문장**으로 시트 상단에 실시간 렌더한다(예: "윤곽 관리 · A코스 / 횟수 +1회 / 혜택 환산 12만 원"). 이 문장이 곧 `title`의 기본값이 되어 원장 타이핑을 없앤다.
- `kind` enum에는 `percent_discount`를 추가해야 한다. 기존 4종은 CHECK 제약에 박혀 있으므로(`109:71-76`) `112`에서 제약을 재생성한다.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| S6 | 사용했던 프로모션이 칩으로 자동 저장되어 원터치 불러오기·수정·삭제 | **재사용 자체는 성립한다** — 프로모션은 견적에 종속되지 않는 샵 단위 카탈로그 행이므로 한 번 만들면 계속 남고, 편집 페이지에서 탭하면 수정 시트가 열리며 휴지통으로 삭제된다. 상담 화면에도 칩 형태로 렌더된다. 그러나 조건이 요구한 **'사용 이력 기반 자동 저장'과 '최근 사용순 정렬'은 없다** — 목록은 항상 `sortOrder` 고정순이고, 어떤 혜택이 몇 번 팔렸는지는 집계되지 않는다 | 카탈로그 CRUD: `lib/features/program/program_edit_page.dart:165-181` / 칩 렌더: `lib/features/program/widgets/program_compare_page.dart:510-532` / 정렬: `lib/services/sori_store.dart:6370-6374` | **[부분]** |

→ 보완안:
- `program_promotions`에 `last_used_at timestamptz`와 `use_count int`를 추가하고, 견적 수락 RPC에서 붙은 혜택들의 카운터를 올린다. 시트 정렬을 `last_used_at desc nulls last, sort_order`로 바꾼다.
- 이는 **테이블 컬럼 2개로 끝나는 저비용 개선**이며, 원장의 반복 타이핑 제거라는 조건의 목적을 직접 달성한다.

| # | 조건(원문 요지) | 현재 구현 상태 | 근거(파일:라인) | 판정 |
|---|---|---|---|---|
| S7 | 조건부 혜택("다음 구매 20% 할인")이 고객 차트에 미사용 쿠폰으로 영구 기록되고 재방문 시 식별 | **완전히 미구현이다.** `nextVisitCredit`은 enum 정의·dbValue 매핑·한국어 라벨·CHECK 제약에만 존재하고, 이를 **발급하거나 저장하거나 소비하는 코드는 저장소 전체에 없다**(`lib/` 전역 검색 결과 참조 0건). `accept_program_quote`가 고객에게 남기는 것은 `service_name/total_visits/used_visits/paid_amount/per_session_value` 5개 필드의 회원권 jsonb 뿐이며 쿠폰 슬롯이 없다. 즉 원장이 "다음에 20% 해드릴게요"를 팔면 **견적이 닫히는 순간 그 약속은 증발한다** | enum: `lib/models/program_sales.dart:40, 46, 64` / 제약: `supabase/migrations/109_program_sales_os.sql:75` / 발급 로직: `supabase/migrations/110_program_quote_promo_qty.sql:84-95` / 회원권 모델: `lib/models/customer_membership.dart:5-25` | **[미구현]** |

→ 보완안:
- 마이그레이션 `114`로 `program_customer_coupons` 테이블을 신설한다 — 발급 견적, 고객, 혜택 사양(퍼센트/정액/횟수/제품), 상태(`issued`/`used`/`expired`/`void`), 만료일, 사용 견적을 갖는다.
- `accept_program_quote`를 확장해 `kind='next_visit_credit'`인 혜택은 **회원권 횟수가 아니라 쿠폰 행으로 떨어지게** 한다. 이것이 "미래가치는 회원권과 다른 자산"이라는 회계적 사실을 반영한다.
- 고객 차트 상단과 방문 시작 시점에 **미사용 쿠폰 배지**를 띄운다. 재방문 식별은 조회가 아니라 능동 알림이어야 실효가 있다.

---

## §3 현장 빈틈 분석 (E1~E8)

### E1. 환불 / 부분 환불

- **상황**: 10회 300만 원 패키지를 산 고객이 3회를 소진한 뒤 이사 때문에 환불을 요구한다. 원장은 "3회는 정가 회당 35만으로 계산하고 나머지를 돌려준다"는 약관을 적용하려 한다.
- **현행 결과**: 환불이라는 개념이 코드에 없다. `CustomerMembership`은 `totalVisits`·`usedVisits`·`paidAmount`만 갖고 상태 필드가 없으며(`lib/models/customer_membership.dart:15-25`), 회원권은 `customers.memberships` jsonb 배열에 append-only로 쌓인다(`supabase/migrations/110_program_quote_promo_qty.sql:93-95`). 원장이 할 수 있는 유일한 행동은 배열에서 그 티켓을 **통째로 지우는 것**이고, 그러면 "얼마를 언제 왜 돌려줬는가"가 영구히 사라진다. 매출 원장에 구멍이 난다.
- **리스크 등급**: **P0**
- **해결책**: 스키마 — 회원권을 jsonb에서 `program_memberships` 테이블로 승격하고(`115`) `status`(`active`/`refunded`/`transferred`/`expired`/`void`), `refunded_krw`, `refunded_at`, `refund_reason`을 둔다. 소진분 정산 기준(정가 회당 vs 패키지 회당)은 `refund_basis` 컬럼으로 남겨 사후 분쟁에 대비한다. `customers.memberships`는 읽기 미러로만 유지해 기존 화면을 깨지 않는다.

### E2. 중간 패키지 변경 (업그레이드)

- **상황**: B코스 6회를 산 고객이 2회 받아보고 만족해서 A코스 10회로 올리고 싶어 한다. 원장은 "쓰신 2회 값만 빼고 차액만 받겠다"고 말한다.
- **현행 결과**: 승계 경로가 없다. `acceptProgramQuote`는 항상 **새 티켓을 배열 끝에 추가**할 뿐 기존 티켓을 참조하지 않는다(`lib/services/sori_store.dart:6608-6614, 6650-6661`). 결과적으로 고객 차트에는 B코스 잔여 4회와 A코스 10회가 **동시에 살아 있는 유령 상태**가 되고, 차감 로직은 이름 매칭으로 아무거나 먼저 걸리는 쪽을 깎는다(E7 참조).
- **리스크 등급**: **P1**
- **해결책**: 상태 전이 — `program_memberships`에 `superseded_by uuid`(자기 참조)와 `credit_applied_krw`를 추가하고, 업그레이드 시 원본을 `status='superseded'`로 닫으면서 잔여 가치(`per_session_value × remaining`)를 신규 견적의 선수금으로 넘긴다. UI — 견적 확정 시트에 "기존 회원권 승계" 체크와 승계 금액 표시를 넣는다.

### E3. 프로모션 기한 만료

- **상황**: 9월 한정 "다음 구매 20% 할인" 쿠폰을 받은 고객이 11월에 방문해 "그때 받은 거 써 주세요"라고 한다.
- **현행 결과**: 두 겹으로 비어 있다. ① 발급된 쿠폰이 애초에 저장되지 않는다(S7). ② 카탈로그 프로모션의 만료는 `isLiveAt`으로 **조회 시점에 목록에서 조용히 사라지는 방식**이라(`lib/models/program_sales.dart:638-643`, `lib/services/sori_store.dart:6370-6374`) 상태 전이 기록이 없다. 더 위험한 것은 **이미 발급된 견적의 무결성** — 만료된 프로모션이 붙은 과거 견적을 다시 열면 `_repriceQuote`가 `programPromotions` 카탈로그를 다시 조회하는데(`lib/services/sori_store.dart:6538-6542`), 카탈로그에서 행이 **삭제**되면 `stacked()`가 그 id를 건너뛰어(`program_sales.dart:112-115`) 혜택액과 결제액이 조용히 달라진다. 만료(비활성)는 안전하지만 삭제는 과거 견적을 변조한다.
- **리스크 등급**: **P1**
- **해결책**: 스키마 + 상태 전이 — ① `program_customer_coupons`에 `expires_at`과 `status`를 두고 만료를 **명시적 상태**로 기록한다(`114`). ② 프로모션 삭제를 하드 딜리트에서 `is_active=false` 소프트 딜리트로 바꾼다(`program_edit_page.dart:172-175`가 현재 하드 딜리트를 호출한다). ③ 더 근본적으로, 견적의 혜택 사양도 수락 시점에 **스냅샷으로 얼려야** 한다 — 패키지는 얼리면서(`toSnapshot`) 혜택은 안 얼리는 현행은 비대칭이다.

### E4. 미결제 상태에서의 회원권 차감

- **상황**: 고객이 "다음 주에 이체할게요"라고 하고 원장은 신뢰 관계상 오늘 시술을 진행한다. 다음 주 이체는 오지 않는다.
- **현행 결과**: 시스템은 이 상황을 **인지조차 하지 못한다.** `accept_program_quote`는 수금 여부와 무관하게 회원권을 발급하고(`110:84-95`), 방문 확정 시 `_deductMembership`은 결제 상태를 보지 않고 `usedVisits`를 1 올린다(`lib/services/sori_store.dart:7407-7427`). 미수금은 어떤 화면에도, 어떤 컬럼에도 남지 않는다. 원장이 손실을 발견하는 시점은 **월말 정산에서 숫자가 안 맞을 때**다.
- **리스크 등급**: **P0**
- **해결책**: 스키마 + UI — `113`으로 견적·회원권에 `payment_status`를 도입하고, `unpaid` 회원권에서 차감이 일어나면 **차감은 허용하되 미수 배지를 고객 카드와 홈에 띄운다.** 차감을 막으면 현장이 마비되므로 **막지 말고 보이게** 하는 것이 맞다. 홈에 "미수금 N건 · 합계 M원" 한 줄을 두어 회수를 유도한다.

### E5. 중단·이탈한 견적(abandoned)의 수명

- **상황**: 상담 중 고객이 "생각해 볼게요"라며 나간다. 원장은 화면을 닫는다. 이런 견적이 매일 3~5건 쌓인다.
- **현행 결과**: `ProgramQuoteStatus.abandoned`는 enum과 DB CHECK에 정의돼 있으나(`lib/models/program_sales.dart:72`, `supabase/migrations/109_program_sales_os.sql:106-107`) **이 값을 쓰는 코드가 없다** — 앱이 쓰는 상태는 `presented`(`sori_store.dart:6517`)와 `accepted`(`sori_store.dart:6641`) 둘뿐이다. 따라서 비교 화면을 열 때마다 만들어진 견적은 `presented`로 영원히 남고, `program_quotes`는 **단조 증가하는 쓰레기 테이블**이 된다. 로드 시 전량을 shop 단위로 끌어오므로(`lib/data/supabase_sori_repository.dart:5595-5599`, LIMIT 없음) 1년 뒤 부팅이 느려진다.
- **리스크 등급**: **P1**
- **해결책**: 상태 전이 + 쿼리 — ① 비교 화면을 수락 없이 닫으면 견적을 `abandoned`로 전이시킨다. ② `loadProgramBoard`의 견적 조회에 `status='accepted' or created_at > now() - interval '7 days'` 필터와 LIMIT을 건다. ③ `112`에 90일 초과 `abandoned` 정리용 인덱스를 추가한다. 이탈 견적은 **버릴 데이터가 아니라 재상담 리드**이므로 삭제가 아니라 분리 보관이 맞다.

### E6. 분할 결제 · 계좌이체 대기 · 카드 승인 취소

- **상황**: 300만 원 패키지를 카드 150만 + 현금 100만으로 나눠 받고 나머지 50만은 다음 방문에 받기로 한다. 며칠 뒤 카드사에서 승인 취소가 난다.
- **현행 결과**: 결제는 `payable_krw`라는 **단일 정수**로만 존재하고(`supabase/migrations/109_program_sales_os.sql:105`), 회원권에도 `paidAmount` 정수 하나뿐이다(`lib/models/customer_membership.dart:22`). 여러 번에 나눠 들어온 돈, 수단별 내역, 취소된 승인을 표현할 자리가 전혀 없다. 원장은 "얼마 받았더라"를 카톡 기록에서 찾게 된다.
- **리스크 등급**: **P1**
- **해결책**: 스키마 — `113`의 `program_quote_payments`를 **입금 이벤트 원장(append-only)** 으로 설계한다. 행마다 금액·수단·시각·메모를 남기고, 취소는 음수 금액 행으로 기록해 이력을 보존한다. 견적의 `paid_krw`는 이 원장의 합계를 담는 파생 컬럼이며 트리거로 동기화한다.

### E7. 다중 회원권 동시 보유 시 차감 우선순위 + care_name 오연결

- **상황**: 한 고객이 "윤곽 관리 A코스"와 "윤곽 관리 B코스"를 동시에 보유한다. 오늘 시술의 차트 `care_name`은 "윤곽 관리"다.
- **현행 결과**: 차감 로직은 `memberships` 배열을 **앞에서부터 순회하며 첫 매칭을 깎는다**(`lib/services/sori_store.dart:7407-7427`). 매칭 규칙은 `a == b || a.contains(b) || b.contains(a)`인 느슨한 부분 문자열 비교라(`lib/models/customer_membership.dart:104-109`) "윤곽 관리"는 A코스·B코스 **양쪽에 모두 매칭된다.** 결과적으로 **배열 순서(= 구매 순서)라는 우연한 요인이 어느 지갑에서 돈이 빠지는지를 결정**한다. 만료 임박분 우선, 비싼 것 우선 같은 정책은 없고, 원장에게 선택권도 주지 않는다.
- **리스크 등급**: **P1**
- **해결책**: 스키마 + UI — ① `program_memberships`로 승격하면서 `expires_at`, `source_quote_id`, `package_snapshot_name`을 명시한다(`115`). ② 차감 정책을 **만료 임박 우선 → 잔여 적은 순 → 구매 오래된 순**으로 SSOT화한다. ③ 후보가 2개 이상이면 방문 확정 시 **"어느 회원권에서 차감할까요" 시트**를 띄운다. 자동 추론이 틀리면 돈 문제가 되므로, 모호할 때는 묻는 것이 옳다.

### E8. 태블릿 오프라인 상태에서의 견적 수락 (+ 판매 실적 귀속)

- **상황**: 상담실 와이파이가 끊긴 상태에서 원장이 [이 구성으로 등록]을 누른다.
- **현행 결과**: `acceptProgramQuote`는 원격 RPC 실패 시 `isMissingSchemaError`가 아니면 **그대로 rethrow한다**(`lib/services/sori_store.dart:6617-6627`). 네트워크 타임아웃은 스키마 오류가 아니므로 예외가 UI까지 올라오는데, 호출부인 `acceptProgramQuoteWithCustomer`에는 try/catch가 없다(`lib/features/program/program_accept.dart:15-18`). 따라서 **고객 앞에서 아무 일도 일어나지 않고 스낵바도 안 뜬다.** 견적은 로컬에서도 `accepted`가 되지 못하고, 원장은 방금 성사시킨 300만 원 계약을 처음부터 다시 입력해야 한다. 부수적으로, 판매자 귀속은 `author_id`가 견적 생성 시 기록되기는 하나(`sori_store.dart:6507`) 이를 집계·표시하는 화면이 전혀 없어 원장이 여럿인 샵에서 실적 배분이 불가능하다.
- **리스크 등급**: **P0** (오프라인 소실) / **P2** (실적 귀속)
- **해결책**: 상태 전이 + UI — ① 수락을 **로컬 우선(optimistic)** 으로 바꾼다. 로컬 회원권을 먼저 쓰고 원격 실패는 아웃박스 큐에 넣어 재시도한다. ② 실패 시 "오프라인 저장됨 · 연결되면 자동 동기화" 스낵바를 띄워 원장을 안심시킨다. ③ `program_quotes`에 `sold_by`(=`author_id` 승격)와 실적 집계 뷰를 만들어 월별 판매자별 매출을 조회 가능하게 한다.

---

## §4 스키마 설계안 (112~116, 실행 가능한 DDL + RLS)

> 공통 원칙 — 모든 신규 테이블은 `109`의 `public.program_shop_is_director(shop_id)`를 그대로 재사용한다. 새 보안 함수를 만들지 않는다.

### 112 — 프로모션 적용 범위 + 혜택 표현 확장

**왜 jsonb가 아니라 컬럼인가** — `scope`/`target_id`/`percent_off`는 **조회 조건과 산술의 대상**이다. 견적 화면은 "이 패키지에 걸린 혜택만" 인덱스로 걸러야 하고 퍼센트는 SQL에서 곱해야 하므로, jsonb에 넣으면 인덱스도 CHECK도 잃는다.

```sql
-- 112_program_promotion_scope_benefit.sql
-- PRD v7.2 — [적용 범위] + [혜택 종류] + [값] 키워드 조립 문법의 저장 형태.

alter table public.program_promotions
  add column if not exists scope text not null default 'global',
  add column if not exists target_id uuid,
  add column if not exists percent_off numeric(5,2) not null default 0,
  add column if not exists gift_qty int not null default 0,
  add column if not exists last_used_at timestamptz,
  add column if not exists use_count int not null default 0;

alter table public.program_promotions
  drop constraint if exists program_promotions_scope_check;
alter table public.program_promotions
  add constraint program_promotions_scope_check
  check (
    scope in ('global', 'category', 'package')
    and (scope = 'global') = (target_id is null)
  );

alter table public.program_promotions
  drop constraint if exists program_promotions_percent_check;
alter table public.program_promotions
  add constraint program_promotions_percent_check
  check (percent_off >= 0 and percent_off <= 100 and gift_qty >= 0);

-- kind 확장: 퍼센트 할인을 1급 종류로 승격
alter table public.program_promotions
  drop constraint if exists program_promotions_kind_check;
alter table public.program_promotions
  add constraint program_promotions_kind_check
  check (kind in (
    'extra_session', 'gift', 'instant_discount',
    'percent_discount', 'next_visit_credit'
  ));

comment on column public.program_promotions.scope is
  'global=샵 전체 자동 노출 / category·package=target_id 에 걸린 개별 혜택.';
comment on column public.program_promotions.percent_off is
  '정액 할인을 먼저 뺀 뒤 적용한다. list_price_krw 는 절대 갱신하지 않는다.';

create index if not exists program_promotions_scope_idx
  on public.program_promotions (shop_id, scope, target_id, is_active);
create index if not exists program_promotions_recent_idx
  on public.program_promotions (shop_id, last_used_at desc nulls last);

-- 부위 taxonomy (C1)
alter table public.program_categories
  add column if not exists body_part text not null default 'face';
alter table public.program_categories
  drop constraint if exists program_categories_body_part_check;
alter table public.program_categories
  add constraint program_categories_body_part_check
  check (body_part in ('face', 'body', 'scalp', 'etc'));

-- 이탈 견적 정리용 (E5)
create index if not exists program_quotes_status_idx
  on public.program_quotes (shop_id, status, created_at desc);

notify pgrst, 'reload schema';
```

- RLS: `program_promotions`·`program_categories`는 `109:189-193, 159-163`의 정책이 테이블 단위 `for all`이므로 **컬럼 추가만으로 그대로 상속된다. 신규 정책 불필요.**

### 113 — 결제 상태 + 입금 원장

**왜 jsonb가 아니라 테이블인가** — 분할 입금·승인 취소는 **행이 시간 순으로 늘어나는 이벤트**다(E6). jsonb 배열에 넣으면 부분 갱신 시 전체 문서를 다시 써야 하고 동시성 충돌이 난다. 합계는 파생 컬럼으로 캐시한다.

```sql
-- 113_program_payment_state.sql
-- PRD v7.2 — PG 없이 수기로 닫는다. '오늘 받을 돈'과 '실제 받은 돈'을 분리한다.

alter table public.program_quotes
  add column if not exists payment_status text not null default 'unpaid',
  add column if not exists paid_krw int not null default 0,
  add column if not exists paid_at timestamptz,
  add column if not exists sold_by uuid references public.profiles(id) on delete set null;

alter table public.program_quotes
  drop constraint if exists program_quotes_payment_status_check;
alter table public.program_quotes
  add constraint program_quotes_payment_status_check
  check (payment_status in ('unpaid', 'partial', 'paid', 'refunded'));

create table if not exists public.program_quote_payments (
  id          uuid primary key default gen_random_uuid(),
  quote_id    uuid not null references public.program_quotes(id) on delete cascade,
  amount_krw  int  not null,                 -- 음수 = 승인 취소/환불 이벤트
  method      text not null default 'cash'
              check (method in ('cash', 'card', 'transfer', 'etc')),
  note        text not null default '',
  received_by uuid references public.profiles(id) on delete set null,
  received_at timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create index if not exists program_quote_payments_quote_idx
  on public.program_quote_payments (quote_id, received_at);

comment on table public.program_quote_payments is
  'PRD v7.2 — append-only 입금 원장. 취소는 삭제가 아니라 음수 행으로 남긴다.';

-- 합계 동기화
create or replace function public.program_sync_quote_paid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote_id uuid := coalesce(new.quote_id, old.quote_id);
  v_sum int;
  v_due int;
begin
  select coalesce(sum(amount_krw), 0) into v_sum
    from public.program_quote_payments where quote_id = v_quote_id;
  select payable_krw into v_due
    from public.program_quotes where id = v_quote_id;

  update public.program_quotes
     set paid_krw = v_sum,
         paid_at = case when v_sum >= coalesce(v_due, 0) and v_sum > 0
                        then now() else null end,
         payment_status = case
           when v_sum <= 0 then 'unpaid'
           when v_sum >= coalesce(v_due, 0) then 'paid'
           else 'partial' end
   where id = v_quote_id;
  return null;
end $$;

drop trigger if exists program_quote_payments_sync on public.program_quote_payments;
create trigger program_quote_payments_sync
  after insert or update or delete on public.program_quote_payments
  for each row execute function public.program_sync_quote_paid();

alter table public.program_quote_payments enable row level security;

drop policy if exists program_quote_payments_director on public.program_quote_payments;
create policy program_quote_payments_director
  on public.program_quote_payments for all
  using (
    exists (
      select 1 from public.program_quotes q
      where q.id = quote_id
        and public.program_shop_is_director(q.shop_id)
    )
  )
  with check (
    exists (
      select 1 from public.program_quotes q
      where q.id = quote_id
        and public.program_shop_is_director(q.shop_id)
    )
  );

notify pgrst, 'reload schema';
```

### 114 — 고객 보유 쿠폰 (미래가치)

**왜 jsonb가 아니라 테이블인가** — 쿠폰은 **만료 배치와 교차 조회의 대상**이다. "이번 달 만료 예정 쿠폰 전부"를 뽑아야 하고 재방문 시 고객 단위로 즉시 조회해야 한다. `customers.memberships` 같은 jsonb 배열에 묻으면 이 두 질의가 전부 전체 스캔이 된다.

```sql
-- 114_program_customer_coupons.sql
-- PRD v7.2 — "다음 구매 시 20% 할인"이 증발하지 않게 만든다.

create table if not exists public.program_customer_coupons (
  id              uuid primary key default gen_random_uuid(),
  shop_id         uuid not null references public.shops(id) on delete cascade,
  customer_id     uuid not null references public.customers(id) on delete cascade,
  issued_quote_id uuid references public.program_quotes(id) on delete set null,
  promotion_id    uuid references public.program_promotions(id) on delete set null,
  title           text not null,
  percent_off     numeric(5,2) not null default 0,
  discount_krw    int  not null default 0,
  extra_visits    int  not null default 0,
  gift_qty        int  not null default 0,
  status          text not null default 'issued'
                  check (status in ('issued', 'used', 'expired', 'void')),
  issued_at       timestamptz not null default now(),
  expires_at      timestamptz,
  used_at         timestamptz,
  used_quote_id   uuid references public.program_quotes(id) on delete set null,
  created_at      timestamptz not null default now(),
  check (percent_off >= 0 and percent_off <= 100),
  check (status <> 'used' or used_at is not null)
);

create index if not exists program_coupons_customer_idx
  on public.program_customer_coupons (customer_id, status, expires_at);
create index if not exists program_coupons_shop_expiry_idx
  on public.program_customer_coupons (shop_id, status, expires_at);

comment on table public.program_customer_coupons is
  'PRD v7.2 — 발급된 미래가치. 회원권(횟수)과 별개 자산이며 상태 전이를 기록한다.';

alter table public.program_customer_coupons enable row level security;

drop policy if exists program_customer_coupons_director on public.program_customer_coupons;
create policy program_customer_coupons_director
  on public.program_customer_coupons for all
  using (public.program_shop_is_director(shop_id))
  with check (public.program_shop_is_director(shop_id));

-- 만료 전이 (스케줄러 또는 앱 부팅 시 호출)
create or replace function public.program_expire_coupons(p_shop_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare v_n int;
begin
  if not public.program_shop_is_director(p_shop_id) then
    raise exception 'not director of shop' using errcode = '42501';
  end if;
  update public.program_customer_coupons
     set status = 'expired'
   where shop_id = p_shop_id
     and status = 'issued'
     and expires_at is not null
     and expires_at < now();
  get diagnostics v_n = row_count;
  return v_n;
end $$;

grant execute on function public.program_expire_coupons(uuid) to authenticated;

notify pgrst, 'reload schema';
```

### 115 — 회원권 승격 (환불 · 업그레이드 · 차감 우선순위)

**왜 jsonb가 아니라 테이블인가** — 현행 `customers.memberships` jsonb는 append-only라 **환불·승계·소멸이라는 상태 전이를 표현할 수 없다**(E1, E2, E7). 돈이 오가는 자산은 행 단위 이력과 FK가 필요하다. 다만 기존 화면이 전부 jsonb를 읽으므로 **jsonb는 읽기 미러로 유지**하고 테이블을 진실로 삼는다.

```sql
-- 115_program_memberships.sql
-- PRD v7.2 — 회원권을 자산 테이블로 승격. customers.memberships 는 읽기 미러로 남긴다.

create table if not exists public.program_memberships (
  id                 uuid primary key default gen_random_uuid(),
  shop_id            uuid not null references public.shops(id) on delete cascade,
  customer_id        uuid not null references public.customers(id) on delete cascade,
  source_quote_id    uuid references public.program_quotes(id) on delete set null,
  service_name       text not null,
  total_visits       int  not null check (total_visits > 0),
  used_visits        int  not null default 0 check (used_visits >= 0),
  paid_krw           int  not null default 0,
  per_session_krw    int  not null default 0,
  status             text not null default 'active'
                     check (status in ('active','refunded','superseded','expired','void')),
  refunded_krw       int  not null default 0,
  refunded_at        timestamptz,
  refund_basis       text,
  superseded_by      uuid references public.program_memberships(id) on delete set null,
  credit_applied_krw int  not null default 0,
  expires_at         timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (used_visits <= total_visits)
);

create index if not exists program_memberships_customer_idx
  on public.program_memberships (customer_id, status, expires_at nulls last);
create index if not exists program_memberships_shop_idx
  on public.program_memberships (shop_id, created_at desc);

comment on column public.program_memberships.refund_basis is
  '소진분 정산 기준. list_unit=정가 회당, package_unit=패키지 회당. 분쟁 대비 기록.';
comment on column public.program_memberships.superseded_by is
  '업그레이드 승계 대상. 원본은 superseded 로 닫고 잔여가치를 credit 으로 넘긴다.';

alter table public.program_memberships enable row level security;

drop policy if exists program_memberships_director on public.program_memberships;
create policy program_memberships_director
  on public.program_memberships for all
  using (public.program_shop_is_director(shop_id))
  with check (public.program_shop_is_director(shop_id));

notify pgrst, 'reload schema';
```

### 116 — accept_program_quote v7.2 (결제 상태 · 쿠폰 · 회원권 테이블 통합)

**왜 RPC를 다시 쓰는가** — 회원권 발급, 쿠폰 발급, 결제 상태 기록, 프로모션 사용 카운트가 **하나의 트랜잭션**이어야 한다. 클라이언트에서 4번 나눠 호출하면 중간 실패 시 회원권만 있고 돈 기록은 없는 상태가 생긴다(E4의 재발).

```sql
-- 116_accept_program_quote_v72.sql
-- PRD v7.2 — 수락 = 회원권 + 쿠폰 + 결제상태를 한 트랜잭션으로 닫는다.

create or replace function public.accept_program_quote_v2(
  p_quote_id       uuid,
  p_customer_id    uuid,
  p_payment_status text default 'unpaid',
  p_paid_krw       int  default 0,
  p_method         text default 'cash'
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote    public.program_quotes;
  v_chosen   jsonb;
  v_visits   int;
  v_extra    int;
  v_paid_due int;
  v_unit     int;
  v_mid      uuid;
  v_promo    record;
begin
  select * into v_quote from public.program_quotes where id = p_quote_id for update;
  if not found then
    raise exception 'program_quote % not found', p_quote_id using errcode = 'P0002';
  end if;
  if not public.program_shop_is_director(v_quote.shop_id) then
    raise exception 'not director of shop' using errcode = '42501';
  end if;
  if p_customer_id is null then
    raise exception 'customer_id required' using errcode = '22023';
  end if;

  if v_quote.chosen_package_id is not null
     and (v_quote.snapshot -> 'right' ->> 'id') = v_quote.chosen_package_id::text then
    v_chosen := v_quote.snapshot -> 'right';
  else
    v_chosen := v_quote.snapshot -> 'left';
  end if;

  v_visits   := greatest(coalesce((v_chosen ->> 'visit_count')::int, 1), 1);
  v_paid_due := greatest(v_quote.payable_krw, 0);

  -- 횟수 추가 혜택만 회원권에 더한다. next_visit_credit 은 쿠폰으로 분기한다.
  select coalesce(sum(pr.extra_visits * coalesce(qp.qty, 1)), 0)
    into v_extra
    from public.program_quote_promos qp
    join public.program_promotions pr on pr.id = qp.promotion_id
   where qp.quote_id = p_quote_id
     and pr.kind <> 'next_visit_credit';

  v_visits := v_visits + coalesce(v_extra, 0);
  v_unit := case when v_visits > 0 then (v_paid_due / v_visits) else 0 end;

  insert into public.program_memberships (
    shop_id, customer_id, source_quote_id, service_name,
    total_visits, paid_krw, per_session_krw
  ) values (
    v_quote.shop_id, p_customer_id, p_quote_id,
    coalesce(v_chosen ->> 'name', 'Program'),
    v_visits, v_paid_due, v_unit
  ) returning id into v_mid;

  -- 읽기 미러 유지 (기존 화면 무중단)
  update public.customers
     set memberships = coalesce(memberships, '[]'::jsonb) || jsonb_build_array(
           jsonb_build_object(
             'id', v_mid::text,
             'service_name', coalesce(v_chosen ->> 'name', 'Program'),
             'total_visits', v_visits,
             'used_visits', 0,
             'paid_amount', v_paid_due,
             'per_session_value', v_unit
           ))
   where id = p_customer_id;

  -- 미래가치 쿠폰 발급
  for v_promo in
    select pr.*, coalesce(qp.qty, 1) as qty
      from public.program_quote_promos qp
      join public.program_promotions pr on pr.id = qp.promotion_id
     where qp.quote_id = p_quote_id
       and pr.kind = 'next_visit_credit'
  loop
    insert into public.program_customer_coupons (
      shop_id, customer_id, issued_quote_id, promotion_id, title,
      percent_off, discount_krw, extra_visits, gift_qty, expires_at
    )
    select v_quote.shop_id, p_customer_id, p_quote_id, v_promo.id, v_promo.title,
           v_promo.percent_off, v_promo.discount_krw, v_promo.extra_visits,
           v_promo.gift_qty, v_promo.valid_until
      from generate_series(1, v_promo.qty);
  end loop;

  -- 사용 이력 (S6)
  update public.program_promotions pr
     set use_count = pr.use_count + 1, last_used_at = now()
    from public.program_quote_promos qp
   where qp.quote_id = p_quote_id and pr.id = qp.promotion_id;

  -- 수기 결제 기록
  if p_paid_krw > 0 then
    insert into public.program_quote_payments (quote_id, amount_krw, method)
    values (p_quote_id, p_paid_krw, p_method);
  end if;

  update public.program_quotes
     set customer_id = p_customer_id,
         status = 'accepted',
         accepted_at = now(),
         payment_status = case
           when p_paid_krw >= v_paid_due and p_paid_krw > 0 then 'paid'
           when p_paid_krw > 0 then 'partial'
           else p_payment_status end
   where id = p_quote_id;

  return jsonb_build_object('quote_id', p_quote_id, 'membership_id', v_mid);
end $$;

grant execute on function
  public.accept_program_quote_v2(uuid, uuid, text, int, text) to authenticated;

comment on function public.accept_program_quote_v2(uuid, uuid, text, int, text) is
  'PRD v7.2 — 회원권·쿠폰·결제상태·사용이력을 한 트랜잭션으로 닫는다. v1 은 호환용 유지.';

notify pgrst, 'reload schema';
```

- **v1 함수는 삭제하지 않는다.** 구버전 앱이 남아 있을 수 있으므로 `accept_program_quote`는 그대로 두고 클라이언트가 `_v2`부터 시도한 뒤 스키마 오류 시 폴백한다 — `upsertProgramPackage`가 이미 쓰고 있는 패턴이다(`lib/data/supabase_sori_repository.dart:5702-5716`).

---

## §5 구현 슬라이스 (R1~R9)

| 슬라이스 | 내용 | 완료 판정 테스트 |
|---|---|---|
| **R1** | 구성 입력 4종화 — 패키지 시트의 구성 행을 `[종류]+[내용]+[분]`으로 확장, `ProgramLineKind.labelKo` 추가, `perk` 하드코딩 제거 | 편집 시트에서 '관리 내용/20분'으로 저장한 패키지를 비교 화면에서 열면 '1. 고주파 온열 20분'과 '시간 합 20분'이 함께 렌더된다 |
| **R2** | 단건 요약 화면 — `ProgramQuotePage` 신설, 하단 클로징 3종 공용 위젯 추출, `presentProgramQuote` 단건 모드 허용 | 패키지 1개만 체크한 뒤 CompareDock의 [이 구성으로 진행]을 누르면 프로모션 버튼과 결제액이 있는 요약 화면이 뜬다 |
| **R3** | Freeze 후 추가 선택 — 단건 요약에 [비교 대상 추가], 3번째 체크 시 슬롯 교체 UI | 1택 진행 → [비교 대상 추가] → 2번째 선택 시 첫 선택의 스냅샷 정가가 그대로 유지된 채 비교 화면이 열린다 |
| **R4** | 마이그레이션 `112` + 프로모션 3단 조립기 — scope/target, percent_off, gift_qty, extra_visits 수량 입력, 미리보기 문장 | '윤곽 A패키지 / 횟수 +3회'로 저장한 혜택이 웨딩 패키지 견적의 프로모션 시트에는 나타나지 않는다 |
| **R5** | 전체 프로모션 자동 노출 — collapsed 앵커 아래 global 혜택 1줄, 시트 2단 분리 | `scope='global'` 혜택 1건이 있을 때 카테고리 카드 접힌 상태에서 혜택 캡션 1줄이 보이고, 배너·색상 강조는 렌더되지 않는다 |
| **R6** | 마이그레이션 `113` + 확정 시트 — 결제 상태 토글·수단 칩, 신규 고객 퀵 생성 CTA | 미결제로 등록한 견적이 `payment_status='unpaid'`로 저장되고, 검색 결과 없는 이름으로 신규 고객을 만들어 그 자리에서 회원권이 발급된다 |
| **R7** | 마이그레이션 `114`+`116` + 쿠폰 UI — `next_visit_credit` 발급, 고객 차트 미사용 쿠폰 배지 | '다음 구매 20% 할인'을 붙여 수락하면 회원권 횟수는 늘지 않고 고객 차트에 미사용 쿠폰 1건이 표시된다 |
| **R8** | 마이그레이션 `115` + 회원권 테이블 전환 — 환불·승계·차감 우선순위 시트, jsonb 미러 동기화 | 만료 임박 회원권과 일반 회원권을 동시 보유한 고객의 방문 확정 시 차감 대상 선택 시트가 뜨고, 선택한 쪽만 `used_visits`가 증가한다 |
| **R9** | 견적 수명·오프라인 내구성 — `abandoned` 전이, 로드 필터+LIMIT, 낙관적 수락과 아웃박스 재시도 | 네트워크를 끊은 상태에서 [등록]을 눌러도 로컬 회원권이 즉시 발급되고 '오프라인 저장됨' 안내가 뜨며, 재연결 시 원격에 1건만 동기화된다 |

- 권장 순서는 **R2 → R6 → R7 → R1 → R4 → R5 → R3 → R9 → R8**이다. 매출 손실을 직접 막는 단건 경로(R2)와 수금·쿠폰(R6·R7)이 먼저이고, 이관 비용이 가장 큰 회원권 테이블 전환(R8)은 나머지가 안정된 뒤가 안전하다.

---

## §6 PO 결정 요청 (Q1~Q6)

**Q1 — 단건 요약 화면을 새 화면으로 만들 것인가, 비교 화면의 1열 모드로 만들 것인가**
- (a) `ProgramQuotePage` 신설 — 단건 전용 레이아웃, 하단 클로징만 공유
- (b) `ProgramComparePage`에 `right == null` 1열 모드 추가 — 화면 1개로 통합
- **권고: (a).** 근거 — 현행 비교 화면은 `quote.left`/`quote.right`를 **비-null로 전제**하고 `_DeltaLine`이 두 값의 차이를 문장으로 만든다(`program_compare_page.dart:460-471`). 1열 모드를 끼워 넣으면 이 위젯 전체가 null 분기로 오염된다. 화면을 나누되 클로징 3종만 공용화하는 쪽이 회귀 위험이 낮다.

**Q2 — 회원권을 테이블로 승격할 것인가, jsonb를 유지할 것인가**
- (a) `program_memberships` 테이블로 승격, `customers.memberships`는 읽기 미러
- (b) jsonb 유지 + 필드 추가(`status`, `refunded_krw`)로 최소 대응
- **권고: (a).** 근거 — 환불·업그레이드 승계·차감 우선순위(E1·E2·E7) 셋 모두 **행 단위 이력과 FK**를 요구한다. jsonb에 상태를 넣으면 "3회 쓰고 환불한 티켓"을 다른 샵·다른 기간과 교차 집계할 수 없어 정산이 영원히 수기로 남는다. 다만 기존 화면이 전부 jsonb를 읽으므로 미러를 유지해 **무중단 전환**한다.

**Q3 — 미결제 상태에서 회원권 차감을 막을 것인가**
- (a) 차감은 허용하되 미수 배지를 띄운다 (경고형)
- (b) 차감을 차단하고 원장 확인 후에만 진행 (차단형)
- **권고: (a).** 근거 — 현장에서 시술은 이미 끝났고 돈은 나중에 온다. 차단하면 원장이 "미결제"를 안 찍고 넘어가는 우회를 학습하게 되어 데이터가 더 나빠진다. **막지 말고 보이게 하는 것**이 수기 체크 문화에 맞다.

**Q4 — 퍼센트 할인과 정액 할인의 적용 순서**
- (a) 정액 먼저 빼고 남은 금액에 퍼센트 (샵에 유리, 할인 총액 작음)
- (b) 퍼센트 먼저 적용하고 정액을 뺀다 (고객에 유리, 할인 총액 큼)
- **권고: (a).** 근거 — 프로모션 스택은 최대 9장까지 겹칠 수 있으므로(`ProgramPromoStack.maxQtyPerPromo`, `program_sales.dart:144`) 순서를 잘못 잡으면 **결제액이 0에 수렴하는 사고**가 난다. (a)가 방어적이며, `ProgramPricing.payable`이 이미 음수를 0으로 클램프하는 방향(`program_sales.dart:94-98`)과 일관된다. 단, 선택한 순서는 Dart와 SQL 양쪽에 **동일하게** 못 박아야 한다.

**Q5 — 이탈 견적의 보존 기간**
- (a) 90일 보존 후 자동 `void` — 리드로 재활용 가능
- (b) 당일 자정 일괄 `abandoned` 후 30일 뒤 삭제 — 테이블 경량 유지
- **권고: (a).** 근거 — "생각해 볼게요"는 실패가 아니라 **재상담 리드**다. 90일이면 계절 상품 1주기를 덮고, 인덱스(`112`의 `program_quotes_status_idx`)와 로드 LIMIT만 있으면 성능 부담도 없다. 삭제는 되돌릴 수 없으므로 기본값을 보존으로 둔다.

**Q6 — 부위(body part) taxonomy를 필터로 노출할 것인가**
- (a) 카테고리 속성으로만 저장하고 UI 필터는 이번 스프린트에서 보류
- (b) 상단 부위 세그먼트 칩 행을 즉시 노출
- **권고: (a).** 근거 — 현재 카테고리는 데모 기준 2개(윤곽·웨딩)뿐이다(`program_sales.dart:1011-1023`). 카테고리가 3~4개인 샵에서 부위 필터는 **빈 화면만 늘리는 UI**다. 컬럼은 `112`에서 미리 넣어 데이터를 축적하고, 카테고리가 8개를 넘는 샵이 나오면 그때 (b)로 켠다. 스키마는 미리, UI는 필요할 때가 원칙이다.

---

*작성: Expert Lead Engineer & UX/UI Architect · 코드 무수정 원칙 준수 (`lib/` 변경 0줄, 마이그레이션 파일 생성 0건)*
