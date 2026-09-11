# SORI C.S1 — 베이스맵 비교 기록 (PO 렌더링 검수)

**Status:** A 채택 **철회** · 콘셉트 **SORI Local Bloom** · 운영 기본 = **0 OSM** · 우선 후보 **D Streets Pastel**  
**기준:** `PRD_v7.9_REGION_MAP_CS1_BASEMAP.md` · 상위 `PRD_v7.9_REGION_MAP_UPGRADE.md`  
**하네스:** 칩 순서 `0 · D · B · A · C · T` · Pastel/B/C는 `MAPTILER_API_KEY` + Origins  
**번들 금지:** MapTiler/Stadia 키를 채택 전 운영 URL에 하드코딩하지 않음 · Web은 도메인 제한 키만

> Cursor 주의: **타일이 뜬다 ≠ 통과.**  
> Quiet Local만으로 부족하다면 Local Bloom: **예쁜 도시 결 + marker 2색이 먼저 읽힘.**  
> A(Alidade)는 저채도 SaaS감으로 **보류**. D Pastel → 이후 C.S2 **SORI Local Bloom 커스텀**.

### 결정 이력

```
기존: A Stadia Alidade Smooth 채택
수정: A 채택 보류 (무채색 앱 + 무채색 지도 → 지역 생동감 부족)
운영: OSM 기준선으로 되돌림 (재채택 전)
새 1순위: D MapTiler Streets Pastel
최종 목표: E SORI Local Bloom 커스텀 (C.S2)
```

---

## 1. 키 · 도메인 제한

| 후보 | 준비 | 웹 운영 권고 | 검수 전 확인 |
|------|------|--------------|--------------|
| 0 OSM | 키 없음 | **현재 운영 기본** | attribution · public tile |
| D Streets Pastel | `MAPTILER_API_KEY` | Allowed HTTP Origins: `https://white-miner.github.io` | **우선 활성화·검수** |
| B Base Light | 동일 MapTiler 키 | 동일 Origins | 비교 유지 |
| A Alidade Smooth | domain auth (키리스 URL) | Property 도메인 | **보류** · 기술만 가능 |
| C Dataviz Light | MapTiler 키 | 동일 | 보조 비교 · 우선↓ |
| T Carto Light | 임시 | — | 비채택 · Key restriction N/A |

### GitHub Pages origin

```
운영:  https://white-miner.github.io
경로:  https://white-miner.github.io/SORI/
allowlist: https://white-miner.github.io
```

MapTiler: Allowed HTTP Origins에 위 origin 등록. 키는 비교 빌드에만(도메인 제한). **채택 확정 전 운영 번들 키 삽입 최소화.**

---

## 2. 후보표 · Local Bloom

| 후보 | 느낌 | 상용/운영 | 수정 판단 |
|------|------|-----------|-----------|
| 0 OSM | 종이 지도 | 기준선·임시 운영 | 기준선 |
| A Alidade Smooth | 조용한 SaaS/데이터 | 보류 | **채택 철회** · 생동감↓ |
| B Base Light | 밝은 도시 | 비교 | 유지 |
| C Dataviz Light | 분석·BI | 보조 | 우선↓ |
| **D Streets Pastel** | 예쁜 도시·파스텔 생활권 | **Yes 목표** | **새 1순위** |
| T Carto | 중립 light | No | 비교만 |
| E Local Bloom 커스텀 | SORI 전용 컬러 | C.S2 | **최종 목표** |

### SORI Local Bloom (콘셉트)

> 예쁜 도시의 결을 보여주되, 글·세미나·클러스터가 여전히 가장 먼저 읽히는 컬러풀한 커뮤니티 지도.

| 감정 | 지도 언어 |
|------|-----------|
| 화려한 | 물·공원·도로·토지사용 구분 색 |
| 예쁜 | jewel/pastel · 날카로운 원색 금지 |
| 매력 | 공원·물·블록이 살아 있음 |
| 세련 | 색은 많아도 역할 분명 · marker와 비경쟁 |
| 여성적 | 핑크 필터≠ · 코랄·라일락·세이지·아쿠아 균형 |
| SORI | 글·세미나 신뢰 포인트가 최전면 |

팔레트(커스텀 E용 초안): 배경 `#FCF9F5` · 건물 `#E9E4EC` · 주요도로 `#E9B29E` · 공원 `#CBE1CC` · 물 `#BFE1EC` · 라벨 `#5E5862` · 글 marker `#6D4A77` · 세미나 `#D96462` · 선택 크림 ring · cluster 단색. **마커 의미색 ≤2.**

---

## 2b. 점수 · Local Bloom 추가 기준

| 항목 | 유지/추가 | 불합격 |
|------|-----------|--------|
| Marker 우선성 | 유지 | ≤3 |
| Cluster 가독 | 유지 | ≤3 |
| Sheet 조화 | 웜 sheet ↔ 컬러 지도 | ≤3 |
| 정보 밀도 | 길·공원·물은 생생 · POI 과밀 금지 | ≤3 |
| **도시 생동감** | **추가** · 3초 내 동네가 살아 있음 | ≤3 |
| **색감 피로도** | **추가** · 컬러가 marker·sheet 압도 안 함 | ≤3 |

### 점수 기입

| 항목 | 0 | D Pastel | B Base | A Smooth | C Dataviz | T |
|------|--:|--------:|-------:|---------:|----------:|--:|
| Marker 우선성 | | | | | | |
| Cluster 가독 | | | | | | |
| Sheet 조화 | | | | | | |
| 정보 밀도 | | | | | | |
| 도시 생동감 | | | | | | |
| 색감 피로도 | | | | | | |
| **평균** | | | | | | |

### 채택 조건 (수정 잠금)

```
평균 ≥ 4.0
AND Marker·Cluster·Sheet·정보밀도 각각 ≥ 4
AND 도시 생동감·색감 피로도 각각 ≥ 4
AND 기술 Y/N (운영 후보) 전부 Yes
AND 탈락 0개
```

---

## 3. Fixture

실데이터만 쓰면 후보별 밀도 차이로 미감이 왜곡된다 → **실데이터 + 고정 fixture 병행**.

| 항목 | 권장 |
|------|------|
| 위치 | PO 지정 **동일 lat/lng 1개** |
| 줌 Low | 12–13 · cluster 보이는 단계 |
| 줌 Medium | 15–16 · 글/세미나 분리 |
| 글 / 세미나 / cluster | 4 / 2 / 1 (수량 예: 12 또는 동일 영역) |
| selected | 글 1 |
| controls | GPS + 저장함 |
| Peek / Half | Peek preview · Half=목록3+필터3 (Half 미구현 시 Peek 카드로 대체 기록) |
| 기기 | 동일 viewport/DPR · 라이트 테마 · bearing/pitch 0 |

**데이터 보호 (잠금)**

```
고정 fixture의 marker 좌표는 공개 가능한 커뮤니티 객체 또는
테스트 전용 익명 좌표만 사용한다.
고객, Visit, 내부 사진, 미동의 B/A, 정확한 비공개 상담 위치는
fixture·스크린샷·GitHub Pages 검수에 사용하지 않는다.
```

| 장면 지역 | 특성 | 이유 |
|-----------|------|------|
| 도심 혼합 | 도로·건물·POI 많음 | 베이스맵 소음 |
| 주거/동네 | 공원·생활권 | “우리 동네” 감각 |
| 콘텐츠 희소 | marker 적음 | 저밀도 품질 |

**이번 검수 fixture 기입**

| 항목 | 값 |
|------|-----|
| lat/lng | |
| Low zoom | |
| Medium zoom | |
| 실데이터 영역 메모 | |

---

## 4. 점수 정의 (상세 1–5 · 기존 항목)

| 항목 | 1 | 3 | 5 | **불합격** |
|------|---|---|---|------------|
| Marker 우선성 | 도로/POI에 묻힘 | 찾는데 시간 | **1초** 내 식별 | ≤3 |
| Cluster 가독 | 숫자/형태 불명 | 수량만 | 수량·타입·선택 즉시 | ≤3 |
| 선택 상태 | 기본과 혼동 | ring 약함 | 선명·과장 없음 | ≤3 |
| Sheet 조화 | 이질 | 톤 불일치 | 한 SORI 화면 | ≤3 |
| GPS/저장함 | 묻힘 | 보임 | 튀지 않으며 즉시 | ≤3 |
| 정보 밀도 | POI 과다 | 일부 혼잡 | 주요 도로·물·공원·지명만 | ≤3 |
| 도시 생동감 | 차갑·지루 | 무난 | 3초 내 동네가 살아 있음 | ≤3 |
| 색감 피로도 | marker/sheet 압도 | 다소 산만 | 컬러 살아 있으나 경쟁 없음 | ≤3 |

점수 기입 표는 **§2b** 사용. 채택 조건은 §2b 잠금본.

---

## 5. 기술 Y/N · 네트워크 정상/비정상

| 후보 | HTTPS | Tile 200 | CORS | Origin/Referer | Attribution | Key restriction | Sheet drag net 0 | 약관/비용 | 판정 |
|------|:----:|:--------:|:----:|:--------------:|:-----------:|:---------------:|:----------------:|:---------:|------|
| 0 OSM | | | | N/A | | N/A | | | 기준선 |
| A | | | | | | **필수** | | | |
| B | | | | | | **필수** | | | |
| C | | | | | | **필수** | | | |
| T | | | | | | **N/A** | | | 임시 |

| 항목 | Yes 기준 |
|------|----------|
| HTTPS | mixed content 없음 |
| Tile 200 | 진입·pan/zoom 이미지 성공 |
| CORS | Console tile CORS 차단 없음 |
| Origin/Referer | allowlist와 실제 헤더 일치 |
| Attribution | 공급자+OSM **모든** 지도 상태 |
| Key restriction | A/B/C: 등록 도메인 외 **거절**. 0·T: N/A |
| Sheet drag net 0 | Peek/Half/Expanded **drag 중** 새 tile/content API **0** |
| 약관/비용 | 트래픽·상업 이용 적합 (T는 채택 조건에서 제외) |

### Tile 요청 정상 vs 비정상 (잠금)

| 상황 | 허용 |
|------|------|
| Sheet drag | 새 tile / content API **0** |
| Map pan/zoom | **새 viewport에 필요한 tile만** · 동일 viewport 반복 이동 시 과도한 중복 tile 없음 |
| Filter 전환 | 마커/콘텐츠 query **1회** · 베이스 타일 재요청 **없음** |
| GPS 중심 이동 | camera 완료 후 필요 tile만 · 반복 위치 요청에 중복 content query 없음 |
| Marker 선택 | 베이스 타일 재요청 **원인 금지** |

```
Map pan/zoom은 새 viewport에 필요한 tile 요청만 허용한다.
동일 viewport 재진입, sheet drag, filter 전환, marker 선택은
기존 베이스 타일을 다시 요청하는 원인이 되어서는 안 된다.
```

---

## 5b. 접근성 · 뷰포트 (화면 UI · 타일 라벨 외)

베이스맵 타일 라벨은 완전 통제 불가. **marker·cluster·sheet·controls**는 통과해야 한다.

| 검수 | 통과 |
|------|------|
| OS 글자 크기 확대 | cluster 수량 · Peek 제목 2줄 · GPS/저장함 semantics · sheet CTA 잘림 없음 |
| 좁은 viewport (360px) | 우측 control ↔ marker·sheet 겹침 없음 |
| 넓은 viewport (태블릿/Web) | marker·sheet 과도 확장 없음 |
| 색상 외 신호 | 글/세미나 = 색 외 형태·glyph·sheet 유형 라벨로 구분 |

후보별 메모: _______________

---

## 6. 탈락 조건 (해당 시 체크)

```
[ ] 기본 OSM/종이 지도 인상 강함
[ ] POI/라벨이 SORI marker보다 우세
[ ] 지도와 sheet가 다른 제품처럼 보임
[ ] 주요 도로·공원·물·지명 인지 불가
[ ] 의미색 3개 이상 또는 과한 파스텔/그라데이션 필요
[ ] tile/CORS/attribution/key restriction 문제 (A/B/C)
[ ] sheet drag 중 타일/콘텐츠 재요청 · pan 시 비정상 중복 tile
[ ] 공급자 약관·비용·상용 조건 불명확 (운영 후보)
```

후보별 탈락 메모: _______________

---

## 7. PO 검수 순서 (장면별 교차 · Local Bloom)

| # | 비교 방식 | 이유 |
|---|-----------|------|
| 1 | 0/D/B/A/C/T 무마커 | 생동감·POI·종이감 |
| 2 | 모두 Low + cluster | cluster 대비 |
| 3 | 모두 Medium + marker | 글/세미나 + 색감 피로 |
| 4 | 모두 selected + Peek | sheet 조화 |
| 5 | 모두 Half + filter | 위계 |
| 6 | **D/B** (필요 시 A) Web·CORS·Origins·attribution | 운영 후보 기술 |
| 7 | 점수 + 탈락 (생동감·피로도 포함) | 채택 조건 |
| 8 | 채택 또는 보류 문구 | URL 변경 권한 |

---

## 8. PO 결정

| 결정 | 복붙 문구 |
|------|-----------|
| **채택 (예: D)** | `후보 D를 C.S1 운영 베이스맵으로 채택한다. Streets Pastel은 Local Bloom 방향의 도시 생동감·색감 피로도·marker 우선성 기준을 충족한다.` |
| **A 철회 확정** | `후보 A Alidade Smooth 채택을 철회한다. 무채색 앱+지도는 지역 커뮤니티 surface의 생동감이 부족하다.` |
| **보류** | `D/B 모두 Local Bloom 또는 Web 기준 미달. 운영은 OSM 유지, C.S2 커스텀 조사.` |
| **기준선** | `OSM은 재채택 전 임시 운영·기능 기준선으로만 유지한다.` |

| 항목 | 기입 |
|------|------|
| 현재 결정 | **A 채택 철회** · 운영 **0 OSM** · 다음 검수 **D Pastel** |
| 채택·보류 문구 | `후보 A 채택을 철회한다. SORI Local Bloom 방향으로 D Streets Pastel을 1순위 재비교한다.` |
| 운영 URL | OSM `tile.openstreetmap.org` (재채택 전) |
| 서명 · 날짜 | PO · 2026-09-11 |

MapTiler 비교 시: Allowed HTTP Origins = `https://white-miner.github.io` · 키는 비교용(도메인 제한). D 채택 확정 후에만 운영 기본 URL 교체.

---

## 9. 변경 로그

| 날짜 | 내용 |
|------|------|
| 2026-09-11 | 초안 → Ready → **A 채택** |
| 2026-09-11 | **A 채택 철회** · Local Bloom · D Pastel 1순위 · 운영 OSM · 생동감/피로도 채택 조건 |
