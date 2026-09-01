# Hotfix Report — 홈 탭 렌더링 붕괴 (Blank Screen)

**Date:** 2026-09-01  
**Severity:** P0 · Production  
**Baseline:** `fab19fc` (v6.0)  
**Fix commit:** pending  

---

## Symptom

프로덕션 Web Release 환경에서 `VisitLauncherPage` 메인 영역이 **날짜 행(`📅 2026년 9월 1일`)만 표시**되고, 플립 시계·툴박스·워크인·프리셋 리스트가 전부 백지화.

GNB / AppBar는 정상 → **홈 `CustomScrollView` 첫 Sliver(`HomeHeroCard`) 내부 레이아웃 붕괴**.

---

## Root Cause (Confirmed)

### Primary — `OverflowBox` + Unbounded Height (v5.4 regression)

| Item | Detail |
|------|--------|
| **File** | `lib/features/visit/widgets/home_hero_card.dart:189` |
| **Widget** | `OverflowBox` inside `Column` → `SliverToBoxAdapter` → `CustomScrollView` |
| **Error** | `RenderConstrainedOverflowBox object was given an infinite size during layout` |
| **Given size** | `Size(366.0, Infinity)` |

PRD v5.4에서 `FittedBox`를 제거하고 `OverflowBox`로 교체하면서, 스크롤 가능한 부모(Column in Sliver)의 **무한 높이 제약** 하에서 OverflowBox가 **높이 ∞**로 resize되어 이후 형제 위젯·Sliver 전체가 렌더링 실패.

**재현:** `test/home_hero_render_hotfix_test.dart` — fix 전 21 exceptions.

### Secondary — Not the cause (investigated)

| Check | Result |
|-------|--------|
| Null weather / preset cache | ❌ Not root — 예외는 Layout 단계, 데이터 로드 이전 |
| Hero tag `sori_care_flip_hero` | ❌ Not root — 동일 Hero 단독 존재, 레이아웃 assert 선행 |
| `HomePresetQuickPick` Expanded | ❌ Not reached — HeroCard collapse 이후 Sliver 미렌더 |

---

## Fix

```dart
// BEFORE (broken)
Center(
  child: OverflowBox(
    maxWidth: constraints.maxWidth,
    child: clock,
  ),
)

// AFTER (fixed)
Align(
  alignment: Alignment.center,
  child: FittedBox(
    fit: BoxFit.scaleDown,
    child: clock,
  ),
)
```

- `ConstrainedBox(minHeight: 200)` 유지 — PRD v5.4 hero zone SSOT
- `FittedBox.scaleDown` — narrow viewport에서 픽셀 축소, **bounded finite size** 보장
- Hero tag 유지 — fullscreen 전환 애니메이션 SSOT

---

## Verification

- [x] `flutter test test/home_hero_render_hotfix_test.dart` — 0 exceptions
- [x] `HomeHeroCard` + `CustomScrollView` E2E widget test
- [ ] Manual prod smoke after deploy

---

## Prevention

1. `HomeHeroCard` regression test in CI (`home_hero_render_hotfix_test.dart`)
2. **금지:** `OverflowBox` / unbounded `Expanded` in Column inside `SliverToBoxAdapter`
3. v5.4 visual QA checklist: scroll viewport 430×932 필수
