# PRD v5.4 — 홈 탭 대시보드 시각 헌법 복구 및 인터랙션 교정

**Status:** Approved · PO 마인드 Final Sign-off 2026-09-01  
**Author:** Expert Lead Engineer & UX/UI Architect  
**Requested by:** PO 마인드 · 2026-09-01  
**Supersedes:** PRD v5.3 (visual layer only — logic SSOT 유지)  
**Baseline commit:** `23e0b1c` (v5.3 implementation)  
**Reference mockups:** `케어 타이머_2.jpg` (Home), `케어 타이머 (1)_2.jpg` (Care Timer Field)  
**Rule:** **PO v5.4 컨펌 전 코드 수정·Commit 금지**

---

## 0. Executive Summary — v5.3 대비 무엇이 망가졌는가

| 영역 | PO 시안 | v5.3 구현 (`image_b751a2`) | v5.4 조치 |
|------|---------|---------------------------|-----------|
| 플립 시계 | Hero **압도적** 크기 · dark glass 타일 | `FittedBox` 축소 · 밀도 낮음 | **HomeHeroScale** 토큰 · min-height 강제 |
| 툴박스 6종 | 아이콘+라벨 **한 줄 꽉 참** · 날씨=「조금 흐림」 | 9px 라벨 · generic headline · 시각 빈약 | **HomeToolboxSpec** 픽셀 스펙 |
| 신규/재방문 | **Green** / **Dark gray-black** | 재방문=Green (오류) | **Green / #1C1C1E** |
| 케어 시작 | **Green** full-width | Green (OK) · 단독 CTA만 | 유지 + Path C 연동 |
| 하단 프리셋 리스트 | 5색 time chip + 라벨 | **전면 삭제** (v5.3) | **HomePresetQuickPick** 복원 (Path C SSOT) |
| 차트 연동 토글 | 시안에 존재 | v5.3 PO 결정으로 제거 | **v5.3 유지: 미복원** (§10) |
| 타이머 필드 칩 | Orange/Green/Yellow/Blue/Purple stack | v5.2 stacked bar (유지) | **PresetSlotTint SSOT** 픽셀 교정 |

> **PO 핵심:** v5.3의 **로직·라우팅·DB**는 유지하되, **시각 헌법(Visual Constitution)** 을 시안 픽셀에 맞게 복구한다.

---

## 1. Visual Constitution — CDG Home Dashboard Tokens

### 1.1 Canvas & Card

| Token | Value | Notes |
|-------|-------|-------|
| `canvasBg` | `#F4F6F9` | VolumeGlassTheme SSOT |
| `heroCardFill` | `#FFFFFF` @ 0.95 | White glass |
| `heroCardRadius` | `24dp` | |
| `heroCardShadow` | blur 30 · α 0.04 · offset (0,8) | |
| `heroCardPaddingH` | `16dp` | |
| `heroCardPaddingTop` | `20dp` | date → clock breathing room |
| `heroCardPaddingBottom` | `16dp` | clock → memo stack |

### 1.2 Date Row (시안 `케어 타이머_2.jpg` 상단)

```
┌──────────────────────────────────────┐
│     📅  2026년 9월 1일                │  ← center-aligned row
└──────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Layout | `Row(mainAxisAlignment: center)` |
| Calendar icon | `Icons.calendar_month_outlined` · **16dp** · `#8E8E93` · **날짜 텍스트 좌측** |
| Date text | Nunito **13sp** · w700 · `#111111` |
| Tap target | min height **44dp** |
| Expand chevron | 캘린더 펼침 시 `keyboard_arrow_up` · 접힘 시 calendar icon 유지 |

### 1.3 Flip Clock Hero (압도적 비율)

**문제:** v5.3 `FittedBox(scaleDown)` 이 narrow viewport에서 시계를 과도 축소.

**v5.4 Spec:**

| Token | Home (wallClock) | Care Field |
|-------|------------------|------------|
| `digitHeight` | **132dp** (min) | **124dp** (existing hero) |
| `digitWidth` | **82dp** | **78dp** |
| `colonSize` | **56dp** | **52dp** |
| `cornerSsScale` | **0.38** of main digit H | **0.40** |
| `style` | `FlipClockStyle.darkGlass` | same |
| `tileFill` | `#111111` | |
| `tileText` | `#FFFFFF` Nunito w800 | |
| `tileRadius` | `14dp` | |
| `flipMidline` | α 0.25 white 1dp | |
| Min hero zone height | **200dp** (clock + SS) | |

**Layout rule:** Hero card 내 clock zone은 `LayoutBuilder` + `ConstrainedBox(minHeight: 200)` — **절대 FittedBox 단독 축소 금지**. overflow 시에만 scale ≤ 0.92.

### 1.4 Memo Stack Bar (시계 직하단)

시안: 녹색 dot + 시간 + 고객명 + stack icon · **white/light pill**

| Element | Spec |
|---------|------|
| Container | full-width · h **44dp** · radius **22dp** |
| Front chip fill | `#34C759` (active/upcoming) |
| Dot | 8dp white circle · left inset 14dp |
| Text | Nunito **12sp** w700 white · `"12:30 김민정님 상담예약"` |
| Stack icon | `Icons.layers_rounded` 20dp · right 12dp · white α 0.85 |
| Fallback chip | future memo · prefix `(M/D)` · same green |
| Empty state | chip hidden · stack icon only if expanded |

**Logic:** v5.3 `MemoDisplayPolicy` **유지** — v5.4는 visual layer만 교정.

---

## 2. Toolbox Row — 6-Icon Visual Restoration

### 2.1 Container

| Spec | Value |
|------|-------|
| Card | white glass · radius **20dp** · margin H **16dp** |
| Inner padding | V **14dp** · H **4dp** |
| Row | `MainAxisAlignment.spaceEvenly` · **6 slots equal flex** |

### 2.2 Per-Slot Spec (시안 순서 고정)

| # | Icon | Label (live data) | Icon size | Label size | Active ring |
|---|------|-------------------|-----------|------------|-------------|
| 1 | `timer_outlined` | `타이머` | **24dp** | **10sp** w700 | Green `#34C759` 2dp |
| 2 | `hourglass_bottom` | `카운트` | 24dp | 10sp | Orange `#FF9500` |
| 3 | `calculate_outlined` | `계산기` | 24dp | 10sp | Blue `#007AFF` |
| 4 | `wb_cloudy_outlined` | **`조금 흐림`** (climate) | 24dp | 10sp | — |
| 5 | `thermostat_outlined` | **`32°C`** | 24dp | 10sp | — |
| 6 | `wb_sunny_outlined` | **`UV 7`** | 24dp | 10sp | — |

**금지:** `brief.headline.split(' ').first` 로 잘린 generic 라벨 — **ShopClimateService** 에서 `weatherLabelKo` 필드 사용 (fallback: `조금 흐림`).

**Tap behavior (유지 + 명시):**
- 1–3: 기존 v5.3 micro-interaction
- 4–6: **`EnvironmentDetailSheet`** (기존 `ClinicalAssistantSheet` climate section scroll-to) — **삭제 금지**

### 2.3 v5.3 Gap Analysis

```
현재: icon 20dp · label 9sp · spaceAround · mono gray
목표: icon 24dp · label 10sp · spaceEvenly · icon #111 · label #8E8E93
```

---

## 3. Customer CTA & Primary Button Colors

### 3.1 Walk-In Cards (2-up)

| Card | Background | Icon | Title | Subtitle |
|------|------------|------|-------|----------|
| **신규 고객** | `#34C759` | white `person_add` 22dp | white 15sp w800 | white α 0.85 11sp |
| **재방문 고객** | `#1C1C1E` (dark gray/black) | white `history` 22dp | white 15sp w800 | white α 0.72 11sp |

> **v5.4 PO Final:** 재방문 = **블랙/다크그레이** (White Glass 기각).

| Spec | Value |
|------|-------|
| Card radius | **24dp** |
| Card padding | 16/20dp |
| Gap between cards | **10dp** |

### 3.2 [케어 시작] Button

| Spec | Value |
|------|-------|
| Fill | `#34C759` |
| Text | white · Nunito **16sp** w800 |
| Height | **56dp** (padding V 18) |
| Radius | **18dp** |
| Width | full minus 32dp margin |
| Shadow | green tint α 0.12 blur 16 |

---

## 4. Home Preset Quick-Pick List (Path C SSOT — **v5.4 신규 복원**)

### 4.1 PO Intent (v5.3 → v5.4 Delta)

v5.3: 홈에서 프리셋 리스트 **전면 제거** → Path C = timer field에서 armed.  
**v5.4 PO 수정:** Path C = **「홈 하단 리스트에서 프리셋 지정 → 케어 시작」**

```
┌─ HomePresetQuickPick (White Card) ──────────────┐
│  [60:00 Orange]  테라노바 복부 슬리밍 관리        │  ← tap = select slot
│  [60:00 Green]   테라노바 다리 슬리밍 관리        │
│  [70:00 Yellow]  테라노바 데콜테 순환관리         │
│  ... (max 5 rows)                               │
└─────────────────────────────────────────────────┘
         ↓ slot selected + [케어 시작]
         Path C → CareTimerFullscreen (careEnd + auto TTS)
```

**NOT restored:** 「타이머 상담 차트 연동」toggle (v5.3 PO Q1 closed).

### 4.2 Row Visual Spec (시안 픽셀)

| Element | Spec |
|---------|------|
| Time chip | w **64dp** · h **36dp** · radius **18dp** · white text 13sp w800 |
| Chip colors | Slot 0→Orange `#FF9500` · 1→Green `#34C759` · 2→Yellow `#FFCC00` · 3→Blue `#007AFF` · 4→Purple `#AF52DE` |
| Time format | `MM:00` planned (e.g. `60:00`) |
| Label pill | flex · `#F4F6F9` fill · radius **14dp** · 13sp w700 `#111` |
| Selected row | label border 1.5dp chip color · α 0.45 |
| Row gap | **8dp** |
| Card padding | 16dp |

### 4.3 State

```dart
// SSOT extension
int? homeSelectedPresetSlot;  // null = Path B eligible
bool get isPathCEligible =>
  homeSelectedPresetSlot != null &&
  presetAt(homeSelectedPresetSlot!).steps.isNotEmpty;
```

---

## 5. Care Timer Field — Stacked Chip Visual (시안 `(1)_2.jpg`)

v5.2 `CareStackedSegmentBar` 로직 **유지** · visual만 교정:

| Element | Spec |
|---------|------|
| Front chip | w **96dp** h **44dp** · pulse 900ms scale 1.0↔1.05 |
| Back chips | w **72dp** h **34dp** · offset **16dp** H / **20dp** V |
| Stack depth | max **4** visible |
| `+` circle | white 32dp · black plus |
| Layers icon | 22dp · α 0.35 |
| Timeline header | 「타임라인」· chevron · 280ms expand |
| [케어 종료] | `#FF9500` full-width h **52dp** radius **18dp** |

---

## 6. Calendar & Memo Stack — Interaction Reconfirm (v5.3 유지)

| Interaction | Behavior | Animation |
|-------------|----------|-----------|
| Date tap | toggle `calendarExpanded` | `AnimatedSize` 300ms easeInOutCubic |
| Day pick | collapse calendar → open `MemoTimeSlotEditor` | sheet 280ms |
| Memo +/− | add slot +30min default · − = `status=cancelled` | — |
| Memo stack tap | expand all `scheduledAt ≥ todayStart` | 280ms |
| No memo today | show nearest future + date prefix | `MemoDisplayPolicy` |

**Data:** `care_schedule_entries` · no new table.

---

## 7. Toolbox & Timer Routing — Reconfirm + Path C Correction

### 7.1 Count Mode (변경 없음)

```
tap 카운트 → countSetup (00:00)
digit tap → 0-9 cycle · reset 5s debounce
5s idle → countRunning
0 reached → 3× blink 1s → wallClock
re-tap 카운트 → cancel
```

### 7.2 Entry Routing Matrix (v5.4 Corrected)

| Path | Trigger | Preset state | Timer field CTA | Auto pipeline |
|------|---------|--------------|-----------------|---------------|
| **A** | Toolbox **타이머** | any | **[케어 시작]** only · **NO [케어 종료]** until running | ❌ |
| **B** | **[케어 시작]** | `homeSelectedPresetSlot == null` | Program picker → **[케어 시작]** manual | ❌ |
| **C** | **[케어 시작]** | **Home list row selected** | **[케어 종료]** immediate | ✅ 3s + TTS + `startCare()` |

### 7.3 Path C Pipeline (unchanged from v5.3)

```
enter fullscreen (Path C)
  → UI settle 420ms
  → delay 3s (cancellable)
  → TTS speakAndWait("케어를 시작합니다")
  → startCare(presetSlot: homeSelectedPresetSlot)
  → stacked segment tick begins
```

**[케어 종료] during wait:** cancel Future + TTS → `finishStandaloneCare()` → pop Home.

### 7.4 Standalone Supabase Log (v5.3 유지)

- Migration **106** applied
- `utility_source = standalone_timer`
- `visit_session_id` nullable

---

## 8. Layout Order — v5.4 Home IA (Final)

```
1. HomeHeroCard        (date · calendar · flip · memo stack)
2. HomeToolboxRow      (6 icons — FULL WIDTH)
3. ActiveSessionStrip  (if care running)
4. WalkInSection       (green + white cards)
5. CareStartButton     (green full-width)
6. HomePresetQuickPick (5 colored rows — NEW)
```

---

## 9. Implementation Plan (Post-Approval)

| Phase | Scope | Files |
|-------|-------|-------|
| **V1** | Visual tokens SSOT `home_visual_tokens.dart` | new |
| **V2** | Hero scale + date row + memo bar polish | `home_hero_card.dart`, `flip_clock_display.dart` |
| **V3** | Toolbox 24dp/10sp + climate labels | `home_toolbox_row.dart`, `shop_climate_context.dart` |
| **V4** | Walk-in color fix + CareStart polish | `visit_launcher_page.dart` |
| **V5** | `HomePresetQuickPick` + Path C wiring | new widget + `visit_launcher_page.dart`, `visit_timer_store.dart` |
| **V6** | Stacked chip pixel pass | `care_stacked_segment_bar.dart` |
| **T** | Visual regression tests + golden optional | `test/home_dashboard_v54_test.dart` |

**Estimated delta:** ~8 files modified · 2 new · 0 DB migration.

---

## 10. PO Open Questions — Closed (2026-09-01)

| # | Question | Decision |
|---|----------|----------|
| 1 | 차트 연동 토글 홈 복원? | **N** — 타이머 필드 ⚙️ 설정 내부만 |
| 2 | 재방문 카드 컬러 | **Dark gray/black `#1C1C1E`** (White Glass 기각) |
| 3 | Path C slot persistence | **Y** — `SharedPreferences` `v54_home_selected_preset_*` |
| 4 | Golden test CI | **Y** — `.github/workflows/test.yml` |

---

## 11. Acceptance Criteria (PO Sign-off)

- [ ] Flip clock min height 200dp · digit H ≥ 132dp on 430×932 viewport
- [ ] Toolbox 6 icons: labels = 타이머/카운트/계산기/조금 흐림/32°C/UV 7 (live)
- [ ] 신규=Green · 재방문=Dark gray-black · 케어시작=Green
- [ ] Home preset list 5 rows with correct slot colors
- [ ] Path A/B/C matrix §7.2 exact
- [ ] Path C: list select → care start → care end visible → 3s TTS auto
- [ ] Calendar/memo/count logic unchanged from v5.3
- [ ] No chart toggle unless PO re-opens Q1

---

**Next Step:** ~~PO v5.4 컨펌~~ → Phase V1–V6 구현 완료 → Commit & Push
