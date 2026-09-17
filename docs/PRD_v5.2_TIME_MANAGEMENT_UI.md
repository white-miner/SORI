# PRD v5.2 — Time Management UI & Calendar Memo Architecture

**Status:** Approved · SSOT  
**Approved by:** PO 마인드 · 2026-09-01  
**Baseline commit:** `ee4e740` (UT-1)  
**Strategy:** Utility-First Phase 0 — 에스테틱 현장 OS

---

## 1. Executive Summary

스마트 플립 시계·케어 타이머 UI를 전면 재설계하고, 캘린더를 경량 메모 패드로 재정의한다.

| Decision | Policy |
|----------|--------|
| Preset UI | 상단 5색 칩 **폐기** → 하단 **PresetExpandPanel** |
| Care start | **수동** — 구간 바 ▶/⏸ (프리셋 선택만으로 시작 안 함) |
| Fullscreen | Care Timer Mode — 가로/세로 풀스크린 |
| TTS mute | Native only · 🔊/🔇 toggle · pause 시 TTS 억제 |
| Web TTS | 불필요 (`kIsWeb` skip) |
| Calendar | `care_schedule_entries` 재사용 · 메모 패드 |
| ENV / Atomizer | Hold |
| A-3 Sync | UI 후 병행 (Migration 105, multi-device) |

---

## 2. Screen Modes

### 2.1 Wall Clock Mode (Home Hero)

- Default Operation Desk view
- Flip clock: **HH:MM only** (no seconds)
- Dark glass digits on white glass card (CDG)
- Red timer icon when session active
- **No** top preset chips
- Bottom: `[타이머 프리셋 설정 및 선택]` → expand panel

### 2.2 Preset Expanded

- Max 5 presets from `CareProgramTemplate` slots 0–4
- Row: tint dot + name (5–12 chars, ellipsis) + step count + chevron
- Empty slot: `+ 설정` → `CareTimerPresetEditorPage`
- Select filled preset → **Care Timer Fullscreen** (smooth transition, no auto-start)

### 2.3 Care Timer Fullscreen Mode

- Top: segment bar (planned MM:SS per step, ▶/⏸ on first segment)
- Active segment: pulsating animation (900ms, scale 1.0↔1.06)
- Main flip: **total care elapsed** HH:MM + small SS corner
- TTS mute toggle top-right
- Pause: freeze flip + **no TTS**
- Step colors: `PresetSlotTint` base + per-step opacity ladder (D-4)

### 2.4 Mini Timer Strip (Home)

- Visible when care timer running and user left fullscreen
- Reuses `ActiveSessionStrip` pattern
- Prevents timeout when opening calendar memo or chart

---

## 3. Implementation Phases

| Phase | Scope | Status |
|-------|-------|--------|
| **A** | Wall Clock hero + `PresetExpandPanel` | Done (`7693514`) |
| **B** | `CareTimerFullscreenPage` + segment bar + transitions | Done (`17a54e4`) |
| **C** | `pauseCare`/`resumeCare`, TTS mute, seconds flip | Done (bundled in B) |
| **D** | `CalendarMemoPanel` (월/주/일) | Done |
| **E** | A-3 Migration 105 + sync E2E | Done |
| **F** | Social dead-code prune (optional) | Done |

---

## 4. Store Changes (Phase B–C)

| API | Purpose |
|-----|---------|
| `bindPreset(int slot)` | Load template, `prep`, no `careStartedAt` |
| `pauseCare()` / `resumeCare()` | Manual pause with accumulated pause seconds |
| `carePausedAt` / `isPaused` | Tick + TTS gate |

---

## 5. Calendar Memo Pad (Phase D)

- **Table:** `care_schedule_entries` (no new table B-1)
- **Fields:** `scheduled_at`, `note`, `customer_name`, `care_label`
- **Placement:** collapsible panel on Operation Desk (B-2)
- **Separate from:** `TodayCareSchedulePanel` on customer tab (chart history, B-3)

---

## 6. Policy Ledger (§12 Approved)

| ID | Decision |
|----|----------|
| A-1–A-6 | Y — default architecture |
| B-1–B-3 | Y — reuse schedule entries, collapsible memo, keep customer panel |
| C-4 | Y — sync after UI shell |
| D-1 | Y — no TTS while paused |
| D-2 | Y — mini timer strip on home |
| D-3 | N — no PO mock images; CDG white glass |
| D-4 | Y — tint base + step opacity variation |

---

## 7. File Map

| File | Role |
|------|------|
| `lib/features/operation/widgets/preset_expand_panel.dart` | Expandable preset list |
| `lib/features/visit/widgets/smart_flip_timer_hero.dart` | Wall clock hero |
| `lib/features/operation/widgets/care_timer_fullscreen_page.dart` | Phase B |
| `lib/features/operation/widgets/care_segment_bar.dart` | Phase B |
| `lib/features/visit/widgets/active_session_strip.dart` | Mini strip (D-2) |
| `lib/visit_kernel/models/preset_slot_tint.dart` | Step color ladder |

---

## 8. Animation Specs

| Transition | Duration | Curve |
|------------|----------|-------|
| Preset panel expand | 300ms | `easeInOutCubic` |
| Wall → Fullscreen | 350ms | `easeInOutCubic` + Hero flip |
| Segment pulsate | 900ms | `easeInOut` loop |

---

*End of PRD v5.2 SSOT*
