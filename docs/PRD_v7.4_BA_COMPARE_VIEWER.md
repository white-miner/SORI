# PRD v7.4 — B/A 비교 뷰어 전면 개편

- 문서 성격: **기획**. PO 컨펌 전까지 `lib/` 무수정.
- 대상: `lib/views/before_after_compare_page.dart`, 공용 `lib/widgets/before_after_slider.dart`(비교 호출부만 맞춤, 포크 금지).
- 작성일: 2026-09-03.

---

## §0 판정

비교 뷰어의 슬라이더가 튀는 것은 **새 슬라이더가 필요해서가 아니다.** 홈 관리 케이스와 같은 `BeforeAfterSlider`를 쓰면서, 비교 페이지만 `InteractiveViewer` + `dragHandleOnly` + `BoxFit.contain` + 글래스 패딩을 얹었기 때문이다.

하단 칩이 안 보이는 것은 **흰 배경에 흰 글자**다. `_SlotChip`이 `ActionChip`을 쓰고, 다크 페이지 위에서 M3 칩 테마가 밝은 면을 깐 뒤 라벨 `Colors.white`가 그대로 올라간다. 테마 패치로 살리지 않고 폐기한다.

---

## §1 슬라이더 지터 — 원인과 동기화

| | 홈 관리 케이스 | B/A 비교 페이지 |
|---|---|---|
| 위젯 | `BeforeAfterSlider` | 동일 |
| 제스처 | 전면 가로 드래그 (`dragHandleOnly: false`) | `InteractiveViewer` 팬 + 핸들 44dp만 (`true`) |
| 좌표 | `localPosition.dx / width` | `handle.localDx + split - 22` |
| 핏 | `BoxFit.cover` | `BoxFit.contain` |
| 프레임 | 카드 폭, radius 0 | padding 8/118/96, radius 20 |

핸들 공식은 `split`이 `setState`로 바뀌는 동안 `localPosition`을 더한다. InteractiveViewer 변환까지 겹치면 한 프레임씩 어긋나 점이 뛴다.

**처방 (S1):** `_ZoomableCompareBody` 슬라이더 모드에서 `InteractiveViewer`를 제거한다. `dragHandleOnly: false`. `height = constraints.maxHeight`, `maxHeight` 동일, `aspectRatio` 없음, `borderRadius: BorderRadius.zero`. 공용 슬라이더 파일은 피드가 이미 안정이므로 **포크하지 않는다.**

**핀치 줌 (Q4 권고):** 슬라이더 모드에서는 포기한다. 한 손가락 비교가 본업이다. 나란히 모드의 패널별 `InteractiveViewer`는 유지한다.

---

## §2 여백 — 확대가 목적이다

`_CompareStage`가 글래스 바를 피하려고 사진을 안쪽으로 민다 (`EdgeInsets.fromLTRB(8, 118, 8, 96)` 세로, `all(8)` 가로). `BoxFit.contain`이 그 안에 레터박스를 또 만든다.

**처방 (S2):** 스테이지는 `Positioned.fill` 풀블리드. 상·하 컨트롤은 사진 **위** 오버레이. `ChartImagePane(fit: BoxFit.cover)` — 피드와 동일해야 좌우 크롭 기준이 맞는다. contain을 남기면 검은 띠가 다시 생긴다.

가로 모드: 사진 영역 비율을 73%에서 **78~80%**로 올리고, 우측 패널은 프로그램·모드만 남긴다. 썸네일 스택은 우측 Wrap이 아니라 **사진 하단 오버레이**다.

---

## §3 스토리형 썸네일 스택

`VisitPhotoSlot.shortLabel`은 이미 `N회차 · B/A`다. URL도 슬롯에 있다. 데이터 모델 변경은 없다.

**BaStoryStrip (신설)**

- 가로 `ListView`.
- 아이템: 64×64, `BorderRadius.circular(18)` 스퀘어 라운드, `ChartImagePane` 썸네일 (`BoxFit.cover`).
- 라벨: 아래 11sp `shortLabel` (공백 없이 `N회차 B`로 줄여도 됨).
- **원형 금지 권고.** 인스타 스토리는 제스처 레퍼런스다. 원은 임상 얼굴의 이마·턱을 자른다.
- 선택: 흰 링 1.5dp. 왼쪽 슬롯 / 오른쪽 슬롯을 링+ L·R 뱃지로 구분.
- `ActionChip` / `_SlotChip` / 하단 32h 칩 ListView **삭제**.

**바인딩 타깃**

- `_bindSide`: `left | right`. 기본 `right` (현행 `onPick`).
- 좌·우 드롭다운 또는 뷰어 왼쪽/오른쪽 절반 탭 → 타깃 변경.
- 스트립 tap / 롱프레스 end → `_bindSide`에 해당 슬롯을 넣는다.

---

## §4 Dock 프리뷰 — 구현 방식

아이템별 `AnimationController`를 두지 않는다. 스트립 State가 `int? hoverIndex`와 `bool magnifying`만 가진다.

```
onTap                    → bind(slot, side)
onLongPressStart         → magnifying=true, hover=index, HapticFeedback.mediumImpact
onLongPressMoveUpdate    → global X로 index 재계산, 바뀌면 lightImpact
onLongPressEnd / cancel  → bind(hover), magnifying=false
```

시각: hover 아이템 `scale 1.38`, `translateY -18`. 양쪽 이웃 `scale 1.12`. `AnimatedScale` + `AnimatedSlide`, duration 80ms, curve `easeOut`.

스크롤 충돌: `magnifying == true`이면 `NeverScrollableScrollPhysics`, 아니면 `BouncingScrollPhysics`. 일반 플릭은 가로 스크롤.

미리보기 중에는 메인 슬라이더를 바꾸지 않는다. 손을 떼야 바인딩한다 (PO: Drag End / Tap).

---

## §5 위젯 트리 (컨펌 후)

```
BeforeAfterComparePage
  landscape Row
    Expanded 78  Stack
      fill     BeforeAfterSlider   // 피드와 동일 제스처
      top      slim back + title
      bottom   BaStoryStrip
    Expanded 22  program / L-R labels / 슬라이더|나란히
  portrait Stack
    fill     BeforeAfterSlider
    top      slim glass (back, program, L/R)
    bottom   mode + BaStoryStrip
```

건드릴 파일: `before_after_compare_page.dart` 중심. 신설 `ba_story_strip.dart`. `before_after_slider.dart`는 비교 호출 인자만 피드와 맞춘다.

---

## §6 PO 결정

**Q1 — 핏**
- (a) `BoxFit.cover` 풀블리드 (**권고**, 피드와 동일)
- (b) `contain` 유지 (얼굴 전체, 레터박스 감수)

**Q2 — 썸네일 모양**
- (a) 스퀘어 라운드 64dp (**권고**)
- (b) 원형 (스토리 픽셀 복제)

**Q3 — 바인딩 기본 슬롯**
- (a) 마지막에 만진 쪽, 기본 오른쪽 (**권고**)
- (b) 항상 오른쪽만 (현행 칩과 동일, L은 드롭다운만)

**Q4 — 줌 (PO 수정 승인)**
- 핀치 / `InteractiveViewer`는 슬라이더·나란히 **둘 다 제거**.
- 오버레이 `[+][-]`가 `1.0 → 1.5 → 2.0` 고정 배율로 `AnimatedScale` 한다.

구현 완료: S1 피드 제스처 동기화 · S2 cover 풀블리드 · S3 `BaStoryStrip` · S4 hoverIndex 80ms 팝 · 버튼 줌.
