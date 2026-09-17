# SORI 글래스 물성 · GPU 성능 계약

**Status:** Locked · Cursor Agent 절대 구현 계약  
**작성:** 2026-09-11 · PO  
**연관:** `docs/SORI_DESIGN_LAWS.md` (언제 glass) · 본 문서 (어떻게 싸게)

## 절대 원칙

```text
Glass = 기능 레이어 (floating only)
Blur = 정적 · 애니메이션 금지
한 화면 BackdropFilter ≤ 1~3개 · 면적 ≤ 35%
중첩 blur / full-screen blur / list-row blur 금지
지도 위: GPS·저장함·Peek 정도만
Half↑ = opacity 강화 · Expanded = opaque
Opacity 위젯 대신 Color.withValues(alpha:)
RepaintBoundary = profile 증거 후에만
```

## Flutter

- `BackdropFilter`는 **최소 `ClipRRect` bounds** 안만.
- blur sigma 기본 **8–12**, 최대 **16**(예외 승인).
- press: `Transform.scale(0.97)` · 80–110ms / release 160–220ms · blur/shadow animate 금지.
- sheet drag ≠ MapCanvas / tile / marker / API rebuild.

## 우리지역 지도 예산

| Surface | Blur | Fill |
|---------|-----:|------|
| GPS / 저장함 | 8px clip | white ~78–90% (지도 위) |
| Peek | 0~12px 또는 없음 | 78–90% |
| Half | 0~8px | 88–94% |
| Expanded | **0** | opaque 90%+ |
| map overlay / marker | **0** | — |

## GPU 한 줄

> 유리는 blur가 아니라 **투명도·테두리·하이라이트·짧은 반응**으로 만든다. 실 blur는 작은 고정 surface에만.

## Cursor 복붙

```md
# SORI Glass Performance + GPU
- BackdropFilter ≤1–3 / screen, clipped small, static, sigma 8–12 (max 16)
- No full-screen / nested / list-row / animated blur
- Color alpha > Opacity widget; borderRadius > unnecessary Clip
- Map: GPS+saved+Peek may glass; Half opaque↑; Expanded solid
- Sheet drag ≠ map repaint/refetch; RepaintBoundary only after profile
```
