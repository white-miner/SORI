# SORI — C.S1 Quiet Local Canvas 후보 비교 · 렌더링 검수

**Status:** In progress · 비교 하네스 코드 준비 · PO 점수·키 대기 · 운영 기본 OSM  
**상위 문서:** `docs/PRD_v7.9_REGION_MAP_UPGRADE.md` (§9 · §13 · C.S1)  
**비교 로그:** `docs/PRD_v7.9_REGION_MAP_CS1_COMPARE_LOG.md`  
**작성:** 2026-09-11 · Perplexity 조사 흡수

---

## 0. 목표

C.S1은 타일 URL 교체가 아니라 **SORI 글·세미나 marker / cluster / Peek sheet가 가장 먼저 읽히는 Quiet Local Canvas 1개 선정**이다.

```
기존 OSM → 도로·POI·라벨이 지배 → SORI UI 묻힘
Quiet Local Canvas → 조용한 배경 → 콘텐츠 마커 먼저 → sheet와 한 제품
```

| 검수 질문 | 통과 |
|-----------|------|
| 3초: 지역·콘텐츠 존재 | 중심·클러스터·마커 즉시 |
| 1초: SORI 마커 발견 | POI/도로보다 marker 대비 높음 |
| 지도↔sheet 동일 제품감 | 웜 뉴트럴 sheet와 저채도 지도 충돌 없음 |
| 길·동네 인지 | 주요 도로·공원·물·지명 유지 |
| OSM·종이 지도 느낌 | 있으면 **탈락** |
| 과도 감성·일러스트 | 있으면 **탈락** |
| Web 안정 | HTTPS·CORS·Referer·attribution·키 정책 |

**분업:** Cursor = 동일 fixture 렌더·비교표·기술 결과 · PO = 스크린샷 미감 선택 · **PO 선택 전 운영 tile URL 교체 금지.**

**부채:** 현재 코드에 Carto `light_all`이 들어가 있음 → C.S1 완료 전 **임시**. 본 문서 후보와 다르면 C.S1에서 재선정·교체.

---

## 1. 동일 조건 Fixture (필수)

```
고정 지역: 상권·주거 혼합 1 · 마커 밀도 높음 1 · 콘텐츠 적음 1
고정 카메라: lat/lng·zoom 동일 · bearing=0 · pitch=0
고정 UI: 글4 · 세미나2 · cluster1 · selected1 · Peek1 · GPS/저장함2 · 동일 기기 프레임
```

| 장면 | 목적 |
|------|------|
| A. 마커 없음 | 베이스맵 소음 |
| B. 저줌 + cluster | cluster 대비 |
| C. 중줌 + 마커 6 | 유형·밀도 |
| D. 선택 + Peek | 위계 |
| E. Half + 필터3 | sheet 밀도 |
| F. 주소 없음 빈 상태 | CTA 자연스러움 |
| G. Flutter Web 실배포 | CORS·Referer·attribution |

---

## 2. 후보

| ID | 후보 | 방식 | 초기 판단 |
|----|------|------|-----------|
| **0** | OSM Standard | 현행/기준선 | 기준선만 · 채택 비권고 |
| **A** | Stadia Alidade Smooth | 라이트 래스터 XYZ | **1순위** · 저채도·POI 적음·marker 중심 |
| **B** | MapTiler Base Light | 래스터/벡터 | **2순위** · C.S2 확장 용이 |
| **C** | MapTiler Dataviz Light | 라이트 스타일 | **3순위** · 대비↑ · BI 느낌 주의 |
| D | MapTiler Streets Pastel | 파스텔 | 첫 후보 비권고 · 의미색 경쟁 |
| E | 임의 공개 래스터 | 제3자 | 프로토타입만 · 프로덕션 비권고 |

### 추천 비교 세트

```
0 OSM · A Alidade Smooth · B Base Light · C Dataviz Light
```

### URL 패턴 (비교용 · 키 하드코딩 금지)

| 후보 | 예시 패턴 | 키 |
|------|-----------|-----|
| A Stadia | `https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png` | 플랜·도메인·proxy/Edge 검토 |
| B/C MapTiler | 공급자 raster XYZ / style endpoint | Edge·domain restriction |
| 0 OSM | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | 공개 서버 정책·attribution 필수 |

키는 Flutter Web 번들 **금지**. Attribution(공급자+OSM) 항상 노출.

### 토큰 적합성 (초안)

| SORI 목표 | A Smooth | B Base Light | C Dataviz | D Pastel |
|-----------|:--------:|:------------:|:---------:|:--------:|
| 저채도 베이스 | 높음 | 높음 | 높음 | 중간 |
| POI 최소화 | 높음 | 중간 | 높음 | 낮~중 |
| marker 대비 | 높음 | 높음 | 매우 높음 | 중간 |
| sheet 조화 | 높음 | 중~높 | 중간 | 높음 |
| 길 가독성 | 높음 | 높음 | 중~높 | 매우 높음 |
| BI 느낌 회피 | 높음 | 높음 | 중간 | 높음 |
| C.S2 확장 | 중간 | 매우 높음 | 매우 높음 | 매우 높음 |

---

## 3. 렌더링 검수표

### 3.1 시각 위계 (1–5 · 합격 ≥4)

| 항목 | 1 | 3 | 5 |
|------|---|---|---|
| Marker 우선성 | 라벨에 묻힘 | 탐색 필요 | 첫 시선 |
| Cluster 가독 | 숫자 불가 | 경쟁 | 즉시 |
| 선택 상태 | 차이 없음 | ring | 명확·과장 없음 |
| Sheet 조화 | 이질 | 무난 | 한 surface |
| GPS/저장함 | 묻힘 | 보통 | 작지만 명확 |
| 정보 밀도 | POI 과다 | 일부 과다 | 길·공원·지명만 |

### 3.2 공간·탐색

| 항목 | 합격 |
|------|------|
| 3초 지역 인지 | 대략 동네/지명 |
| 1초 마커 ≥1 | 찾음 |
| 글/세미나 구분 | 색+아이콘/형태 |
| cluster 탭 | bounds 확대 자연 |
| pan/zoom | 깜빡임 과다 없음 |
| Peek | ring ↔ sheet 제목 일치 |
| Peek→Half | PillNav·control 위계 유지 |
| 필터 | 중심 유지 · marker만 갱신 |

### 3.3 미학 탈락 (1개라도 → 탈락/수정)

- OSM·종이·행정 지도 느낌 강함  
- 외부 POI > SORI marker  
- 베이스 라벨 > Peek 제목  
- ColorFilter/베이지/핑크 overlay로 탁함  
- 의미색 3개 이상 · 그라데이션/3D cluster · 광고형 마커  
- 무채색 과다로 도로·물·공원 구분 실패  
- 지도↔sheet 다른 브랜드감  
- 타일 로딩·저작권·CORS 불안정  

### 3.4 기술·운영 (전부 통과)

HTTPS · tile 200 · CORS · Referer · 키 비하드코딩 · Edge/domain · attribution · Peek↔Half 중 **타일 재요청 0** · 캐시 · 약관 · 타일 실패≠중심 null · GPS 이력 비저장.

---

## 4. 비교 절차

### Cursor 산출물

- 후보 0/A/B/C × 장면(최소: 무마커 · 저줌 cluster · 중줌 6 · Peek · Half+필터)  
- 동일 viewport/DPR/지역/줌  
- tile URL · attribution · key 여부 · CORS · 타일 수 · sheet drag network 0건  
- 장단점·탈락/보류 표  
- **운영 main tile 교체 없음** (preview branch만)

### PO 순서

1 무마커 3초 → 2 cluster → 3 marker 6 → 4 Peek → 5 Half+필터 → 6 느린망/실패 → 7 점수표 → 8 **1후보 잠금**

### 채택 규칙

```
시각 평균 ≥ 4.0
AND 기술 필수 전부 통과
AND 탈락 조건 0
→ C.S1 채택

동점: marker/cluster 대비 → POI 최소화 → Web 안정 → 비용·약관 단순 → C.S2 확장성
```

---

## 5. Cursor 브리프 (복붙)

```md
# SORI C.S1 Quiet Local Canvas 후보 비교

목적: OSM을 꾸미지 말고, 글·세미나 marker + Peek가 먼저 읽히는
저채도 라이트 베이스맵 1개 선정.

후보: 0 OSM | A Stadia Alidade Smooth | B MapTiler Base Light | C MapTiler Dataviz Light

Fixture: 동일 lat/lng/zoom/bearing/pitch · 글4 · 세미나2 · cluster1 · selected1 · Peek · GPS/저장함

각 후보 렌더: 무마커 / 저줌+cluster / 중줌+6 / selected+Peek / Half+[전체][글][세미나]

금지: 파스텔5색 · OSM 종이감 · ColorFilter · 베이지 overlay · 위성 기본 · 과한 POI · 그라데이션 cluster
제출: URL·attribution·key·CORS·성능 표 + 비교표. PO 선택 전 운영 tile 교체 금지.
```

---

## 6. 최종 권고 (잠금 · 채택은 검수 후)

| 순위 | 후보 |
|-----:|------|
| 1 | **Stadia Alidade Smooth** |
| 2 | MapTiler Base Light |
| 3 | MapTiler Dataviz Light |
| 기준선 | OSM Standard (채택 비목표) |

최종은 예시 이미지가 아니라 **SORI fixture 실렌더**로만 결정한다.  
채택 기준 = 단독으로 예쁜가 ❌ · **SORI 마커·클러스터·sheet가 가장 잘 읽히는가** ✅.

---

## 7. 변경 로그

| 날짜 | 내용 |
|------|------|
| 2026-09-11 | C.S1 후보·검수표·절차·브리프 잠금 · 운영 URL 사전 교체 금지 · Carto=임시 부채 |
