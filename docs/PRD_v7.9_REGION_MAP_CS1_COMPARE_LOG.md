# SORI C.S1 — 베이스맵 비교 기록 (PO 검수 로그)

**Status:** In progress · Cursor 하네스 배포 후 PO 점수 기입  
**기준 문서:** `PRD_v7.9_REGION_MAP_CS1_BASEMAP.md`  
**하네스:** 우리지역 맵 하단 `베이스맵 비교 (C.S1)` 칩 · 운영 기본 = **0 OSM**

---

## 키 준비 (로컬/CI · 값 커밋 금지)

| 변수 | 후보 |
|------|------|
| `STADIA_MAPS_API_KEY` | A Alidade Smooth |
| `MAPTILER_API_KEY` | B Base Light · C Dataviz Light |

`.env` 또는 `--dart-define`. GitHub Pages에 넣으면 클라 번들에 포함되므로 **도메인 제한** 필수. 장기적으로는 Edge proxy(C.S2).

키 없이 비교 가능한 것: **0 OSM**, **T Carto Light(임시)**.

---

## Fixture (검수 시 고정)

- 지역: _______________ (lat/lng)
- zoom: _______________
- 글 marker / 세미나 / cluster: 앱에 로드된 실데이터 사용

장면: 무마커 느낌은 줌아웃 · 중줌 마커 · Peek · Half는 시트 구현 전 Peek 카드로 대체 가능.

---

## 점수 (항목당 1–5 · 합격 ≥4)

| 항목 | 0 OSM | A Smooth | B Base | C Dataviz | T Carto |
|------|------:|---------:|-------:|----------:|--------:|
| Marker 우선성 | | | | | |
| Cluster 가독 | | | | | |
| 선택 상태 | | | | | |
| Sheet 조화 | | | | | |
| GPS/저장함 | | | | | |
| 정보 밀도 | | | | | |
| **평균** | | | | | |

기술 (Y/N): HTTPS · tile 200 · CORS · attribution · drag 중 재요청 0

| 후보 | CORS | attribution | 키 | 비고 |
|------|------|-------------|-----|------|
| 0 | | © OSM | 없음 | |
| A | | | STADIA | |
| B | | | MAPTILER | |
| C | | | MAPTILER | |
| T | | © CARTO | 없음 | 공식 후보 아님 |

탈락 조건 해당 여부: _______________

---

## PO 결정

| 항목 | 기입 |
|------|------|
| 채택 후보 | 0 / A / B / C / (보류) |
| 이유 | |
| 운영 URL 교체 승인일 | |
| 서명 | |

동점 시: marker 대비 → POI 최소화 → Web 안정 → 비용·약관 → C.S2 확장성.
