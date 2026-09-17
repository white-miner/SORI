# PRD v5.3 — 홈 탭 대시보드 및 마이크로 인터랙션 아키텍처

**Status:** Approved · SSOT  
**Approved by:** PO 마인드 · 2026-09-01  
**Open Questions:** Closed (see §10)

---

## 0. PO Intent Summary (이해 증명)

| PO 요구 | v5.3 해석 |
|---------|-----------|
| 홈 = 첨부 시안(`홈 대시보드.jpg`) 레이아웃 | 플립 시계 Hero + 메모 스택 + 툴박스 6 + 고객 CTA + **케어 시작** |
| 프리셋 편집기 홈 탈거 | `PresetExpandPanel` **홈에서 제거** → 케어 타이머 필드 ⚙️ 아이콘으로 이전 |
| 차트·타이머 종속성 해제 | `VisitSession` / 차트 기록 **없이** 타이머 단독 사용 가능 |
| 캘린더 = 날짜 탭 → 월간 펼침 | 플립 시계 **상단 날짜** 탭 → `AnimatedSize` 월간 그리드 |
| 메모 = 시간대별 +/− | `care_schedule_entries` 기반 · 슬롯 단위 CRUD |
| 메모 표시 = 시계 아래 스택 | 당일 → 시간순 스택 · 당일 없음 → **가장 가까운 미래** 메모 날짜 포함 표시 |
| 타이머 / 케어시작 진입 분기 | **경로 A·B·C** (§5) — `CareTimerEntryMode` SSOT |
| 케어시작 = 원장 바로가기 | 홈에서 프리셋·프로그램 **이미 지정** 시만 3초 후 TTS 자동 시작 |
| 카운트 / 계산기 / 날씨 | 툴박스 마이크로 인터랙션 (§3·§4) |

---

## 1. 화면 IA — 홈 탭 (`VisitLauncherPage`)

### 1.1 레이아웃 순서 (Top → Bottom)

```
┌─────────────────────────────────────┐
│  [Hero Card — White Glass]          │
│  ┌─ Date row (tap → calendar) ─┐    │
│  │  2026년 9월 1일  📅          │    │
│  ├─ [Animated Calendar Grid] ──┤    │  ← expand/collapse 300ms
│  ├─ Flip Clock (HH:MM + SS) ───┤    │
│  └─ Memo Stack Display ────────┘    │  ← tap → expand upcoming
├─────────────────────────────────────┤
│  [Toolbox Row — 6 icons]            │
│  타이머│카운트│계산기│날씨│온도│UV    │
├─────────────────────────────────────┤
│  [신규 고객]  [재방문 고객]          │
│  [━━━━━━ 케어 시작 ━━━━━━]          │  ← full-width green
├─────────────────────────────────────┤
│  (Optional) 차트 연동 토글 카드      │  ← v5.2 잔존, 프리셋 목록 **제거**
└─────────────────────────────────────┘
```

> **v5.2 → v5.3 Delta:** `SmartFlipTimerHero` 하단 `PresetExpandPanel` **삭제**.  
> `CalendarMemoPanel` (하단 접이식 월/주/일) **Hero 내부로 흡수** 또는 **대체**.

### 1.2 케어 타이머 필드 (`CareTimerFullscreenPage` — 시안 `케어 타이머.jpg`)

```
┌─ AppBar ─────────────────────────────┐
│  ◀ [프로그램명 ▼]              ⚙️    │  ← preset picker + settings
├─ Stacked Segment Bar ────────────────┤
├─ [White Glass — Flip + Controls] ────┤
├─ [케어 종료] or [케어 시작] ──────────┤  ← entry mode dependent (§5)
└─ [타임라인 ▼] ───────────────────────┘
```

---

## 2. 컴포넌트 및 UI 상태 트리 설계

### 2.1 Root State Machine — `HomeDashboardController`

새 컨트롤러(또는 `VisitLauncherPage` + mixin)가 **Hero 모드** 단일 SSOT를 관리한다.

```
HomeHeroMode (enum)
├── wallClock        // 기본: 실시간 HH:MM
├── calendarExpanded // 날짜 탭으로 월간 그리드 노출
├── countSetup       // 카운트: 플립=00:00, digit tap cycle
├── countRunning     // 카운트 다운 중
├── countComplete    // 0 도달 → 3× blink → wallClock
└── (calculatorOverlay는 별도 OverlayEntry, HeroMode 유지)

HomeOverlay (enum?, nullable)
├── calculator       // 하단 slide-up panel
├── weatherDetail    // ShopClimate 상세
└── none
```

**Provider / Store 분리 원칙**

| Layer | Owner | Responsibility |
|-------|-------|----------------|
| UI mode | `HomeDashboardController` | flip/calendar/count/calc overlay |
| Wall time | `SmartFlipTimerHero` tick (1s) | HH:MM when wallClock |
| Count value | `CountdownDraftStore` (local) | MM:SS draft, debounce timer |
| Care timer | `VisitTimerStore` (existing) | prep/care/postCare, steps |
| Memos | `SoriStore.careScheduleEntries` | CRUD via existing API |
| Climate | `ShopClimateService` (existing) | weather/temp/UV |

### 2.2 Hero Card — 상태 트리

```
HomeHeroCard
├── DateHeaderRow
│   ├── onTap → toggle calendarExpanded (AnimatedSize 300ms, easeInOutCubic)
│   └── shows: formatted date + calendar icon
├── CalendarExpandPanel (visible if calendarExpanded)
│   ├── MonthGrid (selected day highlight)
│   ├── onDaySelect → collapse calendar + load memos for day
│   └── MemoEditorSheet (bottom sheet)
│       ├── TimeSlotList (sorted by scheduledAt)
│       │   └── MemoSlotRow [time][note][−]
│       ├── [+] add slot → append empty row with next 30min default
│       └── Save → upsertCareScheduleEntry × N
├── FlipClockZone
│   ├── mode=wallClock → FlipClockDisplay(live now, SS corner)
│   ├── mode=count*     → FlipClockDisplay(editable, digitTapCycle)
│   └── FittedBox scale-down (narrow portrait)
└── MemoStackDisplay
    ├── collapsed: top 1 chip + stack offset (max 3 visible)
    ├── data: MemoDisplayPolicy.resolve(selectedDay, entries) (§2.4)
    ├── onTap → MemoStackExpanded (AnimatedSize / bottom sheet)
    └── expanded: today remaining + future memos chronological
```

### 2.3 Toolbox Row — 6 Icon State Map

| # | Icon | Idle | Active | Overlay / Navigation |
|---|------|------|--------|----------------------|
| 1 | **타이머** | gray circle | green ring if care running | `CareTimerEntryMode.standalone` → fullscreen (§5-A) |
| 2 | **카운트** | gray | orange ring | toggle countSetup; **re-tap = cancel** → wallClock |
| 3 | **계산기** | gray | blue ring | `HomeOverlay.calculator` slide-up 280ms |
| 4 | **날씨** | icon + label | — | `WeatherDetailSheet` or existing `ClinicalAssistantSheet` |
| 5 | **온도** | `32°C` text | — | same destination, scroll to temp section |
| 6 | **UV** | `UV 7` text | — | same destination, UV section |

**Bottom Sheet 공통 Contract**

```dart
// Conceptual — not implemented until PO approval
abstract class HomeToolboxOverlay {
  Duration get animationDuration => 280ms;
  bool get dismissOnScrimTap => true;
  void onDismiss(); // restores icon active state
}
```

### 2.4 Memo Display Policy (데이터 바인딩)

**Input:** `selectedDay: DateTime`, `entries: List<CareScheduleEntry>`, `now: DateTime`

**Algorithm:**

1. `todayEntries` = entries on `now` (same calendar day), status ≠ cancelled, sort by `scheduledAt`.
2. **If `todayEntries` not empty (collapsed):** show next **upcoming** entry (scheduledAt ≥ now) or last if all past.
3. **If `todayEntries` empty:** find **nearest future day** with entries; show first entry + date prefix `(9/3) 12:30 김민정님 상담예약`.
4. **Stack visual:** up to 3 chips, 12px horizontal offset, front = nearest in time.
5. **Expanded (on stack tap):** all memos where `scheduledAt ≥ now.startOfDay` OR same selectedDay, sorted ASC.

**Data model (reuse v5.2):**

- Table: `care_schedule_entries`
- Fields: `scheduled_at`, `note`, `customer_name`, `care_label`, `status`
- API: `SoriStore.addManualCareSchedule`, `upsertCareScheduleEntry`

**Multi-slot same day:** each `[+]` creates independent row; `−` marks cancelled or deletes draft row before save.

---

## 3. 카운트다운 마이크로 인터랙션 (Toolbox — 카운트)

### 3.1 진입 / 취소

| Event | Transition |
|-------|------------|
| Tap 카운트 icon | `wallClock → countSetup`, flip shows `00:00` |
| Tap 카운트 icon again (while countSetup/countRunning) | cancel → `wallClock`, clear draft |
| 5s no digit tap (countSetup) | `countSetup → countRunning` auto |
| Count reaches 0 | `countRunning → countComplete` |

### 3.2 Digit Tap Cycle

- Each flip digit cell is tappable (HH tens, HH ones, MM tens, MM ones — or MM:SS for count).
- Tap cycles: `0→1→…→9→0` (PO: "1부터 0까지 순차" → **0–9 cycle**, initial 0).
- Each tap **resets 5s debounce** (`Timer? _countIdleTimer`).

### 3.3 Debounce Implementation Strategy

```
onDigitTap(digitIndex):
  cycle digit value
  _countIdleTimer?.cancel()
  _countIdleTimer = Timer(5s, _autoStartCountdown)

_autoStartCountdown():
  if mode != countSetup: return
  mode = countRunning
  start tick (1s) decrement totalSeconds
```

### 3.4 Complete → Wall Clock Regression

```
onCountZero():
  mode = countComplete
  await blinkFlipClock(times: 3, interval: 1s)  // opacity or scale pulse
  mode = wallClock
  restore live time display
```

**Isolation:** Count mode **must not** mutate `VisitTimerStore` or create `VisitSession`.

---

## 4. 케어 시작 TTS 및 비동기 파이프라인

### 4.1 Scope

TTS pipeline applies to **경로 C only** (§5-C): Home **케어 시작** with preset already armed.

### 4.2 Async Pipeline (sequential)

```
Stage 0: Navigate Home → CareTimerFullscreenPage (Hero transition)
Stage 1: UI settle (420ms fade) — show stacked bar, timeline, [케어 종료]
Stage 2: await Future.delayed(3s)          // PO: "필드 진입 후 3초"
Stage 3: Flip overlay "3 → 2 → 1" (optional visual, 1s each or 3s total)
Stage 4: CareTimerTtsService.speak("케어를 시작합니다")  // native only, kIsWeb skip
Stage 5: await tts.completed (timeout 5s fallback)
Stage 6: VisitTimerStore.startCare()       // existing
Stage 7: Stacked segment bar begins countdown (existing tick + step advance)
```

### 4.3 Cancellation & Interruption

| Event | Behavior |
|-------|----------|
| User taps [케어 종료] during Stage 2–5 | cancel delayed future + TTS stop → endCare stub → pop to Home |
| User taps pause | existing `pauseCare()` — TTS suppressed (v5.2 D-1) |
| App background | `syncOnResume` — no duplicate startCare |

### 4.4 State Flag

```dart
// Conceptual
enum CareAutoStartPhase {
  idle,
  waiting3s,
  countingDown,
  ttsPlaying,
  started,
  cancelled,
}
```

Stored in `VisitTimerStore` or ephemeral page state; **cleared on dispose**.

---

## 5. 타이머 진입 라우팅 — 경로 A / B / C

### 5.1 SSOT: `CareTimerEntryMode`

```dart
enum CareTimerEntryMode {
  /// A: Toolbox 타이머 icon — standalone utility
  standalone,

  /// B: Home [케어 시작] — preset NOT fully armed on home
  careStartManual,

  /// C: Home [케어 시작] — preset + program name already selected on home
  careStartQuick,
}
```

Passed via `CareTimerFullscreenPage.entryMode` + optional `autoStart: bool`.

### 5.2 경로 A — 타이머 아이콘 (Standalone)

| Item | Policy |
|------|--------|
| VisitSession | **Not required** — use synthetic `standalone` timer context or nullable session |
| Chart | **No dependency** |
| Preset | User selects via ⚙️ / dropdown **inside** timer field |
| Primary CTA | **[케어 시작]** visible at bottom |
| [케어 종료] | **Hidden** until care actually running |
| Auto-start | **Never** on entry |
| Timeline | Visible after program selected |
| Return | Back / close → Home (timer state: prep or idle) |

### 5.3 경로 B — 케어 시작 (Manual Setup)

| Item | Policy |
|------|--------|
| Trigger | Home [케어 시작] when **no** program selected on home |
| VisitSession | Optional — decoupled from chart |
| Primary CTA | **[케어 시작]** — user must pick program + tap ▶ |
| [케어 종료] | Hidden until care running |
| Auto-start | **No** |
| TTS | Only on manual ▶ (existing step TTS, not "케어를 시작합니다" intro) |

### 5.4 경로 C — 케어 시작 (Quick Shortcut)

| Item | Policy |
|------|--------|
| Trigger | Home [케어 시작] when **preset slot + program name already bound** on home |
| Home precondition | `VisitTimerStore.bindPreset(slot)` + UI shows selected program name |
| Primary CTA | **[케어 종료]** visible **immediately** on entry (PO: session treated as committed) |
| Auto-start | **Yes** — §4 pipeline (3s + TTS + startCare) |
| Early end | [케어 종료] → `endCare()` → **pop to Home** (ignore remaining steps) |
| Use case | 원장이 미리 세팅 완료 후 원터치 시작 |

### 5.5 UI Matrix (PO Confirmation Required)

| Surface | A: Timer | B: Care Start | C: Care Start Quick |
|---------|----------|---------------|---------------------|
| [케어 시작] btn | ✅ | ✅ | ❌ |
| [케어 종료] btn | ❌ (until running) | ❌ (until running) | ✅ immediate |
| Auto 3s + TTS | ❌ | ❌ | ✅ |
| Stacked segment bar | After preset pick | After preset pick | Immediate |
| Timeline | After preset pick | After preset pick | Immediate |
| Chart required | ❌ | ❌ | ❌ |

### 5.6 `VisitTimerStore` Decoupling Changes (planned)

| Current (v5.2) | v5.3 Target |
|----------------|-------------|
| Fullscreen open requires `VisitSession` | `session` optional; standalone shop-scoped timer |
| `startCare()` tied to active visit | `startCare({VisitSession? link})` |
| Home preset panel | Removed; `selectedPresetSlot` set from Home quick-pick or Timer field |
| `canEndCare` anytime during care | Unchanged (`20031f9`) |

---

## 6. Store & File Migration Map (Post-Approval)

| Action | File |
|--------|------|
| **New** | `lib/features/visit/home_dashboard_controller.dart` |
| **New** | `lib/features/visit/widgets/home_hero_card.dart` |
| **New** | `lib/features/visit/widgets/home_toolbox_row.dart` |
| **New** | `lib/features/visit/widgets/memo_stack_display.dart` |
| **New** | `lib/features/visit/widgets/calendar_expand_panel.dart` |
| **New** | `lib/features/visit/widgets/countdown_flip_editor.dart` |
| **New** | `lib/features/visit/widgets/quick_calculator_sheet.dart` |
| **Refactor** | `smart_flip_timer_hero.dart` — strip preset panel, delegate to HomeHeroCard |
| **Refactor** | `visit_launcher_page.dart` — new layout order, 케어 시작 handler |
| **Refactor** | `care_timer_fullscreen_page.dart` — entryMode, program picker header, ⚙️ preset |
| **Deprecate** | `preset_expand_panel.dart` on Home (keep editor page) |
| **Deprecate** | `calendar_memo_panel.dart` bottom placement (merge into Hero) |
| **Extend** | `care_timer_tts_service.dart` — intro phrase "케어를 시작합니다" |

---

## 7. Animation Spec (CDG White Glass)

| Interaction | Duration | Curve |
|-------------|----------|-------|
| Calendar expand/collapse | 300ms | easeInOutCubic |
| Memo stack expand | 280ms | easeOutCubic |
| Calculator slide-up | 280ms | easeOutCubic |
| Hero → Care Timer | 420ms | easeInOutCubic (existing) |
| Count complete blink | 3× 1s | linear opacity 1↔0.3 |
| Segment stack step advance | 380ms | easeOutCubic (existing) |

---

## 8. Risk Register & Side-Effect Prevention

| Risk | Mitigation |
|------|------------|
| Standalone timer breaks visit report | Care sessions optionally link `visitSessionId`; report only when linked |
| Count debounce fires during digit drag | Debounce on `onTapUp` only, not `onTapDown` |
| Auto-start fires after user left page | `CareAutoStartPhase` cancelled in `dispose()` |
| Memo stack shows stale data | Listen `SoriStore` + `refreshCareScheduleEntries` on resume |
| TTS overlap with step announce | Gate: intro TTS completes before `startCare()` step TTS |
| Home layout overflow (narrow) | `FittedBox` on flip (done in `20031f9`) |

---

## 9. Acceptance Criteria (PO Sign-off)

- [ ] Home matches mockup layout order (Hero → Toolbox → Customers → Care Start)
- [ ] Preset editor **not** on Home; accessible via ⚙️ in Care Timer field
- [ ] Calendar expands from date row; memo +/− slots work
- [ ] Memo stack: today first, else nearest future with date label
- [ ] Count: digit tap cycle, 5s debounce, cancel re-tap, 3× blink return
- [ ] Calculator bottom sheet functional
- [ ] Weather/temp/UV tap → detail
- [ ] Path A/B/C routing matrix matches §5.5
- [ ] Path C: 3s + TTS + auto stacked timer
- [ ] [케어 종료] → Home, no chart required
- [ ] Zero regression on v5.2 care pause/mute/immersive

---

## 10. Open Questions — PO Decisions (Closed)

1. **차트 연동 섹션** → Home에서 **전체 제거**, ⚙️ 설정으로 이전
2. **경로 B 프로그램 선택** → **타이머 필드 내부만**
3. **경로 A 저장** → **Supabase 영구 저장** (`utility_source`, nullable `visit_session_id`)
4. **메모 삭제** → **`status=cancelled` soft delete**

---

**Next Step:** PO 마인드 컨펌 → §10 Open Questions closure → Implementation Agent 요청문 실행
