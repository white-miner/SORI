# PRD v6.0 — E2E 방문 종료 및 고객 리포트 발송 파이프라인

**Status:** Approved · PO 마인드 Final Sign-off 2026-09-01  
**Author:** Expert Lead Engineer & UX/UI Architect  
**Requested by:** PO 마인드 · 2026-09-01  
**Builds on:** PRD v5.4 (`7ac14f0`) — 타임 매니지먼트 SSOT  
**Rule:** ~~PO v6.0 컨펌 전 코드 수정·Commit 금지~~ → **Approved · Implementation in progress**

---

## 0. Executive Summary

v5.x까지 구축한 **타임 매니지먼트 데이터**(상담·차트·케어·구간·정성 오버타임)는 현재 `buildReportBlock()`으로 plain text만 생성되어 `customer_charts.treatment_summary`에 append되고, **고객에게 자동 전달되는 E2E 파이프라인은 없다.**

v6.0은 **[방문 종료] 1-tap → 데이터 취합 → 진정성 있는 리포트 문구 생성 → 3초 카톡 발송(MVP)** 을 하나의 흐름으로 연결한다.

```
[방문 종료]
    ↓ VisitCareReportGenerator (구조화)
    ↓ VisitReportNarrativeEngine (톤앤매너 텍스트)
    ↓ persist + completeVisit
    ↓ VisitReportSendSheet (복사 / 카톡 열기 / 링크)
    ↓ 고객 CareReportPage (B/A · 미션 · 시간 요약)
```

> **PO 핵심:** 메타 광고가 주지 못하는 **'원장님이 직접 들인 시간'의 증거**를 고객이 샵을 나서기 전/직후 카카오톡으로 받게 한다.

---

## 1. Problem Statement — 현재 갭

| 영역 | 현재 (`7ac14f0`) | v6.0 목표 |
|------|------------------|-----------|
| 방문 종료 | `_endVisit` → text append → phase=done | 종료 + **리포트 생성 + 발송 UI** |
| 리포트 형식 | 기계적 plain text blob | **구조화 JSON + 따뜻한 내레이션** |
| 정성(오버타임) | `· 정성 오버타임 포함` 한 줄 | **"00분의 정성을 더 담았습니다"** 구체 수치 |
| 고객 전달 | `customer_link_popup` 등 **수동·분리** | **방문 종료 직후 3초 플로우** |
| B2C 페이지 | `CareReportPage` — summary 텍스트만 | **시간·구간·정성 섹션** 시각화 |
| 카카오 | Mock Alimtalk + 별도 팝업 | MVP: **복사 + 카톡 열기** (알림톡은 Phase 2) |

**Baseline hook:** `lib/features/visit/visit_launcher_page.dart` → `_endVisit()`  
**Existing assets:** `VisitTimerStore.buildReportBlock()`, `buildCareReportAlimtalkBody()`, `SoriStore.buildCareReportUrl()`, `CareReportPage`

---

## 2. Scope & Non-Goals

### In Scope (v6.0 MVP)

- Visit-bound timer sessions (`visit_operation_timers.visit_session_id NOT NULL`)
- [방문 종료] 트리거 E2E (타이머 fullscreen · action strip · session view 공통)
- Report Generator + Narrative Engine
- `VisitReportSendSheet` UI (복사 / 카톡 열기 / 링크)
- `customer_charts` structured report persistence
- `CareReportPage` 시간 요약 섹션 추가

### Out of Scope (v6.0)

- 실 Kakao Alimtalk API 심사·연동 (Phase 2 placeholder UI만)
- Standalone utility timer (`utility_source = standalone_timer`, migration 106)
- SMS / 이메일 / WhatsApp
- 고객 자동 opt-in 마케팅
- AI 문구 생성 (템플릿 기반만; AI는 v6.1 후보)

---

## 3. Report Generator — 데이터 취합 및 요약 엔진

### 3.1 Input Sources (SSOT)

| Source | Table / Model | Fields Used |
|--------|---------------|-------------|
| Session | `visit_sessions` | `id`, `customer_id`, `customer_name`, `started_at`, `completed_at`, `chart_draft_id` |
| Timer | `visit_operation_timers` | `consultation_started_at`, `chart_active_seconds`, `chart_opened_at`, `care_started_at`, `care_ended_at`, `visit_ended_at`, `template_id`, `template_snapshot`, `step_results`, `after_photo_captured`, `status` |
| Preset | `care_program_templates` | `name`, `slot_index`, `steps` (fallback if snapshot empty) |
| Chart | `customer_charts` | `care_name`, `before_image_url`, `after_image_url`, `home_care_prescriptions`, `visit_number` |
| Customer | `customers` | `name`, `phone` |
| Events | `visit_operation_events` | `care_plan_complete`, `care_ended`, `visit_ended` (감사·디버그) |

### 3.2 Output Model — `VisitCareReport`

```dart
/// v6.0 SSOT — 방문 1회의 케어 리포트 스냅샷 (immutable after generate).
class VisitCareReport {
  final String visitSessionId;
  final String chartId;
  final String customerId;
  final String customerName;       // honorific 전 처리 raw
  final String shopName;
  final String presetName;         // care_program_templates.name || chart.careName
  final DateTime visitDate;

  // ── Duration tracks (seconds) ──
  final int totalVisitSeconds;     // consultationStartedAt → visitEndedAt
  final int consultationSeconds;   // total - chart - care (≥ 0)
  final int chartSeconds;          // chartActiveSeconds + live window
  final int careSeconds;           // careStartedAt → careEndedAt
  final int plannedCareSeconds;    // Σ templateSnapshot[i].minutes × 60
  final int overtimeSeconds;       // max(0, careSeconds - plannedCareSeconds)

  // ── Step breakdown ──
  final List<VisitCareStepLine> steps;
  final bool hadOvertime;
  final bool afterPhotoCaptured;

  // ── Links ──
  final String publicReportUrl;    // buildCareReportUrl(chartId)

  // ── Generated copy (filled by NarrativeEngine) ──
  final String kakaoShortMessage;  // ≤ 500 chars MVP
  final String kakaoLongMessage;     // preview + link
  final String internalAuditBlock; // 기존 buildReportBlock 호환
}

class VisitCareStepLine {
  final String label;
  final int plannedMinutes;
  final int actualSeconds;
  final int deltaSeconds;          // actual - planned×60 (signed)
}
```

### 3.3 Extraction Algorithm

**Trigger:** `_endVisit()` 직전, timer `status == postCare` (케어 종료 후 애프터 촬영 단계).

```
VisitCareReportGenerator.generate(ctx):
  1. timer ← VisitTimerStore.active (must match session.id)
  2. Finalize live chart window into chartActiveSeconds (if chart still open)
  3. snap ← VisitTimerLiveSnapshot.compute(timer, now: visitEndedAt)
  4. planned ← Σ templateSnapshot.minutes × 60
  5. overtime ← max(0, snap.careSeconds - planned)
  6. steps ← map stepResults → VisitCareStepLine
  7. presetName ← lookup templateId || chart.careName || '오늘의 케어'
  8. consultation ← max(0, total - chart - care)
  9. narrative ← VisitReportNarrativeEngine.render(report draft)
 10. return VisitCareReport (immutable)
```

**Overtime (정성) SSOT — v6.0 신규 명시:**

| Method | Formula | Priority |
|--------|---------|----------|
| **Primary** | `overtimeSeconds = careSeconds - plannedCareSeconds` | MVP default |
| **Event anchor** | `care_ended` − `care_plan_complete` from `visit_operation_events` | Cross-check / audit |
| **Persist** | `visit_operation_timers.overtime_seconds` (migration 107) | Written at `endCare()` or `endVisit()` |

> v5.x는 `isOvertime` boolean만 존재. v6.0에서 **초 단위 정성 시간**을 persist하여 리포트·B2C 페이지에서 "00분"으로 표현.

**Edge cases:**

| Case | Behavior |
|------|----------|
| 케어 중 [케어 종료] (planned 미완) | `stepResults` partial + overtime=0 |
| 프리셋 완료 후 정성 구간 | `hadOvertime=true`, overtimeSeconds>0 |
| 차트 미작성 | chartSeconds=0, consultation에 포함 |
| 애프터 미촬영 | `afterPhotoCaptured=false` → 문구에 soft disclaimer |
| Timer 없음 (legacy visit) | Generator skip → 기존 `_endVisit` fallback |

### 3.4 Service Location

```
lib/features/visit/report/
  visit_care_report.dart              # models
  visit_care_report_generator.dart    # aggregation
  visit_report_narrative_engine.dart  # templates
  visit_end_pipeline.dart             # orchestrator (_endVisit replacement)
```

**Persistence (MVP):**

```sql
-- migration 107 (proposed)
ALTER TABLE customer_charts
  ADD COLUMN IF NOT EXISTS care_report_json jsonb,
  ADD COLUMN IF NOT EXISTS care_report_generated_at timestamptz;

ALTER TABLE visit_operation_timers
  ADD COLUMN IF NOT EXISTS overtime_seconds int NOT NULL DEFAULT 0;
```

`care_report_json` = `VisitCareReport.toJson()` — B2C page + re-send without recompute.

`treatment_summary` append는 **유지**(원장 차트 기록용) + `internalAuditBlock` 동일 내용.

---

## 4. Narrative Engine — 리포트 톤앤매너 및 템플릿 구조

### 4.1 Tone Principles (CDG Customer Voice)

| Principle | Rule |
|-----------|------|
| **진정성** | 숫자는 timer SSOT — 추정·과장 금지 |
| **전문성** | 프리셋명·구간명 그대로 사용 |
| **친절** | "~해 드렸습니다", "~담았습니다" — 존댓말 |
| **간결** | 카톡 본문 **3~5문장** + 링크 |
| **금지** | 영수증 형태, "총액", "결제", robotic bullet spam |

### 4.2 Template Architecture

**3-Layer Template System:**

```
Layer A — kakaoShortMessage   (고객 카톡 본문, ≤500자)
Layer B — kakaoLongMessage    (SendSheet preview, 링크 포함)
Layer C — internalAuditBlock  (차트 treatment_summary append, 기존 호환)
```

**Variable Dictionary:**

| Token | Example | Source |
|-------|---------|--------|
| `{customer}` | 김민정 | customer.name + "님" |
| `{shop}` | 테라노바 경주 | shop.name |
| `{care}` | 테라노바 복부 슬리밍 | presetName |
| `{total_min}` | 87 | totalVisitSeconds ÷ 60 (ceil) |
| `{care_min}` | 62 | careSeconds ÷ 60 (ceil) |
| `{overtime_min}` | 8 | overtimeSeconds ÷ 60 (ceil, 0이면 omit) |
| `{step_highlight}` | 마무리 림프 | last stepResults.label |
| `{url}` | https://…/care-report/… | buildCareReportUrl |
| `{visit_n}` | 6 | chart.visitNumber |

### 4.3 Template Specimens

**Template `SORI_VISIT_REPORT_V1` — Standard (with overtime)**

```
{customer}님, 오늘 {shop}에서 {care} 케어 잘 받으셨습니다.

오늘 {customer}님을 위해 총 {total_min}분의 시간을 들여 꼼꼼히 케어해 드렸어요.
케어 본 시간은 {care_min}분이었고, 특히 마지막 {step_highlight}에
{overtime_min}분의 정성을 더 담았습니다.

아래 링크에서 오늘 케어 리포트와 B/A 사진, 3일 홈케어 가이드를 확인해 보세요.
{url}
```

**Template `SORI_VISIT_REPORT_V1_NO_OT` — No overtime variant**

```
{customer}님, 오늘 {shop}에서 {care} 케어 잘 받으셨습니다.

오늘 {customer}님을 위해 총 {total_min}분의 시간을 들여 꼼꼼히 케어해 드렸어요.
각 단계별로 계획된 시간에 맞춰 세심하게 진행했습니다.

아래 링크에서 오늘 케어 리포트를 확인해 보세요.
{url}
```

**Template `SORI_VISIT_REPORT_V1_NO_AFTER` — After photo missing**

Standard body + footer:

```
※ 오늘 애프터 사진은 다음 방문 시 함께 기록해 드릴게요.
```

**Layer C — internalAuditBlock (unchanged format, extended)**

```
--- 케어 시간 리포트 (SORI) ---
총 방문: 1h 27m
상담: 25m | 차트: 18m | 케어: 1h 02m
프리셋: 테라노바 복부 슬리밍
· 워밍업: 8:12 (예정 8분)
· 복부 집중: 22:05 (예정 20분)
· 마무리 림프: 15:30 (예정 12분)
· 정성 시간: 8:00
애프터: 촬영완료
```

### 4.4 Step Narrative (Optional B2C Detail Section)

CareReportPage에 **접이식 타임라인**:

```
오늘의 케어 타임라인
├─ 워밍업      8분 → 8:12 ✓
├─ 복부 집중  20분 → 22:05 ✓
├─ 마무리     12분 → 15:30 ✓
└─ 정성 시간           +8:00 ♥
```

---

## 5. MVP 공유 및 발송 매커니즘

### 5.1 Design Goal

> 원장님이 **3초 안에** 고객 카톡 채팅방에 리포트를 전달.

알림톡 서버·템플릿 심사 전 MVP는 **Manual Kakao Assist** — 자동 발송이 아닌 **원클릭 assist**.

### 5.2 `VisitReportSendSheet` UI

**Trigger:** `_endVisit` 성공 직후 · `showModalBottomSheet` · dismissible=false until action

```
┌─ VisitReportSendSheet ─────────────────────────┐
│  ✓ 방문이 종료되었습니다                          │
│                                                  │
│  ┌─ Preview (Layer B) ─────────────────────┐    │
│  │ 김민정님, 오늘 테라노바 경주에서…           │    │
│  │ (scrollable, monospace-off, Nunito)      │    │
│  └──────────────────────────────────────────┘    │
│                                                  │
│  [ 💬 카카오톡으로 보내기 ]  ← primary green      │
│  [ 📋 문구 복사 ]                                │
│  [ 🔗 리포트 링크 복사 ]                          │
│  ─────────────────────────────                   │
│  [ 나중에 ] (secondary)                           │
└──────────────────────────────────────────────────┘
```

### 5.3 [카카오톡으로 보내기] Flow

```
onKakaoSendTap():
  1. Clipboard.setData(kakaoLongMessage)     // always copy first
  2. Platform branch:
     · Android/iOS native:
         url_launcher → kakaotalk://send?text={encoded}
         fallback → kakaolink://send?text={encoded}
         fallback 2 → toast "문구가 복사되었습니다. 카톡에 붙여넣기"
     · Web (GitHub Pages):
         copy only + SnackBar "카카오톡 앱에서 붙여넣어 보내주세요"
  3. Log visit_report_share_attempted (analytics, optional)
  4. Dismiss sheet
```

**Phone-aware deep link (Phase 1.5 optional):**

```
kakaotalk://chat?phone={normalizedPhone}&text={encoded}
```

> 카카오 공식 Kakao Link SDK는 앱 키·도메인 등록 필요 → **v6.0 MVP 제외**, v6.2 후보.

### 5.4 Existing Alimtalk Bridge (Deferred Default)

`sendKakaoAlimtalkWithUi()` — **SendSheet 하단 "알림톡 발송 (65P)"** tertiary button:

- Mock RPC 유지 (`send_kakao_alimtalk_mock`)
- PO Q2에서 MVP default 여부 결정
- `customer.phone` empty → button disabled + "연락처 등록 필요"

### 5.5 Re-use Matrix

| Existing | v6.0 Usage |
|----------|------------|
| `buildCareReportAlimtalkBody()` | Deprecated → `VisitReportNarrativeEngine` replaces |
| `copyKakaoMessage()` | Re-use for [문구 복사] |
| `SoriStore.buildCareReportUrl()` | `{url}` token |
| `sendKakaoAlimtalkWithUi()` | Optional tertiary in sheet |
| `SoriShare.shareReviewLink()` | Not used (review ≠ care report) |

---

## 6. E2E Pipeline — Sequence

```
Director taps [방문 종료]
        │
        ▼
┌─ VisitEndPipeline.run(session) ─────────────────────┐
│  A. Validate: timer.status == postCare              │
│  B. report ← VisitCareReportGenerator.generate()    │
│  C. Persist:                                        │
│     · care_report_json on chart                     │
│     · overtime_seconds on timer                     │
│     · treatment_summary += internalAuditBlock       │
│  D. timer.endVisit()                                │
│  E. visit.completeVisit(session.id)                 │
│  F. return report                                   │
└─────────────────────────────────────────────────────┘
        │
        ▼
VisitReportSendSheet.show(report, customer.phone)
        │
        ├─ [카톡으로 보내기] → copy + open Kakao
        ├─ [문구 복사]
        ├─ [링크 복사]
        └─ [나중에] → Home refresh
        │
        ▼
Customer opens {url} → CareReportPage (enhanced)
```

**Status gate (unchanged from v5.x):**

```
idle → consulting → prep → care → careOvertime → postCare → [방문 종료] → done
                                      ↑                  ↑
                                 [케어 종료]        after photo optional
```

---

## 7. CareReportPage Enhancement (B2C)

### 7.1 New Section — "오늘의 케어 시간"

`care_report_json` 존재 시 렌더:

| Element | Spec |
|---------|------|
| Hero stat | **"{care_min}분"** care duration · green accent |
| Overtime badge | `+{overtime_min}분 정성` · only if > 0 · heart icon |
| Timeline | Collapsible step list from `steps[]` |
| Fallback | Legacy `treatmentSummary` text if no JSON |

### 7.2 Layout Order (updated)

```
1. Shop name + "{name}님의 케어 리포트"
2. Care name + visit number
3. ★ NEW: Care Time Summary card
4. B/A photos
5. Summary text (narrative excerpt or directorInsight)
6. 3-day home care missions
7. Shop CTA (call / booking)
```

---

## 8. Implementation Plan (Post-Approval)

| Phase | Scope | Files / Migration |
|-------|-------|-------------------|
| **R1** | `VisitCareReport` model + generator | `lib/features/visit/report/*` |
| **R2** | Narrative engine + templates | `visit_report_narrative_engine.dart` |
| **R3** | Migration 107 + repository persist | `supabase/migrations/107_*`, `sori_store.dart` |
| **R4** | `VisitEndPipeline` + `_endVisit` refactor | `visit_launcher_page.dart`, timer fullscreen hooks |
| **R5** | `VisitReportSendSheet` + Kakao assist | new widget + `url_launcher` |
| **R6** | `CareReportPage` time section | `care_report_page.dart` |
| **T** | Generator unit tests + narrative snapshot tests | `test/visit_care_report_v60_test.dart` |

**Estimated delta:** ~10 files · 1 migration · 0 new table (MVP).

---

## 9. PO Open Questions — Closed (2026-09-01)

| # | Decision |
|---|----------|
| Q1 | **총 소요 시간** 어필 + **케어·정성**만 강조 (상담/차트 분리 노출 금지) |
| Q2 | **카톡 열기(Clipboard+Intent)** Primary · 알림톡 tertiary |
| Q3 | **발송 허용** — 애프터 미촬영 disclaimer만 |
| Q4 | **`treatment_summary` append 유지** + `care_report_json` |
| Q5 | **Standalone timer 제외** |
| Q6 | **`{이름}님`** |

---

## 10. Acceptance Criteria (PO Sign-off)

- [ ] [방문 종료] → Report Generator ≤ 500ms (local)
- [ ] overtimeSeconds 정확 (planned 대비 care delta)
- [ ] Kakao short message: 3~5문장 · 존댓말 · 프리셋명 포함
- [ ] [카톡으로 보내기]: clipboard + native Kakao intent (where supported)
- [ ] `care_report_json` persisted · CareReportPage renders time section
- [ ] Phone missing → 카톡 버튼 disabled · 복사는 가능
- [ ] Standalone timer → no send sheet
- [ ] v5.x timer/count/home flows **unchanged**

---

## 11. Risk Register

| Risk | Mitigation |
|------|------------|
| Kakao deep link OS variance | Copy-first always; fallback toast |
| Web deploy (GitHub Pages) no Kakao intent | Web-specific copy-only UX |
| overtime calc drift vs events | Dual compute + log mismatch |
| Long preset names overflow | Ellipsis at 24 chars in short msg |
| PO tone too "AI-ish" | Template-only v6.0; human review in QA |

---

**Next Step:** PO v6.0 컨펌 → Phase R1–R6 구현 → Commit
