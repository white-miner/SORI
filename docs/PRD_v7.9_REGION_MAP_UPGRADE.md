# SORI — 우리지역 맵 고도화 (조사 잠금)

**Status:** Draft · 기능 계약 잠금 + **미학/검수 계약 보강** · 코드는 부분 구현(부채 있음)  
**작성:** Cursor (2026-09-11) · 미학 보강 동시  
**분업 잠금:** Perplexity/PO = 근거·선택지·금지·문구·미감 검수 · Cursor = 작은 범위 **코드 계약** 구현. Cursor에게 “UI 개선해줘”만 주지 않는다.

**전제 (이미 잠김 · 재조사 금지):**

- GPS = 사용자 **탭 후**만 요청 · 거부/실패 시 Shop/Biz 중심 **유지** · `mapCenter=null`로 덮지 않음  
- 가짜 서울/대한민국 중심 **금지**  
- Kakao REST Key = Edge Secret만 · Flutter Web 번들 금지  
- 고객·Visit·내부 B/A·미동의 사진·매출/인기 지표 = 지도 **절대 비노출**  
- FloatingPillNav clearance = **scroll content bottom padding** (`SafeArea + kSoriFloatingNavClearance + 16`)  
- Phase C 배포분: Biz 폴백 · center 전달 · 주소 CTA (GPS CTA는 C.1)  
- **저장은 상세에서만** · 맵 버튼/마커/Peek는 저장함 **입구·미리보기**만 (Peek에 저장 토글 넣은 현행 코드는 **계약 부채 → C.2 정정**)

**구현 부채 (문서 > 코드):** C.4 detent sheet 미착수 · 클러스터 미착수 · 118 마이그레이션 미적용 · C.S1은 URL 교체만 하고 **후보 비교 검수 미완** · Peek 저장 토글은 §3과 충돌.

---

## 1. 제품 정의

지도는 길찾기 앱이 아니라 **지역 커뮤니티 탐색 surface**.

```
지도 중심 → 주변 글/세미나 발견 → 마커·클러스터 → 하단 시트 → 저장/상세
```

---

## 2. 우측 상단 floating control (MVP = 2개)

| # | 라벨(semantics) | 역할 | 금지 |
|---|-----------------|------|------|
| 1 | `현재 위치로 보기` | GPS 1회 중심 이동 | 자동 권한 · 위치 이력 저장 · 실시간 추적 |
| 2 | `저장한 지역 콘텐츠 보기` | 저장함 sheet | 카메라 좌표 저장 · 미구현 더미 버튼 |

- hit ≥ **48×48dp** · 시각 40–44 · 간격 ≥8 · AppBar 아래 8–12 · 우측 inset 12–16  
- 최대 **2개**. 필터·작성·검색은 여기 두지 않음.  
- pan/zoom 후 GPS **활성 상태 해제**(1회성 이동만).

---

## 3. 저장함 (즐겨찾기) 계약

| 대상 | MVP | 저장 행동 위치 |
|------|-----|----------------|
| 커뮤니티 글 | Yes | **상세** 북마크 |
| 세미나 | Yes | **상세** 북마크 |
| 공개 B/A | 조건부 | 상세만 |
| 관심 지역·샵·GPS 이력·카메라 좌표 | No/후속 | — |

맵 우측 상단 = **저장함 열기만**. 마커/클러스터에서 저장 금지.  
미구현이면 버튼 **미노출**(가짜 빈 저장함 금지).

---

## 4. 마커 · 클러스터

| 객체 | 초기 | 탭 |
|------|------|-----|
| 커뮤니티 글 | Yes | Peek preview sheet |
| 세미나 | Yes | Peek preview sheet |
| 공개 B/A·샵 | 조건부/후속 | — |
| 고객/Visit/내부 B/A | **금지** | — |

- 낮은 줌: 수량 클러스터 (`99+` 상한) · 탭 → **bounds 확대**(즉시 상세 금지)  
- 높은 줌: 개별 마커 · 탭 → **하단 sheet**(말풍선 비권고)  
- 동일 좌표: spiderfy **금지** → `이 위치의 이야기 N개` 목록 sheet  
- 색상 = 유형만 · 인기/매출 색 금지

---

## 5. 필터 · 하단 sheet

초기 필터 **3개만:** `[전체] [글] [세미나]`

| Detent | 비율(권고) | 용도 |
|--------|------------|------|
| Peek | 0.20–0.24 | 단일 마커 식별 · CTA 1개 · 저장 |
| Half | 0.46–0.54 | 클러스터/지역 목록 2–4행 |
| Expanded | **≤0.70** | 짧은 목록 · 긴 탐색은 `전체 보기` route |

- **Standard(비모달)** sheet · PillNav **노출·탭 가능**  
- Modal = 삭제/신고/권한 설명만  
- 단일 `DraggableScrollableSheet` ScrollController → 내부 `CustomScrollView`  
- Peek/Half 위로 drag = 높이 먼저 · Expanded 후 목록 스크롤 · 목록 0에서 아래 = 축소

---

## 6. GPS 상태 카피 (잠금)

| 상태 | 문구 |
|------|------|
| 활성 | `현재 위치 주변을 보고 있어요.` |
| 거부 | `현재 위치 없이 샵 주소 기준으로 보고 있어요.` |
| 실패 | `현재 위치를 확인하지 못했어요. 샵 주소 기준으로 보여드릴게요.` |
| 주소 없음 | `우리 지역의 글을 보려면 샵 주소를 등록해 주세요.` |

---

## 7. Expand Phase (승인 후 · ≤5파일/회)

| Phase | 범위 | 선행 | 비범위 |
|-------|------|------|--------|
| **C.1** | GPS 버튼 + geolocator(또는 웹 Geolocation) · 1회 중심 · 거부 폴백 | Phase C 배포 | 저장함·마커 |
| **C.S1** | **미학 검수 Phase** · 상세: `docs/PRD_v7.9_REGION_MAP_CS1_BASEMAP.md` · 동일 fixture로 0/A/B/C 비교 후 **1 URL 잠금** | PO 미감 선택 + 키/약관 | ColorFilter · 비교 없이 운영 URL 교체 · Pastel 1순위 |
| **C.2** | 저장함 버튼 + 글/세미나 북마크 SSOT·목록 sheet | 저장 객체 계약 | 관심지역·샵저장 |
| **C.3** | 글·세미나 마커 + 클러스터 + Peek sheet | 공개 위치 정책 | B/A 핀·상권 히트맵 |
| **C.4** | Half/Expanded≤0.70 · 필터3 · idle debounce · **sheet drag≠map rebuild** · InteractiveFlag | C.3 | full-screen drag detector · NestedScrollView · rotate |
| **C.S2** | MapTiler(또는 동급) **SORI Local Light** 커스텀 · Edge 키 · POI/라벨 축소 | C.S1 + 비용/키 승인 | 자체 타일서버 · Mapbox SDK 전면 교체(별도) |
| **C.5+** | 관심 지역 · 내 샵 공개 마커 · 추천 | 별도 PRD | — |

**공통 금지:** Timer · Payment · SQL 파괴 · 고객/Visit 지도 · REST 키 클라 · 가짜 중심 · spiderfy · 우측 상단 3개 이상 · 지도 CSS filter / 전면 반투명 감성 overlay · §13.3 미학 금지 전체.

---

## 8. PO 승인 문구 (복붙)

### C.1

> Phase C.1 승인: 우리지역 맵 우측 상단에 `현재 위치로 보기`만 추가한다. 탭 후에만 위치 요청·1회 중심 이동. 거부/실패 시 Shop/Biz 중심 유지·null 덮어쓰기 금지. 저장함·마커·클러스터·하단 sheet 고도화 비범위.

### C.2

> Phase C.2 승인: 우측 상단 `저장함` + 글/세미나 상세 북마크만. 맵에서 저장 금지. 미구현 더미 금지.

### C.3

> Phase C.3 승인: 공개 글·세미나 마커와 수량 클러스터, 탭→Peek standard sheet. spiderfy·고객/Visit/내부 B/A 금지.

### C.4 (시트·성능·제스처)

> Phase C.4 승인: Half/Expanded(≤0.70)·필터3·viewport idle debounce. Sheet drag는 MapCanvas/타일/마커/클러스터/네트워크를 rebuild·재요청하지 않는다. Stack(Map, Controls, DraggableScrollableSheet) bounds 분리 · full-screen drag detector 금지 · InteractiveFlag에서 rotate·doubleTapDragZoom off.

### C.S1 (베이스맵 · 미학 검수)

> Phase C.S1 승인: 상세 검수는 `docs/PRD_v7.9_REGION_MAP_CS1_BASEMAP.md`를 따른다. 목표는 URL 교체가 아니라 Quiet Local Canvas **1개 선정**. 비교 세트 = OSM(0) · Stadia Alidade Smooth(A·1순위) · MapTiler Base Light(B) · Dataviz Light(C). 동일 fixture(글4·세미나2·cluster·Peek·controls) 스크린샷·CORS·attribution·키(클라 하드코딩 금지) 제출 후 PO가 잠근다. **PO 선택 전 운영 tile URL 교체 금지.** ColorFilter·overlay·위성·Pastel 1순위 금지. 현행 Carto light_all은 임시 부채로 취급한다.

### C.S2 (SORI Local Light)

> Phase C.S2 승인: MapTiler(또는 동급)에서 SORI Local Light 커스텀 스타일 고정·Edge 키만. 도로/POI/라벨 축소. 클라에 스타일 API 키 하드코딩 금지.

---

## 9. 시각 위계 (미학 계약 · 추가 잠금)

지도는 그림이 아니라 **콘텐츠를 받치는 캔버스**.

```
1순위: 이 동네의 글·세미나
2순위: 선택한 콘텐츠
3순위: 지도상 어디쯤인가
4순위: 도로·공원·지명(방향 보조)
```

| 시각 요소 | 우선순위 | 원칙 |
|-----------|---------:|------|
| 선택 콘텐츠 | 1 | ring + Peek + **CTA 1개** |
| 마커/클러스터 | 2 | 의미색 ≤2 · 수량·유형만 |
| 하단 sheet | 3 | 웜 뉴트럴 · 유형→제목→동네/시간→CTA |
| 우측 controls | 4 | ≤2 · 지도보다 튀지 않음 |
| 베이스맵 | 5 | 저채도·POI 최소화 |
| 도로·건물·라벨 | 6 | 방향에 필요한 수준만 |

목표 인상:

```
조용한 지도 → 명확한 콘텐츠 마커 → 하나의 이야기 → Peek → 상세/저장
```

금지 인상: 도로·POI가 주인공 · 마커 묻힘 · 시트/GPS가 다른 디자인 언어 · “지도 위에 버튼 얹은 화면”.

---

## 10. Sheet 성능 계약 (추가 조사 잠금)

**끊김의 주원인:** detent 변화마다 지도·마커·클러스터·목록을 통째로 rebuild/paint.

| 상태 | MapCanvas / 타일 / 마커 / query | Sheet |
|------|----------------------------------|-------|
| Peek↔Half↔Expanded **drag** | **변경 금지** | 크기·scroll만 |
| snap 완료 | 변경 금지 | lazy list만 |
| 마커 탭 | 선택 ID + 약한 pan 1회 | Peek 콘텐츠 |
| map pan/zoom | camera · **idle 후** query | Peek 닫기/최소화 |
| 필터 | 중심 유지 · marker 재조회 | detent 유지 |
| 저장 토글 | 전체 마커 색 재구성 **금지** | 해당 item만 |

상태 분리 (한 `setState`에 묶지 않음):

```
MapCamera ≠ MapContentQuery ≠ SelectedMarker ≠ SheetDetent ≠ SheetScroll
```

| Detent | 값 |
|--------|-----|
| Peek / initial / min | **0.22** |
| Half | **0.50** |
| Expanded max | **0.70** |
| snap | `true` · `snapSizes: [0.22, 0.50, 0.70]` |

- `DraggableScrollableController` = State 멤버 1개 · `build()`에서 생성 금지 · `isAttached` 확인  
- drag 중 프로그램 `animateTo()` **금지**  
- 네트워크: drag/scroll 중 **0건** · camera idle debounce **250–400ms** · scroll page **150–250ms**  
- `RepaintBoundary` / clustering plugin = **profile 후** 최소 적용 (추측 적용 금지)  
- 동시 애니: sheet height만 · map pan+marker scale+fade 동시 실행 금지 · detent ~180–260ms

---

## 11. 제스처 충돌 계약 (추가 조사 잠금)

```
Stack(MapCanvas, RightControls, DraggableScrollableSheet)
```

| 금지 | 이유 |
|------|------|
| `Positioned.fill` + `onVerticalDragUpdate` | map pan 탈취 |
| standard sheet 뒤 full scrim / AbsorbPointer | 지도 죽음 |
| NestedScrollView · 이중 ListView · 독립 ScrollController | handoff/snap 실패 |
| GestureArenaTeam / RawGestureDetector (MVP) | 과도 · bounds 분리 우선 |

| 터치 시작 | 소유 |
|-----------|------|
| Modal | Modal |
| Sheet bounds 세로 drag | Sheet / list |
| GPS·저장함 | Control |
| Marker / cluster tap | Marker / cluster |
| Map 빈 영역 | FlutterMap |

Sheet = **자기 사각형만** hit-test. Standard preview에서 map 입력 유지.

**flutter_map InteractiveFlag (권고):**

- On: drag · pinchZoom · pinchMove · fling · tap  
- Off: **rotate** · doubleTapDragZoom · (선택) doubleTapZoom(빈 영역 선택 해제 빠르게)  
- Web wheel: **map hover일 때만** zoom · sheet bounds 안은 목록 scroll · 전역 wheel 가로채기 금지

마커 탭: Peek 유지+콘텐츠 교체 · Half/Expanded→Peek · pan 시작→선택 해제+Peek 닫기/최소화.

---

## 13. 베이스맵 미감 — Quiet Local Canvas (추가 조사 잠금)

**원칙:** 지도는 배경. 마커·클러스터·하단 시트가 주인공. 엔진 전면 교체 없이 **타일 스타일**로 해결.

| 콘셉트 | 내용 |
|--------|------|
| 이름 | **SORI Local Light** (단일 라이트 테마 · 다크는 후속) |
| 분위기 잠금 | **B(Soft Urban) ↔ C(Monochrome Focus) 중간** — 과한 Warm Paper 베이지 지양 |
| 코드(현재) | Carto `light_all` **임시** · C.S1 공식 후보(A/B/C) 비교·잠금 전 · 운영 확정 아님 |

| 토큰(초안) | 예시 |
|------------|------|
| Background | `#F7F5F1` |
| Building | `#EEECE7` |
| Minor / Major road | `#F3F1EC` / `#DDD8CF` |
| Park / Water | `#E3EEE4` / `#E6F0F5` |
| Label / Boundary | `#6F6B64` / `#D9D4CC` |
| Markers | 커뮤니티 1색 · 세미나 1색 · 선택 = ring + 1.05–1.1 · **파스텔 5색 금지** |

| 방식 | SORI |
|------|------|
| OSM 기본 유지 | 비권고(종이 지도 톤) |
| 공개 라이트 래스터 URL 교체 | **C.S1 (비교 후 잠금)** |
| MapTiler/Mapbox 커스텀 벡터 | **C.S2** (중장기) |
| ColorFilter / 베이지 overlay / 종이질감 | **금지** |
| 자체 타일 서버 | 비권고 |

표시: 주요 도로·공원·물·주요 지명 · 높은 줌에서만 세부 도로/건물.  
숨김: 카페·관광 POI 과밀 · 혼잡/위성/지형 · 진한 건물 외곽 · 저줌 과도 도로.

키·약관: 타일/스타일 API 키는 **Kakao와 동일 — Edge/서버 Secret · Web 도메인 제한 · Flutter 번들 금지**. attribution 유지.

### 13.1 C.S1 베이스맵 통과/탈락 기준

| 항목 | 통과 | 탈락 |
|------|------|------|
| 도로 대비 | 주요 도로만 구분 · 생활도로는 배경 | 도로 격자가 주인공 |
| POI 밀도 | 공원·물·주요 지명 중심 | 카페·식당·주차 라벨 > SORI 마커 |
| 건물 | 낮은 대비 면 | 진한 외곽·회색 블록 과다 |
| 라벨 | 한글 읽히되 방해 안 함 | 콘텐츠 압도 |
| 색감 | Soft Urban↔Monochrome 중간 | 누런 종이·파스텔 필터·교통색 |
| 마커 대비 | 글/세미나 마커 **1초 내** 인지 | 베이스맵 POI와 구별 실패 |
| 시트 조화 | 웜 뉴트럴 sheet와 이질감 없음 | sheet만 고급·지도만 구형 OSM |
| 줌별 정보 | 저줌 단순 · 고줌만 세부 | 저줌부터 난립 |
| Web | CORS·Referer·attribution·로딩 안정 | 빈 타일·워터마크·느림 |

### 13.2 C.S1 비교 프로토콜

전체 절차·점수표·탈락·Cursor 브리프 → **`docs/PRD_v7.9_REGION_MAP_CS1_BASEMAP.md`**.

추천 순위(채택은 검수 후): **1 Stadia Alidade Smooth · 2 MapTiler Base Light · 3 Dataviz Light · 0 OSM=기준선**.  
PO 선택 전 운영 URL 교체 금지.

### 13.3 미학적 금지 (Cursor 범용 UI 차단)

| 금지 | 대안 |
|------|------|
| OSM 유지 + 마커만 꾸미기 | Quiet Local Canvas 타일 선정 |
| 모든 컨트롤을 동일 흰 원형 | GPS/저장만 우측 · 나머지는 다른 surface |
| 지도 위 배지 다수(글 N·세미나 N…) | sheet 헤더 하나로 통합 |
| 마커에 썸네일·작성자·좋아요·댓글 | 유형·수량·선택만 |
| 선택 마커 과대 확대/바운스 | 1.05–1.10 + ring |
| 클러스터 그라데이션 원 | 단색 circle + 수량 |
| 핑크·보라·민트 다색 마커 | 글 1색 · 세미나 1색 · 선택 ring |
| glassmorphism 남발 | controls 절제 · sheet는 filled |
| sheet 안 카드 안 카드 안 칩 | 단일 surface + divider/여백 |
| pan마다 강한 카메라 애니 | GPS·cluster bounds·명시 선택만 |

권장 미감 요약: Soft Urban/near-mono 베이스 · controls 작은 tool stack(GPS 활성만 ring) · 저장함 outline bookmark · 글 단색 / 세미나 보조색+작은 달력 glyph · sheet = 유형→제목→동네/시간→CTA 1개 · 큰 shadow·과한 round-card 금지.

---

## 14. 운영 분업 · Cursor 디자인 프롬프트

| 단계 | Cursor | Perplexity / PO |
|------|--------|-----------------|
| C.1 | 권한·폴백 계약 구현 | 허용/거부/timeout UX |
| C.S1 | 비교 하네스(칩)·후보 URL · **운영 기본 OSM** · 비교 로그 | 스크린샷·점수·1후보 잠금 (`CS1_COMPARE_LOG`) |
| C.2 | 저장 SSOT·목록·빈 상태 · **맵에서 저장 금지 정정** | 저장 의미 자연스러움 |
| C.3 | 공개 객체·zoom·Peek | 밀도·색·공개성 |
| C.4 | detent·gesture·성능 계약 | 탐색 감각·PillNav |
| C.S2 | 선택 스타일 계약 구현 | Local Light 품질 확정 |

Cursor에게 “UI 개선”만 주지 말고, 아래 **결정 질문**을 요구한다.

1. 진입 3초: 기준 지역 / 콘텐츠 유무 / 현재 위치 전환 가능 여부  
2. 요소 우선순위 나열 (마커·클러스터·선택·control·sheet·베이스맵)  
3. OSM vs Light 2후보 동일조건 비교표  
4. 글·세미만 · 고객/Visit/내부 B/A/매출/인기 **금지** 안에서 마커 설계  
5. Peek/Half/Expanded 각 상태 show/hide 표 · CTA **상태당 1개**  
6. 웜 뉴트럴 + 저채도 베이스 + 의미색 2 · 핑크/보라 그라데이션·ColorFilter·종이질감·무지개 마커·카드인카드 **금지**  
7. 모든 UI에 목적 / 우선순위 / 탭 결과 / 빈 상태 명시

---

## 15. 변경 로그

| 날짜 | 내용 |
|------|------|
| 2026-09-11 | Perplexity/기획 조사 흡수 · C.1–C.4 분할 · **구현 금지** |
| 2026-09-11 | Sheet 성능·제스처·InteractiveFlag 계약 §10–11 · C.4 승인 문구 |
| 2026-09-11 | Quiet Local Light §13 · Phase **C.S1/C.S2** · overlay/ColorFilter 금지 |
| 2026-09-11 | **C.1** GPS FAB + `geolocator` one-shot · 거부 시 base center 유지 |
| 2026-09-11 | §9 시각 위계 · §13.1–13.3 C.S1 검수/금지 · §14 분업·프롬프트 · Peek 저장=부채 명시 |
| 2026-09-11 | C.S1 전용 `PRD_v7.9_REGION_MAP_CS1_BASEMAP.md` · 후보 A/B/C 순위 · 운영 URL 사전교체 금지 |