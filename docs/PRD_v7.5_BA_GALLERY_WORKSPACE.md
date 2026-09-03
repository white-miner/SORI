# PRD v7.5 — B/A 갤러리 워크스페이스

- 작성일: 2026-09-03
- 대상: `BeforeAfterComparePage`를 사이드 패널 뷰어에서 **풀블리드 드래그 워크스페이스**로 교체.

---

## §0 판정

현행 비교 페이지는 사진 위에 드롭다운·모드 칩·스토리 스택을 얹은 **뷰어**다. 와이어프레임은 그 반대다. 사진이 바닥이고, 고객·케어·슬롯·필름이 손으로 만지는 **작업대**다.

가로 78/22 사이드 패널은 폐기한다. **풀블리드 `BoxFit.cover` + 사진 위 오버레이도 폐기한다.** 사진은 `BoxFit.contain`으로 검은 매트 안에 담고, 헤더·좌우 레일·하단 독은 그 여백(조종석)에 둔다.

슬라이더 지터를 막기 위해 `InteractiveViewer`는 다시 넣지 않는다. 줌은 버튼 스텝(0.5 / 1 / 1.5 / 2). Y 이동은 합성 사진 하나의 `panY`다.

---

## §1 위젯 트리

```
SafeArea > Column
  TopChrome                 뒤로 · 케어 필 · ⋮
  Expanded > Row
    Y rail ~52
    Photo DropZone          contain + 라벨. 드래그 중 중앙 타깃
    Right rail ~84          프로필 · 모드 · 줌
  BaWorkspaceDock           Before웰 | 필름 | After웰
```

---

## §2 자석 바인딩

- `_bindSide`: `left`(Before, `SoriTokens.cameraYellow`) | `right`(After, `SoriTokens.alignEmerald`).
- 웰 탭: 비활성이면 활성화. 이미 활성이면 `ScaleTransition` 1.0→1.1→1.0.
- 필름: `LongPressDraggable<VisitPhotoSlot>`. 피드백은 `BaDragGhost` 220dp.
- 메인 사진 영역 전체 = `ba-compare-drop-zone`. 중앙 드롭은 활성 슬롯으로 라우팅.
- `DragTarget` 웰: 그 슬롯에 바인딩.
- 웰 밖·중앙 드롭: 활성 슬롯에 바인딩 (자석).
- 드롭 시 `HapticFeedback.lightImpact()`.
- 메인 뷰어와 웰 썸네일은 같은 `_left` / `_right`.

---

## §3 Y 동기화

상태 하나 `panY`. 좌우 `TransformationController`를 두지 않는다. 나란히여도 합성 Row 전체를 옮긴다.

- 줌 ≤ 1: `panY = 0`, 화살표 no-op.
- 줌 > 1: 화살표 ±28px, 세로 드래그. clamp `±(zoom-1)*h/2`.

---

## §4 컨텍스트

| UI | 경로 |
|---|---|
| 프로필 | `showVisitCustomerPickerSheet` → `chartsForCustomer` 재시드 |
| 케어 필 | `CareProgramGroup` 아코디언 (Material Dropdown 폐기) |
| 모드 아이콘 | 기본 슬라이더. 탭마다 나란히 토글 |
| 뒤로 `<` | `Navigator.pop` — 피드에서 왔으면 피드 |
| 나가기 | `go(AppPaths.appHome)` |
| 촬영 | `SmartGuideCameraPage.open` After 우선, 고스트=현재 Before URL |
| 저장 | 크롬 없는 합성 PNG → `PhotoManager.editor.saveImage` |
| 공유 | 같은 PNG + `Share.shareXFiles` |
| 피드에 추가 | 같은 회차 B/A만 관리 케이스 피드 대상. 합성 비교는 행이 아님 — 안내 |

`openBeforeAfterComparePage`에 `store`, `customerId`를 넘긴다. 테스트는 store 없이 크롬만 렌더.

---

## §5 슬라이스

- W1 풀블리드 오버레이
- W2 웰·자석·햅틱
- W3 panY
- W4 케어·프로필·모드
- W5 더보기 5종

`BeforeAfterSlider` 포크 금지.
