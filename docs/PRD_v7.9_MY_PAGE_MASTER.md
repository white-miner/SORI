# PRD v7.9 MASTER — 마이페이지 · 홈 스케줄 · 사장 책상 (총기획)

**Status:** **Approved** (2026-09-11 · PO Yes×3 + §16.11 가드)  
**PO:** 마인드  
**작성:** Cursor (2026-09-11)  
**입력:** Brief · P1–P7 · Claude · Perplexity C1–C5 · inventory · SaaS 재평가 · Approved 전 가드 보강 · CONTRACTS
  

> **제품 계약 Approved.** `lib/` 구현은 **Phase별 명시 승인** 후에만.  
> Phase PR: ≤5파일 · §16.8 F Timer 경로 금지 · §16.11 가드 위반 시 롤백.

---

## 0. 한 줄

소리는 소셜 앱이 아니다.  
**홈 스케줄면**은 주간 glance·빠른 메모, **홈·Timer**는 케어 플립시계 SSOT,  
**마이·사장 책상**은 사후 업무·고객·경영·자산,  
**커뮤니티·공개 프로필**은 신뢰·공유·전환 면이다.

---

## 1. 잠금 요약

| 주제 | 잠금 |
|------|------|
| IA | 안 A · 사장 책상 기본 진입 · 공개면은 미리보기 CTA |
| 책상 탭 | 오늘 · 고객 · 경영 · 자산 · 더보기 (AI·세미나운영·설정→더보기) |
| 홈 스케줄면 | 주간 스트립 · 오늘 하이라이트 · 빠른 메모 · **플립시계 없음** |
| 홈 Timer | **플립시계 필수** · `VisitTimerStore` → `HomeTimerStage` / `FlipClockDisplay` |
| 스케줄 SSOT | `care_schedule`(+TodayAgenda) **단일** · 홈=읽기 glance · 마이=CRUD |
| 마이 오늘 | **업무 큐 위** · **스케줄 상세 아래** · 타이머 UI 없음 |
| 빠른 메모 | 홈=1줄 미리보기 · 마이=편집 · MVP=`CareScheduleEntry.note` · SOAP/고객메모 자동복제 금지 |
| 기록 완료(큐) | `visitChecked && hasSummary` · 사진 비필수 · **결제 큐 보류**(Payment SSOT 전) |
| 경영 | 5 ZONE + `지금 확인할 일` 공통 레이어 · ★시간당 수익 · 인사이트≠큐 · peek≤1 |
| 금액 | A 들어온 돈 ≠ B 선불 잔여·미수행 |
| B/A | 내부 → 동의·검토 → **커뮤니티 공개** · **프로필 쇼케이스 대표 max 5**(커뮤니티 총량 제한 아님) |
| CTA | `naverBookingUrl`/`Place` 수동 등록 시 예약하기 · 아니면 문의 |
| 알림 | 기록·일정변경·재방문·선불 활성 · `payment_missing` 페이로드 **비활성** · 폴백=마이 오늘 큐 · 홈 go 금지 |
| Visit | ≈ `customer_charts` · 딥링크는 chartId/scheduleId |
| 기술 | Expand only · 삭제·리네임 금지 · PR≤5파일 |
| UI | `docs/PRD_v7.9_UI_UX_BRIEF.md` · 검수 3문항 · Phase별 Acceptance |
| 단서(Approved) | ①결제 큐=후속 Payment PRD ②대표5=프로필만 ③Peek 하드가드 |
| Approved 가드 | §16.11 세 문장 (visitChecked 비자동 · no_show 비가정 · payment_missing 후속만) |

---

## 2. 성공 기준

### 2.1 원장 10초 / 30초

| 시간 | 성공 |
|------|------|
| 10초 (마이 오늘) | 가장 급한 미완료(기록/결제/일정요청) 또는 “처리할 일 없음”+오늘 일정 |
| 30초 | 해당 객체 열기 · 또는 경영 한 줄→대시보드 · 또는 내 샵 미리보기 |
| 홈 스케줄면 | 이번 주·오늘 중요 일정 파악 · (가능 시) 다음 일정에서 케어 시작 |
| Timer | 진행 중/시작 후 **구간 잔여 플립시계**가 1초로 움직임 |

### 2.2 고객 (Phase 후순위 · 최소)

다음 예약 · 회원권/잔액 · 내 방문 공개 요약 · 후기/문의 · **운영 BI 비노출**

---

## 3. 표면 역할 분담

| 표면 | 질문 | 넣음 | 넣지 않음 |
|------|------|------|-----------|
| 홈 스케줄면 | 이번 주·오늘 뭐가 있지? | 주간 스트립, 오늘 2~3건, 빠른 메모, 케어 시작 CTA | Day/Week CRUD, 플립시계, 경영 차트 |
| 홈 Timer | 지금 케어 구간이 얼마 남았나? | 플립시계, 구간 리스트, 케어 컨트롤 | 주간 CRUD, 업무 큐, 프로필 |
| 마이 오늘 | 남은 운영 일·일정 관리 | 업무 큐, 일/주 스케줄 CRUD, 고객 연결 | 플립시계, 피드, 상권 ZONE3 |
| 경영 | 흐름·원인·다음 행동 | 5 ZONE + 행동 레이어 | 타이머, 일정 CRUD 전체 |
| 공개 프로필 | 믿을 만한 샵인가? | 소개, 대표 B/A, 후기, 세미나 쇼케이스, 문의/외부예약 | 매출, SOAP, 미완료 업무 |
| 커뮤니티 | 업계·동료와 무엇을 나누나? | 공개 B/A·세미나 등 (v7.8) | 사장 책상 운영 UI |

---

## 4. 스케줄 SSOT · 홈 ↔ 마이 (P1)

### 4.1 계약

```
care_schedule (SSOT)
 ├─ 홈 glance …… 읽기 · 주간 스트립 · 오늘 하이라이트 · 빠른 메모(일정 선택 후)
 └─ 마이 오늘 …… 일/주 · CRUD · 고객 연결 · 상태 · Visit/케어 진입
```

금지: 홈·마이에 **별도 스케줄 테이블/스토어** 신설.  
기존 후보 재사용: `care_schedule_entries`, `TodayAgenda`, `home_scheduler_strip`.

### 4.2 홈 glance에 보일 것 / 안 보일 것

| 보임 | 안 보임 |
|------|---------|
| 주간 7일 · 오늘 강조 · 당일 중요 2~3건 · 상태 점 · 빠른 메모 · 다음 일정 `케어 시작` | Day/Week 전환 · 생성/삭제/드래그 · 반복 규칙 · 고객 전체 이력 · 결제 상세 · 플립시계 |

### 4.3 빠른 메모 (P2)

- 기본: **선택된 care_schedule의 schedule_note**  
- 일정 미선택 시: 일정 먼저 고르게 함 · **무소속 메모 자동 생성 금지**  
- 고객 메모로 옮기려면 **명시적 선택**만  
- SOAP/차트 기록과 **별도 객체** · 완료 일정 메모는 참고만 · 업무 큐 자동 승격 금지  
- 샵 공용 스크래치: **v7.9 비범위**

---

## 5. 케어 시작 · Timer 연결 (P3 · L1)

| 시작 | CTA | 결과 |
|------|-----|------|
| 홈 다음 일정 | 케어 시작 | Timer 탭 · 해당 schedule/고객 문맥 세션 |
| 마이 일정 상세 | 케어 시작 | 동일 |
| 이미 활성 세션 | 진행 중인 케어 보기 | 기존 세션 · **새 타이머 자동 생성 금지** |
| 완료/취소 일정 | 기록 보기 등 | 케어 시작 비노출 |

**오작동 방지**

1. 활성 세션의 customer/schedule ≠ 선택 일정이면 확인 시트 먼저.  
2. 기본 CTA=`진행 중인 케어 보기` · `종료 후 시작`은 명시 확인 후.  
3. 플립시계·틱 UI는 **Timer 탭만**. 마이/스케줄면에 숫자·조작 복제 금지.

---

## 6. 사장 책상 · 마이 오늘 (P4 · L2)

```
AppBar: [내 샵 미리보기] [알림] [설정]
오늘
 ├─ 업무 큐 (최대 3 · sticky 금지)
 │    순서: 기록미완료 → 결제누락 → 일정변경요청 → 재방문 → 선불만료
 ├─ (큐 없음) 한 줄 빈상태 → 스케줄이 사실상 첫 콘텐츠 OK
 └─ 스케줄 상세 (일/주 · CRUD · 고객 연결)
경영 한 줄 / AI 카드: 큐·스케줄 아래 또는 저우선
```

빈 큐 카피(권고 A): `지금 처리할 일이 없어요. 오늘 일정을 확인해 보세요.` → `오늘 일정 보기`

책상 내부 탭: **오늘 · 고객 · 경영 · 자산 · 더보기**  
기존 6탭 body(Home/경영/Shop/Asset/Seminar/AI) **삭제·리네임 금지** · 새 셸에서 재배치.

---

## 7. 경영 · 금액 (v7.6 + Brief)

```
ZONE 1 이번 기간의 결론 …… ★시간당 수익 · 진짜영업이익(보조) · 상권은 ZONE3
ZONE 2 돈의 구조 …… 워터폴 · BEP
ZONE 3 시장·상권 참고 …… 공공 · 마이 오늘에 올리지 않음
ZONE 4 고객 자산
ZONE 5 시간·캐파
공통  지금 확인할 일 …… 제6 ZONE 아님
```

| 카드 | 의미 | 금지 |
|------|------|------|
| A 들어온 돈 | 기간 성공 Payment − 환불 등 · 선불 **판매 수납** 포함 시 라벨 명시 | 잔여 횟수를 매출에 합산 |
| B 아직 제공할 선불 | 잔여 횟수/잔액 · 미수행 금액 | A와 한 숫자로 합치기 |

세무: 운영 참고용 추정치 · 장부와 다를 수 있음 고지.

마이 오늘 한 줄: **A(+B 보조)** · 경영 상세 ★는 **시간당 수익**.

---

## 8. 공개 프로필 · CTA · B/A (P6)

### 8.1 CTA

| 설정 | 주 | 보조 |
|------|----|------|
| booking/place URL | 예약하기(외부) | 문의 |
| 전화만 | 전화 문의 | 공유 |
| 없음 | 준비 중(원장 설정) | 공유 |

자동 스크래핑 금지. 깨진 URL → 문의 폴백.

### 8.2 B/A

```
INTERNAL → CANDIDATE → CONSENTED_REVIEW → PUBLISHED_TO_COMMUNITY
                                      ↘ 프로필 미러(대표만 명시 선택)
```

- 원본 1 · 커뮤니티/프로필은 참조  
- 커뮤니티 카드에 예약 CTA 중복 금지  
- 프로필 CTA는 샵 단위 예약/문의 1개  
- 철회·비공개 시 양면 동시 비노출  

---

## 9. 알림 MVP 5 (P5)

| # | 이름 | 트리거 | 딥링크 |
|---|------|--------|--------|
| 1 | 기록 미완료 | chart/Visit 미완료 | 해당 chart |
| 2 | 결제·선불 누락 | **v7.9 페이로드 비활성** (Payment SSOT 후속 PRD) | — (슬롯만 유지) |

| 3 | **SORI 일정 변경** | care_schedule 취소·시간변경 · 또는 원장 `고객 요청` 메모 | schedule 상세 · **홈 금지** |
| 4 | 재방문 확인 | 기준일 초과 | 고객 필터 목록 |
| 5 | 선불 만료 임박 | 잔여>0 · 만료 임박 | 해당 credit |

외부 네이버/카카오 변경: **알림·자동반영 약속 금지** · 설정 시 1회 고지.

---

## 10. Expand Phase (P7) · 구현은 Approved 후

| Phase | 목적 | 성공 기준 | 절대 금지 |
|-------|------|-----------|-----------|
| 0 | 기준선·계측 | 홈/마이/Timer/일정 경로 문서화 | Timer SSOT 삭제 |
| 1 | 스케줄 읽기 전용 이중 밀도 | 한 일정 상태가 홈·마이에 일치 | CRUD·Timer 변경 |
| 2 | 마이 업무 큐 | 카드→정확 딥링크 | 홈 시술 UI·ZONE body |
| 3 | 마이 스케줄 CRUD | 생성·수정이 홈 glance에 반영 | 외부 예약 자동동기화 |
| 4 | 일정→케어 시작 | 다른 고객 세션 시 확인 시트 | 플립시계 위치 변경 |
| 5 | B/A 미러·외부 CTA | 철회 시 양면 숨김 · URL 폴백 | 내부 B/A 기본 공개 |
| 6 | 안정화·계측 | 30초 과업·알림 검증 | 6탭 body 일괄 삭제 |

비범위: 직원·멀티지점·자동메시지·자동환불·AI 자율실행·외부 예약 webhook·샵 스크래치 메모 ·  
`care_schedule`에 **`no_show` enum Expand** · Peek→자동 큐/알림/메시지 · `payment_missing` 활성 · Timer에 scheduleId 강제 추가.

PR 계약: **≤5파일** · §16.8 F Timer 경로 손대지 않음.

---

## 11. 소리 코드 매핑 (구현 시 Cursor 책임)

| 기획 용어 | 현실 |
|-----------|------|
| Visit | `customer_charts` (+ visit_sessions) |
| care_schedule | `care_schedule_entries` 등 기존 |
| 미완료 | §16.1 · `visitChecked && !hasSummary` · 결제 큐 보류 · no_show 자동예외 금지 |
| Timer | `VisitTimerStore` · tear-off `_onTick` 금지 |
| 예약 URL | `Shop.naverBookingUrl` / `naverPlaceUrl` / phone |

---

## 12. Perplexity 잔여 Yes/No — Cursor 권고 (PO 확인)

| # | 질문 | Cursor 권고 |
|---|------|-------------|
| 1 | 빠른 메모=일정 전용? | **Yes** |
| 2 | 빈 큐→스케줄이 첫 콘텐츠? | **Yes** |
| 3 | 일정 변경 알림=내부+요청메모만, 외부 자동반영 없음? | **Yes** |
| 4 | 홈 glance / 마이 CRUD · 동일 SSOT? | **Yes** |
| 5 | 프로필 미러=대표만 · 철회 시 동시 숨김? | **Yes** |

§12는 구 Perplexity 잔여. **제품 잠금 SSOT는 §16.7** (PO Yes 5 + 단서 3).

---

## 13. Claude 평가 요청문 (복붙)

```
[SORI v7.9 총기획 평가 요청]

역할: 제품/IA 비평가. 코드·위젯 구현 금지.
문서: docs/PRD_v7.9_MY_PAGE_MASTER.md
Status: Draft · Approved 아님 · 구현 금지

절대 전제(위반 시 즉시 지적):
- 홈·Timer 탭 플립시계 유지 (VisitTimerStore SSOT)
- 홈 스케줄면에 플립시계 없음
- 마이 오늘 = 업무 큐 위 + 스케줄 상세 아래
- 스케줄 SSOT 단일 (care_schedule)
- Expand only · Visit ≈ customer_charts
- 외부 네이버/카카오 예약 변경 자동반영 약속 금지
- 6탭 BI 통째 교체 금지 · 커뮤니티 IA(v7.8)와 섞어 리라이팅 금지

평가해 줄 것:
1) 논리적 모순·이중 OS·홈/마이/Timer 충돌
2) Phase 0–6 순서의 위험·누락
3) 빠진 계약(동의·금액 A/B·알림·딥링크·미완료 정의)
4) 반대하는 조항과 대안 1줄씩
5) Approved 전 PO Yes/No로 닫을 질문 최대 5개

톤: 짧고 솔직. 예쁜 SNS 리디자인·직원/멀티지점 제안 금지.
끝에 “평가 Draft · Approved 아님” 명시.
```

---

## 14. 변경 로그

| 날짜 | 내용 |
|------|------|
| 2026-09-11 | Skeleton |
| 2026-09-11 | Perplexity P1–P7 흡수 · Claude 평가용 총기획 |
| 2026-09-11 | Claude 평가 흡수 §15 · 후속 Perplexity 요청서 분리 · **구현 금지** |

---

## 15. Claude 평가 흡수 (2026-09-11) · Cursor 판정

**원문 요지:** Pass(절대전제) · 위험 5 · 계약 공백 3 · 역할 재검토 3 · PO Q1–Q5.

### 15.1 Cursor 즉시 채택 (조사 불필요 · MASTER 보완 후보)

| Claude | Cursor 판정 |
|--------|-------------|
| 홈·마이 주간 범위: 홈=고정 주간 · 마이 날짜 이동이 홈을 끌지 않음 | **채택** → §4.1에 넣을 문장 |
| 큐 vs 지금 확인할 일: 실행 vs 인지 | **채택** |
| 알림 deeplink 홈 우회 · 마이 직진 | **채택** · 경로 표기는 Perplexity C4 + 라우터 inventory |
| Timer 세션 전역 확인 시트 (홈↔마이 이중 시작) | **채택** · §5 강화 (기존 P3와 동일 계열) |
| 마이 “진행 중” 배지 → Timer 직진 | **채택** (Option B) |
| ZONE3 상권은 경영만 · 마이 peek는 매출/행동만 | **채택** |

### 15.2 Cursor 잠금 (스키마 inventory 후 · §16.1 SSOT)

소리 `customer_charts` 현실: `visitChecked` · `beforeImageUrl`/`afterImageUrl` · `treatmentSummary`/`directorInsight` (별도 SOAP 4필드 테이블 아님). **차트 Payment FK · `paymentNotRequired` 없음.**

| 상태 | 정의 (§16.1 · PO 잠금) |
|------|----------------|
| 기록 미완료(큐) | `visitChecked == true` AND `hasSummary == false` |
| 부분 완료 | **MVP 상태값 없음** · 스키마에 draft 필드 없으면 별도 상태 금지 |
| 결제 누락 | **보류** · “불필요”가 아니라 Payment SSOT·차트 FK 전 정직한 범위 통제 |

Claude의 `visit_checked ∧ 사진 ∧ SOAP` **엄격 AND는 폐기.** 상세는 §16.1.

### 15.3 Claude 제안에 대한 Cursor 기울기

| 항목 | Claude | Cursor |
|------|--------|--------|
| 빈 큐 UX | Option B(섹션 헤더 분리) | **채택 기울기** · PO Q3 |
| 경영 peek | Option B(위험 1줄→대시보드) | **채택 기울기** · 큐와 섞지 않음 · PO Q4 |
| 빠른 메모 | 홈 읽기·마이 편집 | **채택** · PO Q2 · UI 상세는 C2 |
| 대표 B/A 개수 | 최대 3 예시 | **프로필 쇼케이스 max 5** (커뮤니티 총량 아님) |
| CONSENTED_REVIEW 미구현 | 비범위 가능 | **상태 enum Expand만 · 워크플로 단순화 가능** |

### 15.4 다음 파이프라인 (갱신)

```
1) Status = **Approved** · §16.11 · UI BRIEF ✅ · Phase 1 AC 8항 잠금 ✅
2) Phase 1 = **PO 승인 대기** (한정 문구 §17.2)
3) 승인 후 lib/ ≤5파일 · Timer 격리
```

**구현 금지.**

---

## 16. Perplexity C1–C5 흡수 · **구현 가능 계약** (Cursor)

**전제:** Claude 재평가(“진단만 있다 / 문서 미저장”)에 대해 — 본 파일은  
`docs/PRD_v7.9_MY_PAGE_MASTER.md` 에 저장됨. 아래는 **Yes면 코드로 무엇을 짜는지**까지 내린 계약.  
**구현은 여전히 금지** · Status=Approved 후보 · 정식 Approved + Phase 승인 후에만 `lib/`.

### 16.0 소리 식별자 (딥링크·큐 공통)

| 기호 | 의미 | 현실 |
|------|------|------|
| `chartId` | Visit ≈ 차트 | `customer_charts.id` |
| `scheduleId` | 일정 | `care_schedule_entries.id` (기존) |
| `customerId` | 고객 | `customers.id` |
| `taskType` | 큐/알림 종류 | enum 문자열 아래 표 |

**Expand 경로 (신규 · 기존 라우트 삭제 없음):**

```
/app/my?desk=today&task=<taskType>           ← 작업 큐 포커스
/app/my?desk=today&schedule=<scheduleId>     ← 일정 상세
/app/my?desk=today&chart=<chartId>&step=record|payment
/app/my?desk=customers&customer=<id>&focus=credits|followup
/app/biz-dashboard#zone=<1-5>                ← peek 착륙 (기존 경로 유지·해시 Expand)
```

알림·큐 CTA는 위 쿼리만 사용. **`/app/home` · Timer 인덱스를 착륙점으로 쓰지 않음.**

---

### 16.1 기록 미완료 — **불리언 계약** (C1) · **스키마 inventory 반영**

#### 16.1.0 Inventory 결과 (2026-09-11 · 코드/마이그레이션 확인 · 구현 아님)

| 항목 | 결과 | 근거 |
|------|------|------|
| `visit_checked` | **있음** | `customer_charts` · `CustomerChart.visitChecked` |
| `before_image_url` / `after_image_url` | **있음** | 동일 |
| `treatment_summary` / `director_insight` | **있음** | 동일 |
| `payment_not_required` | **없음** | 전 repo grep 0건 · Expand 전제만 존재했음 |
| 차트 FK Payment row | **방문 차트에 없음** | `visit_trigger_service`: 「결제 테이블 연동 없이 visit_checked」· 회원권은 `customers.memberships` / tickets **차감** (차트 row에 결제 이력 FK 없음) |
| `program_quote_payments` | 프로그램 견적용 | 방문 기록 큐와 **분리** |
| `care_schedule.status` | `scheduled` \| `completed` \| `cancelled` | **`no_show` 없음** (096 + enum) |
| `care_schedule.note` | **있음** (text) | 빠른 메모 MVP는 **기존 note 필드** 가능 · 이력 테이블은 후속 Expand |

#### 헬퍼 (의사코드 · **MVP = 스키마에 있는 것만**)

```
hasSummary(c) :=
  trim(c.treatmentSummary).isNotEmpty
  OR trim(c.directorInsight).isNotEmpty

hasPhoto(c) :=
  nonEmpty(c.beforeImageUrl) OR nonEmpty(c.afterImageUrl)
  // 완료 조건 제외 · UX 권고만

// ❌ v7.9 Phase 2에서 쓰지 않음 (필드·차트결제 FK 없음):
// paymentOk / paymentNotRequired

requiredComplete_MVP(c) := hasSummary(c)
  // Q1 개정: 옵션 A의 “결제 포함”은 스키마 준비 전 잠금 불가
  // → 옵션 B' (기록 우선)로 Phase 2 잠금

isCancelledSchedule(s) := s.status == cancelled
isFutureSchedule(s) := s.scheduledAt > now AND s.status == scheduled
// no_show: v7.9 비범위 (enum Expand 후)
```

#### 큐 판정 · Q1 상태 계약 (Phase 2 · PO 잠금)

| 상태 | v7.9 판정 | 큐 노출 | 비고 |
|------|-----------|--------:|------|
| 방문 미확인 | `visitChecked = false` | 아니오 | 미래 일정 · Timer 종료 · postCare 도착 포함 가능 |
| 기록 미완료 | `visitChecked && !hasSummary` | **예** | 마이 오늘 1순위 |
| 기록 완료 | `visitChecked && hasSummary` | 아니오 | 사진·결제 **비포함** |
| 일정 취소 | `care_schedule.status = cancelled` | 아니오 | Visit 완료로 환산 금지 |
| 일정 완료 | `care_schedule.status = completed` | 자동판정 금지 | **`visitChecked`와 상호 자동 동기화 금지** |
| 노쇼 | 정의 불가 | 자동 예외 금지 | 표시·추정·자동 제외 **금지** |

```
기록미완료(chart c):
  c.visitChecked == true AND hasSummary(c) == false

기록완료(c):
  c.visitChecked == true AND hasSummary(c) == true

부분완료 / hasSummaryDraft: MVP 상태값 없음 → 만들지 않음

결제·회원권 누락 큐 (payment_missing):
  v7.9 = 보류 · 재개 = 후속 Payment PRD (§16.11 · §16.10)

상호 비동기화:
  care_schedule.status=completed 와 visitChecked=true 는 동시 존재 가능
  한쪽이 다른 쪽을 자동 갱신하지 않음
```

**가드 (필수):**  
`care_schedule` 완료, Timer 종료, postCare 도착은 `visitChecked`를 자동 변경하지 않는다.  
기록 미완료 큐의 **유일한 입구**는 명시적 `visitChecked`다.  
care_schedule 종료 · Timer 종료 · postCare 도착은 큐 생성 조건이 **아니다**.  
`postCare`는 현장 종료 문맥이며 `visitChecked`를 자동 변경하지 않는다.  
자동 상태 전이는 v7.9 **비범위** · 원장의 명시적 방문확인만 `visitChecked`를 변경한다.

**no_show:**  
v7.9에서는 `no_show` 상태·자동 판별·기록 미완료 예외 처리를 **구현하거나 가정하지 않는다.**  
Phase 1–6: status enum Expand 금지 · 이후 생겨도 자동 배선 금지.

**사진:** 완료 조건 불포함.  
**`paymentNotRequired`:** v7.9 비범위 (예외 상태 모델이 Boolean 하나로 끝나지 않음).


---

### 16.1b Q1 개정 (스키마 현실)

| | 구(Perplexity 옵션 A) | **신(Inventory 후 Cursor 잠금)** |
|--|----------------------|----------------------------------|
| 기록 완료 | 요약 + 결제/불필요 | **`visitChecked` + 요약만** |
| 결제 큐 | 동시 | **Phase 2 보류** · 알림 MVP5의 payment는 “설계 슬롯 유지·트리거 미연결” 또는 Phase 후순위 |
| 사진 | 비필수 | 비필수 유지 |

PO §16.7 Q1 문구를 아래로 교체한다 (구 문구 폐기).

---

### 16.2 빠른 메모 — **상태도** (C2 · PO Yes)

```
[홈 glance 일정 카드]
  [메모 아이콘] + note 1줄 (비어 있으면 아이콘만/숨김 — Phase 설계)
  onTap / 메모아이콘 → go(/app/my?desk=today&schedule=<id>)
  홈에서 note 편집 UI · BottomSheet 직접 오픈 금지

[마이 일정 상세 scheduleId]
  note 전체 읽기
  [수정] → lines≤2 ? BottomSheet : FullScreenEditor

저장:
  CareScheduleEntry.note 갱신 → 홈 glance 동일 SSOT 재구독으로 즉시 반영
  SOAP / customer note 자동 복제 금지
  무소속 스크래치 메모 테이블 금지
  이력 테이블 CareScheduleNote: 후속 Expand (v7.9 필수 아님)
```

---

### 16.3 홈 주간 vs 마이 주간 — **상태**

| 상태 | 홈 | 마이 |
|------|----|------|
| `homeWeekAnchor` | 로컬 캘린더 **이번 주 월 00:00** 고정 | 무관 |
| `myVisibleDay` / `myVisibleWeek` | 변경해도 홈 불변 | 사용자 제스처로 변경 |
| 데이터 구독 | `care_schedule` where start ∈ homeWeek | where start ∈ myVisible range |
| 쓰기 | **금지** (메모·CRUD 없음) | 허용 |

동시성: 마이 CRUD 성공 → store notify → 홈은 **같은 SSOT 재구독**으로 반영.  
낙관적 충돌: last-write-wins + snackbar (Phase 3).

---

### 16.4 대표 B/A (C3) — **구현 규칙** (PO Yes)

**범위:** `max 5`는 **공개 프로필 상단 쇼케이스**에만 적용.  
커뮤니티에 공개된 B/A **총량 제한이 아님**.

```
profileFeaturedBaIds: List<assetId>  // max length 5, order = display order
communityPublished(asset) 독립 플래그
default featured = 0 허용 · 자동 미러 금지

setFeatured(id): if published && consented && featured.count<5
unsetFeatured(id): featured만 제거 · published 유지
revokeConsent / unpublish / delete / 이미지없음:
  커뮤니티·프로필 **표시** 동시 비노출
  prefs ID는 자동 unset하지 않음(표시만 필터) · 원장 의도 복원 가능
```

**로컬 저장 (Phase 5 MVP):**  
featured 선택·순서는 **현재 기기 로컬 설정**. 서버/다기기 동기화·백업·복구는 비범위.  
앱 데이터 삭제·재설치 시 초기화될 수 있음. 로컬 유실은 새 공개를 만들지 않으며 `caseShared`/consent를 변경하지 않음.  
서버 동기화는 별도 계약·마이그레이션 PRD.

**매 렌더 필터 (잠금):**

```
displayFeaturedCases =
  profileFeaturedBaIds 순서 유지
  AND chart 존재 AND caseShared AND consent AND 이미지 존재
```

UI 권고: 선택 모드 + 최대 5 + 선택 순=표시 순 (드래그 최소화).  
관리 CTA는 **원장(isOwner)만** · 외부 방문자 노출 금지.

---

### 16.5 알림 딥링크 — **포맷** (C4 · PO Yes)

**잠금 문장:**  
모든 원장 운영 알림은 홈이 아니라, 처리 대상 객체가 선택된 **사장 책상 상세**로 직접 이동한다.  
대상이 없거나 접근할 수 없으면 **사장 책상 오늘의 작업 큐**로 이동한다.

| taskType | URI |
|----------|-----|
| `incomplete_record` | `/app/my?desk=today&chart=<chartId>&step=record` |
| `payment_missing` | (스키마 전 **페이로드 생성 금지**) `/app/my?desk=today&chart=<chartId>&step=payment` |
| `schedule_changed` | `/app/my?desk=today&schedule=<scheduleId>` |
| `follow_up_due` | `/app/my?desk=customers&filter=follow_up_due` 또는 `&customer=<id>` |
| `credit_expiry` | `/app/my?desk=customers&customer=<id>&focus=credits` |
| fallback | `/app/my?desk=today&task=queue` |

대상 없음: toast  
`처리할 항목을 찾을 수 없어요. 오늘 남은 업무를 확인해 보세요.`  
+ fallback URI. **home 탭 index로 go 금지.** 일반 고객 목록만으로 폴백 비권고.

---

### 16.6 큐 vs peek · Timer 배지 (C5 · PO Yes)

**큐 row:** `{ taskType, objectId, label, missingBits[], dueAt }`  
상태 전이로 닫히는 일만. 인사이트는 row로 insert 금지.

**큐에 넣지 않음 (예시):** 목표대비 매출·실매출 하락·시간당수익·빈 시간대·재방문율·평균결제·상권·B/A·후기 수 → 해당 경영 ZONE / 자산면.

**peek 허용 조건:**

| 조건 | 잠금 |
|------|------|
| 개수 | 동시 max **1** |
| 위치 | 업무 큐 아래 · 상세 스케줄 위 |
| 시각 | 큐 카드보다 **저강도** · 배지·체크박스·빨간 경고 금지 |
| 데이터 | 최소 데이터량·비교 기준·기간 **모두** 충족 시에만 |
| CTA | **`경영에서 보기`만** → `/app/biz-dashboard#zone=N` |
| 숨김 | `이번 주 숨기기` 또는 `나중에 보기` |
| 자동 | 큐 insert · 고객 알림 · 메시지 발송 **금지** (토글/설정으로도 v7.9에서 켜지 않음) |
| 고객 연결 | 원장이 명시적으로 대상 고객을 연 뒤에만 |
| AI 제안 | 「다음 고객에게 물어봐」류는 **경영 대시보드만** · peek에 두지 않음 |

**단서③ 강화 (제약 ≠ 선택 기능):**  
Peek 자동화 금지는 v7.9 **제품 제약(하드 가드)** 이다.  
“원장이 원하면 자동 알림”은 **후속 PRD** · 본 문서 Phase에 넣지 않는다.  
구현 검증: peek 모듈에서 notification/queue/message insert 경로 **lint/테스트 0건**.

**Timer ↔ 마이「진행 중」:**

```
SSOT = VisitTimerStore (단일)
마이 배지: active != null && !done
  && VisitSession(customerId) match (scheduleId 직접 매칭 불가 · §16.8 B)
  onTap → select Timer shell tab + store.resume/focus (새 세션 생성 금지)
홈/마이 「케어 시작」:
  if store.active && active.visitSessionId/customer 불일치 → ConfirmSheet
  else if store.active && same → Timer focus
  else → startCare(target) then Timer tab
```

**배지 계약 보정 (§16.6):**  
`scheduleId` 직접 매칭 **불가**(타이머에 필드 없음). MVP는  
`active.visitSessionId` → `VisitSession.customerId` → 일정/고객 매칭.  
상세 inventory: §16.8 B.

---

### 16.7 PO Yes/No — **잠금 완료** (2026-09-11)

| # | 질문 | PO | Phase에서 할 일 |
|---|------|----|-----------------|
| **1** | 기록 완료 = `visitChecked` + `hasSummary` · 사진 비필수 · `payment_missing` 큐 보류 · `paymentNotRequired` 비범위 · no_show 자동예외 금지? | **Yes** | `requiredComplete_MVP`/`기록미완료` 순수함수+테스트. 결제 큐·draft 상태 없음. |
| **2** | 홈=메모 미리보기 · 마이=편집 · `CareScheduleEntry.note` · SOAP/고객메모 자동복제·스크래치 금지? | **Yes** | 홈 읽기 전용 · 마이 편집 · note SSOT. |
| **3** | 프로필 쇼케이스 대표 B/A max 5 · 해제≠커뮤니티철회 · 철회=양면숨김 · 자동미러 금지? | **Yes** | featured max5+정렬 테스트 · **커뮤니티 총량 제한 아님**. |
| **4** | 알림=상세 직행 · 폴백=마이 오늘 큐 · 홈 go 금지? | **Yes** | §16.5 URI · fallback toast. |
| **5** | 인사이트≠큐 · peek≤1 · CTA=`경영에서 보기`만 · 자동 큐/알림/메시지 금지? | **Yes** | peek 계약 §16.6 · insert→큐 경로 없음. |

#### Approved 후보 단서 3문 (동시 잠금)

1. **Q1:** 결제 큐가 “불필요”한 것이 아니라, 현재 Payment SSOT·예외 상태·차트 FK가 없어 **정확한 상태 계약이 생길 때까지 보류**한다.  
   **재오픈:** v7.9 Phase 번호가 아니라 **후속 Payment/차감 SSOT PRD Approved 후**. (본 Phase 2–6에 몰래 넣지 않음)
2. **Q3:** 대표 사례 5개는 **공개 프로필 쇼케이스 한도**이며, 커뮤니티 공개 B/A의 총량 제한이 아니다.  
   **커뮤니티팀 FAQ:** “몇 개까지 공개?” → **커뮤니티 총량 제한 없음**(정책·동의·검토만). 프로필 상단만 max 5.
3. **Q5:** Peek는 인사이트를 읽는 진입점일 뿐이며, 자동으로 업무 큐·고객 알림·메시지 발송을 만들지 않는다.  
   → **하드 가드** (§16.6) · “원하면 자동 알림” = 후속 PRD.

**알림 MVP:** `incomplete_record` · `schedule_changed` · `follow_up_due` · `credit_expiry` 활성.  
`payment_missing` = 페이로드 생성 **비활성**(슬롯만 문서 유지).

**Status:** **Approved.** Phase 승인 후에만 `lib/`.

---

### 16.8 Phase 0 선행 체크리스트 — **완료** (문서 inventory · 구현 아님)

#### A. 스키마 (이전 완료)

- [x] `paymentNotRequired` → **없음** · Expand 비범위  
- [x] 차트 Payment FK → **없음** · payment 큐 보류  
- [x] care_schedule status → scheduled/completed/cancelled · **no_show 없음**  
- [x] 요약·사진·visitChecked → **있음** · `CareScheduleEntry.note` 있음  

#### B. VisitTimerStore 활성 필드 inventory

| 심볼 | 위치 | 값 |
|------|------|----|
| SSOT | `VisitTimerStore.instance.active` | `VisitOperationTimer?` |
| 방문 연결 | `active.visitSessionId` | 비면 **standalone** (`isStandalone`) |
| 샵 | `active.shopId` | |
| 상태 | `active.status` | idle…care…postCare…done |
| 고객/일정/차트 | **타이머 row에 없음** | `scheduleId` · `customerId` · `chartId` **필드 부재** |
| 고객 해석 | `VisitSession` via `visitSessionId` | `VisitSession.customerId` · optional `chartDraftId` |
| 일정 매칭 | 간접만 | `customerId` ↔ `CareScheduleEntry.customerId` (동명이인·null customerId 주의) |
| 입구 | `startCare` / `jumpToStep` / `resumeCare` → `_ensureTicking(force:)` | |
| 통로 | `Timer.periodic` → **`_onTick()` 호출** (tear-off 금지 · 코드 주석 있음) | |
| 출구 | `HomeTimerStage` → `FlipClockDisplay` (잔여/오버타임만) | |
| 케어 종료 | `endCare()` → `postCare` | **`visitChecked`를 건드리지 않음** |

**배지 계약 보정 (§16.6 · §16.10):**  
`scheduleId` 직접 매칭 **불가**. MVP는 **고객 단위** 배지.  
다중 일정 규칙은 §16.10 문제③.

#### C. `visitChecked==false` + 세션 종료 → 큐 진입점 (**입구 1개로 잠금**)

```
입구 후보 (조사):
  1) endCare() / finishStandaloneCare()  → 타이머 postCare/done
  2) VisitSession.phase → done            → 방문 세션 종료
  3) 원장/기존 UX: visit_checked = true   → 차트 방문확인

Phase 2 잠금 (택1 완료):
  기록미완료 큐 입구 = **(3) ONLY**
  (1)(2)는 큐에 insert 하지 않음

케어 종료 후 착륙 (문서):
  endCare → status=postCare · 홈 Timer / 기존 케어 UI에 머무름
  방문확인·요약 작성은 **별 화면/기존 차트 UX** (세션 종료에 자동 묶지 않음)
  “케어 끝 + 방문확인 안 함” → 오늘 일정/배지 등 **별 UX만** · 큐 자동생성 금지
```

#### D. 홈 week / 마이 day 구독 쿼리 스케치

**현재 코드:**  
`SoriStore.refreshCareScheduleEntries` → `loadCareScheduleEntries(shopId, from: now-1개월, to: now+2개월)`  
→ 메모리 `careScheduleEntries` 단일 리스트.  
홈 스트립: `HomeSchedulerStrip.todayEntries` = **당일 + status==scheduled**.  
마이/어젠다: `buildTodayAgenda` = 당일 scheduled + 미완료 `visit_sessions` 병합.

**v7.9 목표 스케치 (구현 시 Expand·필터만 · 새 SSOT 금지):**

```
homeWeekAnchor = 로컬 주 월요일 00:00 (고정)
homeWeekEnd   = homeWeekAnchor + 7d

홈 glance 구독:
  careScheduleEntries.where
    scheduledAt ∈ [homeWeekAnchor, homeWeekEnd)
    AND status != cancelled
  표시: 주간 스트립 + 오늘 하이라이트 + note 1줄 미리보기
  쓰기: 금지

마이 myVisibleDay (기본=오늘):
  careScheduleEntries.where isSameDay(myVisibleDay)
  + TodayAgenda 병합 규칙 재사용 가능
  쓰기: note 갱신 · status CRUD 허용
  note 저장 → 동일 리스트 notify → 홈 재구독 반영

동시성: last-write-wins + snackbar (Phase 3)
범위 좁히기: Phase에서 from/to를 week 단위로 줄여도 API 시그니처 유지
```

#### E. 알림 payload → §16.5 URI (`payment_missing` 제외)

기존 `shop_notifications`는 팬/에스크로 등 **다른 kind**.  
원장 운영 알림 MVP는 **신규 payload 계약**(Expand) 전제. 매핑표만 잠금:

| taskType | payload 필수 키 | URI | 활성 |
|----------|-----------------|-----|------|
| `incomplete_record` | `chartId` | `/app/my?desk=today&chart=<chartId>&step=record` | Yes |
| `schedule_changed` | `scheduleId` | `/app/my?desk=today&schedule=<scheduleId>` | Yes |
| `follow_up_due` | `customerId` (optional filter) | `/app/my?desk=customers&customer=<id>` 또는 `filter=follow_up_due` | Yes |
| `credit_expiry` | `customerId` | `/app/my?desk=customers&customer=<id>&focus=credits` | Yes |
| `payment_missing` | — | — | **No** (페이로드 생성 금지) |
| (실패) | — | `/app/my?desk=today&task=queue` + toast | fallback |

라우터: Phase 1+ · **home shell index로 go 금지**.

#### F. Timer 플립시계 경로 — **손대지 않음 서명**

```
서명 범위 (v7.9 마이페이지 Phase 0–6 전 구간):
  ✗ VisitTimerStore 틱 로직 · _onTick / _ensureTicking 시그니처·호출 방식
  ✗ HomeTimerStage · FlipClockDisplay 중앙 표시값 규칙
     (벽시계·총시간을 중앙에 넣지 않음 · 구간 잔여/오버타임만)
  ✗ CareTimerTtsService 계약 · primeFromUserGesture
  ✗ tear-off `(_) => _onTick` 재도입 금지

허용 (배지·딥링크만 · 별도 Phase 승인):
  ✓ 마이 「진행 중」이 VisitTimerStore.instance 를 listen
  ✓ onTap → Timer 탭 focus / resume (새 시계 소스 금지)
  ✓ ConfirmSheet 충돌 UX (다른 고객 세션 활성 시)

서명: Cursor Phase 0 문서 (2026-09-11) · PO Approved 후보 전제
위반 시: 해당 PR 즉시 롤백
```

#### Phase 0 종료 조건

위 A–F 전부 체크됨 → **Phase 0 문서 완료**.  
다음: **§16.10** 잔여 잠금 확인 → 정식 **Approved** → Phase 1 구현 계획.

---

### 16.9 Claude 재평가 대응표

| Claude 재평가 | 대응 |
|---------------|------|
| 문서 미저장 | 경로: `docs/PRD_v7.9_MY_PAGE_MASTER.md` |
| C1이 진단만 | §16.1 불리언 |
| C2 상태도 없음 | §16.2 |
| C4 deeplink 포맷 없음 | §16.0 · §16.5 |
| Q가 구현 불가 | §16.7 Yes→구현 |
| Timer/배지 충돌 | §16.6 SSOT 단일 |
| Phase 0 30% | §16.8 **문서 완료** (A–F) |
| 잔여 불확실성 | §16.10 (no_show·큐입구·배지 다중일정·단서 강화) |

---

### 16.10 잔여 불확실성 — **잠금 완료** (Approved 편입)

#### 문제① no_show → §16.1 · §16.11

#### 문제② 큐 진입점 → §16.1 가드 · 입구=`visitChecked` ONLY

#### 문제③ 동일 customerId 다중 일정 — **테스트 가능 계약**

| 항목 | 규칙 |
|------|------|
| 배지 집계 | 마이 오늘 「진행 중」배지 = **고유 `customerId` 수** (일정 건수 아님) |
| 동일 고객 복수 일정 | 배지에서 **1명**으로 계산 |
| 후보 일정 | `status != cancelled` · 아직 닫히지 않은 일정만 |
| primary | 현재 시각과 **가장 가까운** 미완료 일정 **1건** |
| tie-break | `scheduledAt` 동률 → `updatedAt`(없으면 `createdAt`) 최신 · 재동률 → **stable id** 오름차순 |
| secondary | `오늘 일정 N건` **개수만** · 업무 큐에 일정 카드 **중복 row 금지** |
| 일정 없음 | 고객 단위 후속 업무만 있으면 `다음 일정 없음` |
| null customerId / standalone | 배지 매칭 **스킵** |
| scheduleId on timer | v7.9 **비범위** |
| 필수 테스트 | 같은 고객 당일 2예약 + 타이머 활성 |

#### 단서① · Payment 후속 PRD 진입 조건

`payment_missing`은 Phase 2 “추가 기능”이 **아니다**.  
다음이 **별도 Payment PRD에서 Approved**된 뒤에만 재검토:

| 선행 계약 | 확인할 질문 |
|-----------|-------------|
| Payment SSOT | 결제 1건의 객체·상태 |
| Visit 연결 | Payment ↔ Visit/`customer_chart` FK·규칙 |
| 선불권 | CreditLedger 차감의 Visit 귀속 기준 |
| 예외 사유 | 무료·현장미결제·외부결제·선물권·보류 표현 |
| 환불/취소 | 부분환불·재차감 이력·상태 |
| 큐 해제 | 성공 / 차감 / 불필요 / 보류 중 무엇으로 닫는가 |
| 금액 지표 | 실매출·선풀판매·잔여의무 갱신 시점 |

`paymentNotRequired` 단독 Expand **금지** (예외 상태 모델이 Boolean이 아님).

#### 단서③ · B/A 한도

- Peek 자동화 금지 = **하드 가드** · feature flag로 우회 활성화 **불가**(v7.9)  
- 커뮤니티 공개 B/A: **총량 제한 없음** · 각각 유효한 공개 동의·검토 상태 필수  
- 프로필 대표 사례: **0~5개** · 커뮤니티 총량에 적용하지 않음  

#### Cursor 구현 계약

- [x] Phase 0 A–F · §16.10 · §16.11 = Approved 기준선  
- [ ] Phase PR마다: ≤5파일 · Timer 경로 미포함 · `payment_missing` insert 0 · peek→queue/notify/message 0 · visitChecked 자동전이 0  

#### PO 서명 (2026-09-11)

| # | 한 줄 | PO |
|---|-------|-----|
| Q1 | 방문확인+요약 · 결제큐 보류 · no_show 없음 | **Yes** |
| Q3 | 프로필5 ≠ 커뮤니티 총량 | **Yes** |
| 단서① | 결제 큐 재오픈 = 후속 Payment PRD | **Yes** |

---

### 16.11 Approved 가드 문장 (필수 · 축약)

> `care_schedule` 완료, Timer 종료, postCare 도착은 `visitChecked`를 자동 변경하지 않는다. 기록 미완료 큐는 명시적으로 방문확인된 Visit만 대상으로 한다.

> v7.9에서는 `no_show` 상태가 존재하지 않으므로, 노쇼의 자동 판별·자동 제외·자동 알림을 구현하거나 가정하지 않는다.

> `payment_missing` 큐는 후속 Payment PRD에서 Payment SSOT, Visit 연결, 선불권 차감, 환불 및 예외 상태 계약이 Approved된 뒤에만 재개한다.

추가 하드 가드:  
v7.9에서는 자동 알림·자동 메시지·자동 상태 변경을 **feature flag로 우회 활성화할 수 없다.**

---

## 17. UI Acceptance · Phase 1 계획 (문서 · `lib/` 미착수)

**UI SSOT:** `docs/PRD_v7.9_UI_UX_BRIEF.md`  
톤: 따뜻한 임상 기록 + 조용한 경영 도구. 범용 카드 대시보드·인스타 복제·영어 Analytics 라벨 **거부**.

### 17.1 공통 검수 (모든 Phase PR)

1. 급한 일 / 현재 맥락 / 다음 행동이 3초 안에 구분되는가  
2. 화면이 한 가지 일만 하는가  
3. 스키마에 없는 상태(결제·no_show·자동 visitChecked)를 UI가 발명하지 않는가  

### 17.2 Phase 1 — 스케줄 읽기 전용 이중 밀도

**목적:** 홈 glance ↔ 마이 오늘 읽기 · 동일 `careScheduleEntries`  
**Acceptance SSOT:** `PRD_v7.9_UI_UX_BRIEF.md` §5.1 **8항** (단일 SSOT · 홈 범위 · 정렬 · note · 상태 · 읽기전용 · Timer 격리 · 비경영)

| # | 파일 | 역할 |
|---|------|------|
| 1 | 신규 `care_schedule_read_density.dart` | week/day · 오늘 top3 정렬 · note preview(빈 note 숨김) · cancelled 기본 제외 |
| 2 | `home_scheduler_strip.dart` (+필요 시 주간 glance 위젯 Expand) | 주간 점 스트립 · 오늘 ≤3 · `+N건` · 쓰기 없음 |
| 3 | `visit_launcher_page.dart` | glance 연결만 · Timer/`_onTick`/FlipClock **미수정** |
| 4 | 신규 `my_today_schedule_read_panel.dart` | 당일 전체 읽기 · note 1줄 · CRUD/큐/KPI 없음 |
| 5 | `director_my_page_view.dart` | Home 탭 상단 Expand만 · 6탭 삭제 금지 |

**테스트:** `test/care_schedule_read_density_test.dart` — AC1·3·4·5 단위 · `today_agenda_test` 회귀

**승인 상태:** **Phase 1 Approved** (2026-09-11) · §5.1-A 포함 · 구현 착수  

**승인 한정 문구:**

> Phase 1 승인: `docs/PRD_v7.9_UI_UX_BRIEF.md` 및 MASTER §17의 Acceptance Criteria를 준수하여, 동일 `care_schedule` SSOT 기반의 홈 주간 스트립·오늘 일정 최대 3건·일정 note 1줄·마이 오늘 읽기 전용 스케줄만 구현한다. Timer, `VisitTimerStore`, 플립시계, 일정 CRUD, 업무 큐, 고객 타임라인, 방문 기록, 결제, 경영 ZONE, 공개 프로필은 범위 밖이며 수정·추가·리팩터링하지 않는다.

**§5.1-A:** 종료 시각 없음 → Timer/visitChecked 미사용 · 가까운 미래 `scheduledAt` 정렬 · cancelled는 상위3·주간점·마이 목록에서 제외.

### 17.3 후속 Phase UI (문서만 · 지금 구현 금지)

| Phase | UI 초점 (BRIEF) |
|-------|-----------------|
| 2 | 마이 오늘 큐≤3 · peek≤1 · 기록하기 CTA · 빈 큐 1줄 |
| 3 | 마이 일정 CRUD · note 시트/풀 · 홈은 미리보기만 |
| 4 | 케어 시작 1 CTA · ConfirmSheet · Timer 탭만 시계 |
| 5 | 프로필 대표 B/A 0~5 · 예약\|문의 |
| — | 고객 타임라인 · 10초 방문 기록 작업대 · 경영 ★시간당수익 |

### 17.4 Phase 5 — **Approved** (2026-09-11 · 조건부 가드 잠금)

**승인 문구:**

> Phase 5 승인: MASTER §16.4·§17 및 UI/UX BRIEF를 준수하여, 공개 프로필에 원장이 명시 선택·정렬한 대표 B/A 쇼케이스 0~5개와 외부 예약/문의 CTA를 Expand 방식으로 추가한다. 대표 선택은 현재 기기의 샵별 로컬 설정으로만 저장하며, `caseShared`·동의·이미지 유효 조건을 매 렌더 시 재검증한다. 대표 해제는 커뮤니티 공개를 철회하지 않으며, 공개·동의 철회 또는 이미지/차트 부재는 커뮤니티 및 프로필 쇼케이스에서 비노출한다. 기존 `Shop.naverBookingOrPlaceUrl`이 유효하면 `예약하기`, 없으면 공개 전화번호의 `문의하기`, 둘 다 없으면 CTA를 숨기고 안내만 표시한다. Timer, `VisitTimerStore`, 일정·큐·결제·경영 ZONE, `caseShared`의 기존 의미, SQL 마이그레이션 및 `sori_store` 대규모 리팩터링은 범위 밖이며 수정하지 않는다.

**가드 5:**

1. featured = 기기 로컬 · 서버/다기기 동기화 비범위 · 재설치 시 초기화 가능 · 유실≠새공개/`caseShared`변경  
2. 매 렌더 `displayFeatured` 재검증 · 상태 변화 시 prefs 자동 unset 금지(표시만 필터)  
3. CTA: 유효 URL→예약하기(외부) · 없으면 전화→문의하기 · 둘 다 없으면 버튼 숨김+「예약 방법을 준비 중이에요」 · URL 열기 실패 시 가짜 예약 성공 금지  
4. `대표 사례 관리`는 isOwner만 · 외부 방문자 노출 금지  
5. `caseShared`/동의/featured 독립 · 대표 해제≠커뮤니티 철회

**파일(≤5):** `profile_showcase.dart` · `profile_featured_ba_local.dart` · `director_fandom_profile_page.dart` · `profile_featured_ba_picker_sheet.dart` · `test/profile_showcase_test.dart`

---

## 14. 변경 로그 (갱신)

| 날짜 | 내용 |
|------|------|
| 2026-09-11 | Skeleton → P1–P7 → Claude §15 → C1–C5 §16 |
| 2026-09-11 | **§16 구현가능 계약 보강** (불리언·URI·Yes→구현·Phase0 체크) · 구현 금지 |
| 2026-09-11 | **스키마 inventory** · Q1→기록우선(요약) · payment 큐/ paymentNotRequired 보류 · no_show 없음 |
| 2026-09-11 | **§16.7 PO Yes(5) 잠금** · 단서3 · 부분완료/draft 상태 폐기 · Status=Approved 후보 · 구현 금지 |
| 2026-09-11 | **Phase 0 문서 완료** (§16.8 A–F) |
| 2026-09-11 | **§16.10** no_show/큐입구/배지 다중일정/단서 |
| 2026-09-11 | **§16.11 가드 3문** · PO Yes×3 · **Status=Approved** · Phase 승인 전 `lib/` 금지 |
| 2026-09-11 | **UI/UX BRIEF** · §17 Phase 1 계획 · 구현 금지 |
| 2026-09-11 | Phase 1 Acceptance **8항** 잠금 · 승인 한정 문구 · **PO 승인 대기** · `lib/` 금지 |
| 2026-09-11 | **§5.1-A** · Phase 1 **Approved** · 홈 glance·마이 읽기 패널 구현 |
| 2026-09-11 | **§17.4 Phase 5 Approved** · §16.4 로컬 featured·표시필터 가드 · 구현 |
