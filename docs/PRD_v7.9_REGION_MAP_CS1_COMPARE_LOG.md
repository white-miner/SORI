# SORI C.S1 — 베이스맵 비교 기록 (PO 렌더링 검수)

**Status:** Adopted A · **Stadia Alidade Smooth** · domain auth 필수 · Pages 게이트 확인 중  
**기준:** `PRD_v7.9_REGION_MAP_CS1_BASEMAP.md` · 상위 `PRD_v7.9_REGION_MAP_UPGRADE.md`  
**하네스:** 비교 칩 유지 · **운영 기본 = A** · 0=롤백  
**번들 금지:** Stadia `api_key` / `--dart-define` Web 키 삽입

> Cursor 주의: **타일이 뜬다 = 기술 통과 후보일 뿐.**  
> 진짜 합격 = **SORI 콘텐츠 marker·cluster·sheet가 지도에서 가장 먼저 읽히는가.**  
> Cursor 다음 일: 하네스 렌더 · 동일 fixture 스크린샷 · DevTools Y/N · PO 점수표 제공 · **1후보 채택/보류 대기.** 운영 URL 임의 교체 금지.

---

## 1. 키 · 도메인 제한

| 후보 | 준비 | 웹 운영 권고 | 검수 전 확인 |
|------|------|--------------|--------------|
| 0 OSM | 키 없음 | 기준선만 | attribution · public tile 정책 |
| A Alidade Smooth | `STADIA_MAPS_API_KEY` | **API key보다 Domain authentication 우선** | `white-miner.github.io` origin/referrer 승인 |
| B Base Light | `MAPTILER_API_KEY` | Allowed HTTP Origins에 Pages 등록 | `https://white-miner.github.io` · Origin/Referer |
| C Dataviz Light | 동일 MapTiler 키 | B와 동일 | B/C 동일 키 quota·약관 |
| T Carto Light | 임시 | free라도 key·attribution | watermark 가능 → **정식 후보 아님** · key restriction **N/A** |

### GitHub Pages origin

```
운영:  https://white-miner.github.io
경로:  https://white-miner.github.io/SORI/
allowlist: https://white-miner.github.io   ← 보통 path가 아니라 origin
```

| 상황 | 주의 |
|------|------|
| Pages 기본 도메인 | `white-miner.github.io` 등록 |
| custom domain | allowlist 추가 |
| 로컬 | `localhost`는 **개발용 키만** |
| Preview Pages | preview origin 별도 등록 |
| Referrer-Policy | `no-referrer`면 Stadia domain auth 실패 가능 |
| `--dart-define` | Web 빌드 후 **번들에 키 포함** |
| 안전 기준 | 키 숨김이 아니라 **도메인으로 사용 제한** |

DevTools Network에서 tile 요청의 `Origin` / `Referer`를 반드시 확인한다.

---

## 2. 후보표

| 후보 | 타일 | Web 인증 | 상용/운영 | 비교 목적 |
|------|------|----------|-----------|-----------|
| 0 OSM | Raster XYZ | 없음 | **기준선 전용** | 종이 지도 문제 확인 |
| A Alidade Smooth | Raster XYZ | Stadia domain auth 권장 | **Yes** | marker/overlay 캔버스 |
| B Base Light | Raster/style | MapTiler origin-restricted key | **Yes** | 균형 도시 지도 |
| C Dataviz Light | Raster/style | MapTiler origin-restricted key | **Yes** | marker/cluster 대비 |
| T Carto Light | Raster XYZ | CARTO key 가능 | **No · 임시** | 중립 light 감각만 |

키 없이 즉시 비교: **0 · T**. A/B/C는 키+도메인 설정 후.

**T CARTO:** 감각 비교용. `Key restriction`·상용 약관은 **N/A**로 기록하고, **운영 채택 후보의 기술 통과 조건에 포함하지 않는다.** “키 없이 무조건 쓸 수 있는 후보”로 해석하지 않는다.

### 렌더 전 기대 순위 (확정 아님)

| 순위 | 후보 | 기대 | 탈락 가능성 |
|-----:|------|------|-------------|
| 1 | A Alidade Smooth | muted·POI 절제·marker 중심 | domain auth · 한글 지명 품질 |
| 2 | B Base Light | 도시 인지 · C.S2 연결 | POI/라벨이 A보다 많을 수 있음 |
| 3 | C Dataviz Light | marker 대비 최상 | BI/분석 지도 느낌 |
| 비교 | T CARTO | light 최소 감각 | 운영 후보 아님 |
| 기준선 | 0 OSM | 개선 전후 체감 | Quiet Local 채택 아님 |

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

## 4. 점수 정의 (1–5)

| 항목 | 1 | 3 | 5 | **불합격** |
|------|---|---|---|------------|
| Marker 우선성 | 도로/POI에 묻힘 | 찾는데 시간 | **1초** 내 식별 | ≤3 |
| Cluster 가독 | 숫자/형태 불명 | 수량만 | 수량·타입·선택 즉시 | ≤3 |
| 선택 상태 | 기본과 혼동 | ring 약함 | 선명·과장 없음 | ≤3 |
| Sheet 조화 | 이질 | 톤 불일치 | 한 SORI 화면 | ≤3 |
| GPS/저장함 | 묻힘 | 보임 | 튀지 않으며 즉시 | ≤3 |
| 정보 밀도 | POI 과다 | 일부 혼잡 | 주요 도로·물·공원·지명만 | ≤3 |

### 점수 기입

| 항목 | 0 OSM | A Smooth | B Base | C Dataviz | T Carto |
|------|------:|---------:|-------:|----------:|--------:|
| Marker 우선성 | | | | | |
| Cluster 가독 | | | | | |
| 선택 상태 | | | | | |
| Sheet 조화 | | | | | |
| GPS/저장함 | | | | | |
| 정보 밀도 | | | | | |
| **평균** | | | | | |

### 채택 조건 (잠금)

```
채택:
- 평균 ≥ 4.0
- AND Marker 우선성 · Cluster 가독 · Sheet 조화 · 정보 밀도 각각 ≥ 4
- AND 기술 Y/N 필수 전부 Yes (운영 후보 A/B/C 기준 · T의 Key restriction은 N/A)
- AND 탈락 체크 0개

동점: marker/cluster 대비 → POI 최소화 → Web 안정 → 비용·약관 → C.S2 확장성
```

| 핵심 4항목 | 이유 |
|------------|------|
| Marker 우선성 | 콘텐츠 탐색 surface |
| Cluster 가독 | 저줌 탐색 핵심 |
| Sheet 조화 | UI 완성도 |
| 정보 밀도 | OSM/종이 지도 문제의 핵심 |

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

## 7. PO 검수 순서 (장면별 교차 비교)

후보를 하나씩 끝까지 보기보다, **장면마다 0/A/B/C/T를 교차**한다.

| # | 비교 방식 | 이유 |
|---|-----------|------|
| 1 | 모두 무마커 | 베이스맵 종이감·POI 밀도 |
| 2 | 모두 Low + cluster | cluster 대비 공정 비교 |
| 3 | 모두 Medium + marker | 글/세미나 대비 |
| 4 | 모두 selected + Peek | 지도·sheet 조화 |
| 5 | 모두 Half + filter | 위계·카드화 |
| 6 | **A/B/C만** Web network·CORS·attribution·key restriction | 운영 후보 기술 검수 |
| 7 | 점수 + 탈락 체크 | 평균·핵심4·기술 |
| 8 | 채택 또는 보류 문구 | 운영 URL 변경 권한 확정 |

---

## 8. PO 결정

| 결정 | 복붙 문구 |
|------|-----------|
| **채택** | `후보 ○를 C.S1 운영 베이스맵으로 채택한다. marker 우선성, 정보 밀도, sheet 조화, Web 안정성 기준을 충족했다.` |
| **보류** | `후보 A/B/C 모두 핵심 시각 기준 또는 Web 운영 기준을 충족하지 못했다. C.S1은 운영 URL 교체 없이 보류하고, 대체 라이트 래스터 후보를 추가 조사한다.` |
| **기준선 유지** | `OSM Standard는 기능 기준선으로만 유지하며, Quiet Local Canvas 운영 후보로는 채택하지 않는다.` |

| 항목 | 기입 |
|------|------|
| 채택 후보 | **A — Stadia Alidade Smooth** |
| 채택·보류 문구 | `후보 A를 C.S1 운영 베이스맵으로 채택한다. Stadia Alidade Smooth는 marker 우선성, 정보 밀도, sheet 조화, Web 안정성 기준을 충족하는 Quiet Local Canvas로 채택한다.` |
| 운영 URL 교체 승인일 | 2026-09-11 (디자인 채택) · **도메인 인증·Pages 타일 200 확인 후 확정** |
| 서명 · 날짜 | PO · 2026-09-11 |

### 운영 교체 후 필수 게이트 (하나라도 실패 → OSM 롤백 · C.S1 보류)

| 확인 | 통과 | 결과 (기입) |
|------|------|-------------|
| Stadia Property에 `https://white-miner.github.io` 등록 | Yes | |
| Pages에서 tile HTTP 200 | Yes | |
| Console CORS 없음 | Yes | |
| Attribution 전 상태 표시 | Yes | |
| Flutter Web 번들에 `api_key` 없음 | Yes (코드 계약) | |
| Sheet drag 중 새 tile/content API 0 | Yes | |
| 약관/비용 적합 | Yes | |

**운영 URL (키리스 · domain auth):**
`https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png`

B/C 보류 · T 비교 · 0 롤백 기준선 유지.

---

## 9. 변경 로그

| 날짜 | 내용 |
|------|------|
| 2026-09-11 | 초안 로그 |
| 2026-09-11 | 키/도메인 · 채택(핵심4≥4) · fixture 병행 · 기술표 · 탈락 · PO 순서 |
| 2026-09-11 | 최종 보강 4: tile 정상/비정상 · fixture 데이터 보호 · T Key restriction N/A · a11y/viewport · 장면 교차 검수 · Status Ready |
| 2026-09-11 | **PO 채택 A Alidade Smooth** · 키리스 URL · domain auth 게이트 · B/C 보류 |
