# SORI 우리 지역 필드 100% 구현계획 및 자료

> **저장 위치:** `docs/SORI_OUR_AREA_FIELD_100_IMPLEMENTATION.md`  
> **기준:** 현재 `origin/main`의 최신 상태에서 시작  
> **오늘 야간 목표:** ‘우리 지역’이 지도 장식이나 빈 목록이 아니라, 실제 샵에서 주변 뷰티 업소를 찾고 이해하고 지도에서 확인하며, 상권 판단의 출발점을 만드는 완성된 필드 기능이 되게 한다.

---

# 1. 제품 정의

## 한 문장

> **우리 지역은 원장과 고객이 선택한 반경 안의 실제 뷰티 업소를 발견하고, 기본 정보를 이해하고, 필요하면 Naver Map으로 확인·길찾기까지 이어지는 SORI의 지역 연결 필드다.**

SORI는 Naver Map, 예약 플랫폼, 지도 SDK를 대체하지 않는다. SORI는 사용자가 필요한 뷰티 업소와 지역 판단을 발견하게 하고, 상세 장소 정보·길찾기·등록 정보는 이미 강력한 외부 지도 플랫폼으로 연결한다.

## 완성 정의

“우리 지역 100%”는 모든 공공데이터·AI·예약을 한밤에 구현한다는 뜻이 아니다. 오늘 야간의 100%는 아래 **필드 핵심 루프가 빈 결과 없이 실제로 완주되는 상태**다.

```text
우리 지역 진입
→ 탐색 중심이 결정됨
→ 반경/카테고리를 이해함
→ 반경 안 실제 뷰티 업소가 목록과 지도에 표시됨
→ 업소의 이름·업종·거리/주소를 이해함
→ 지도에서 보기로 Naver Map 확인/길찾기
→ 결과 없음이면 반경 확장 또는 중심 변경으로 회복
→ 위치/데이터 오류이면 무엇이 실패했는지 알고 재시도 가능
```

---

# 2. 지금까지 배포된 기반

| 기능 | 현재 상태 | 유지 여부 |
|---|---|---:|
| 업체 카드 지도 CTA | 지도/Place URL → 좌표 → 주소 검색 → 업체명+지역 검색 fallback | 유지 |
| 반경·카테고리·결과 수 요약 | Deploy 26 완료 보고 | 유지 |
| 0건 반경 넓히기 | Deploy 26 완료 보고 | 유지 |
| 업체 카드 요약 | 이름·업종·거리/주소 + 지도에서 보기 | 유지 |
| FlutterMap 제스처 | 무변경 | 유지 |
| RegionMapExploreSheet | 무변경 | 유지 |

## 현재 P0

> **맵에서 반경 안에 아무것도 잡히지 않는다.**

이 문제가 해결되기 전에는 카드 UI, 상권 분석, 콘텐츠, 정렬, visual polish로 이동하지 않는다.

---

# 3. 오늘 야간 P0: 반경 결과를 실제로 복구

## 3.1 원인 후보

아래 중 하나 또는 복합 문제일 가능성이 높다.

| 후보 | 증상 | 확인 방법 |
|---|---|---|
| 탐색 중심 오류 | 지도는 보이나 실제 사용자/선택 위치와 다른 지역을 검색 | filter center와 map center lat/lng 출력 |
| 위치 권한/획득 실패 | 위치를 못 가져왔는데 fallback이 빈 값 또는 잘못된 값 | permission/status/error path 확인 |
| 반경 단위 오류 | 3km 선택이 3m, 3000km 등으로 계산 | UI km 값과 filter meter 값 확인 |
| lat/lng 필드 오류 | 모든 업소가 비정상 위치이거나 distance가 NaN | 원본 좌표 parse와 위도·경도 순서 확인 |
| 좌표계 오류 | EPSG:5174 같은 TM 좌표를 WGS84 lat/lng처럼 사용 | source coordinate system 확인 |
| 데이터 로딩 오류 | 원본 업체 배열이 비어 있음 | source count 확인 |
| 서로 다른 중심 사용 | circle, map, list가 서로 다른 위치를 기준으로 움직임 | 각 소비처의 center source 확인 |
| 너무 좁은 기본 반경 | 데이터는 있으나 범위 밖 | 1/3/5/10km 통과 수 확인 |

## 3.2 15분 진단 계약

에이전트는 15분 안에 다음 수치를 test 또는 dev-only diagnostics로 산출한다. 추측하지 않는다.

```text
A. 현재 search center: lat, lng, source
B. 현재 map camera center: lat, lng
C. 선택 radius: UI 값(km), filter 값(m)
D. 원본 업체 total count
E. 유효 WGS84 coordinate count
F. invalid/missing coordinate count
G. 각 radius(1/3/5/10km) 통과 count
H. 현재 list의 filter 통과 count
I. geolocation permission/status/error
J. list center와 circle/map center가 같은 source인지
```

### 진단 결과 분기

| 진단 결과 | 즉시 처리 |
|---|---|
| 원본 업체 0개 | 데이터 source/load path 복구가 Deploy 32 |
| 유효 좌표 0개 | 좌표 파싱/좌표계 변환 또는 주소 기반 fallback이 Deploy 32 |
| map/list center 불일치 | 단일 `AreaSearchCenter`로 통합 |
| 3km는 0, 10km는 있음 | 기본 반경/확장 동작만 조정, 데이터 구조 변경 금지 |
| 모든 반경 0 | center 또는 coordinate/filter calculation 복구 |
| geolocation 실패인데 fallback 없음 | map center → existing default region fallback 추가 |
| 결과는 있지만 UI 0 | state/filter/render 연결 복구 |

---

# 4. 데이터 기준과 수집 자료

## 4.1 1차 데이터: 업소 발견용

오늘 밤 1차 목적은 **실제 업소명·업종·주소·좌표가 있는 데이터**를 확보해 반경 탐색을 작동시키는 것이다.

### 우선 데이터 소스

| 우선 | 소스 | 제공 가치 | 구현 판단 |
|---:|---|---|---|
| 1 | 현재 SORI 내 업체 데이터 | 이미 있는 모델·로컬 데이터·API | 우선 복구/재사용 |
| 2 | 행정안전부 생활 미용업 | 전국 지자체 인허가 기반, 업소명·영업상태·주소·인허가일 등 | 전국 기본 목록 후보 |
| 3 | 소상공인시장진흥공단 상가(상권)정보 | 상호명·업종분류·주소·경도·위도 제공 | 반경 검색에 가장 직접적 |
| 4 | 지역별 미용업 인허가 공개 데이터 | 업종·상호·주소·전화 등 | 지역 확장/보강 |

### 사용 가능한 필드

```text
업체 식별:
- stable source id 또는 source + source record id
- 상호명
- 업종 대/중/소분류 또는 미용업 업태

위치:
- WGS84 latitude
- WGS84 longitude
- 도로명/지번 주소
- 시도/시군구/읍면동

상태:
- 영업 상태
- 인허가일/폐업일(있을 때만)

표시:
- 업종 라벨
- 거리(좌표가 신뢰 가능한 경우만)
- 주소(거리 없을 때 또는 보조 정보)
```

### 공식 자료 메모

- 행정안전부 생활 미용업 데이터는 지자체 관리 인허가 정보를 전국 단위로 취합하며, 헤어·메이크업·네일·피부 관련 업소의 인허가일, 영업상태, 사업장명, 소재지 주소 등의 정보를 제공한다.
- 일부 데이터는 WGS84 위경도가 아니라 Bessel 중부원점 TM(EPSG:5174) 좌표를 제공한다. 이 값을 위도/경도로 직접 사용하면 반경 검색이 전부 실패할 수 있다.
- 소상공인시장진흥공단 상가(상권)정보는 상호명, 업종 분류, 주소, 위도, 경도 등을 제공하는 데이터 소스로 반경 기반 발견에 적합하다.

## 4.2 2차 데이터: 상권 판단용

이것은 오늘 밤 P0 해결 뒤에만 시작한다.

| 데이터 | 사용 목적 | 표시 원칙 |
|---|---|---|
| 국세청 생활업종 통계 | 지역/업종별 사업자 수·매출 수준·평균 존속 등 거시 판단 | 개별 업체 매출처럼 표시 금지 |
| 소상공인 상권정보 | 업종 분포와 경쟁 환경 | 출처·기준일 표시 |
| 지자체 인허가 상태 | 업소 상태와 지역 분포 | 최신성·좌표계 명시 |

### 매출 데이터의 엄격한 원칙

```text
국세청/공공 통계의 지역·업종 집계 매출은
개별 샵의 연매출이 아니다.

SORI는 이를 “해당 지역·업종의 통계 지표”로만 표시한다.
개별 업체 카드에 추정 매출 또는 개인별 매출로 붙이지 않는다.
```

---

# 5. 오늘 밤 구현 순서

## Deploy 32 — 반경 검색 P0 복구

### 사용자 결과

> 사용자는 우리 지역에서 선택한 반경 안에 있는 실제 뷰티 업소를 본다.

### 구현 계약

1. **단일 source of truth:** `AreaSearchCenter`
   - geolocation 성공: 현재 위치
   - 실패/거부: 현재 지도 중심
   - 지도 중심 불가: 기존 기본 지역 중심
2. 아래 네 곳은 같은 center를 사용한다.
   - FlutterMap camera
   - radius circle
   - 업체 목록 filter
   - 상단 조건 요약
3. radius 단위를 명시적으로 통일한다.
   - UI: km
   - filter/distance: m
4. WGS84가 아닌 좌표는 WGS84로 변환하기 전까지 distance filter에 쓰지 않는다.
5. 유효 좌표가 없는 업체는 “반경 N km” 결과에 섞지 않는다.
   - 주소/지역 fallback 목록을 제공할 수는 있지만 거리 표시는 하지 않는다.
6. 결과 0을 두 종류로 분리한다.
   - 실제 조건 0건: 반경 넓히기
   - 위치/데이터 준비 실패: 현재 위치 다시 사용 또는 지도 중심으로 찾기

### 최소 fixture tests

```text
- center 근처 500m 업체 1개
- center에서 2km 업체 1개
- center에서 8km 업체 1개
- invalid coordinate 업체 1개

1km → 1개
3km → 2개
10km → 3개
invalid coordinate → 반경 결과/거리 표시 제외
location denied → map center/default center fallback의 기대 결과
```

### 완료 기준

```text
대표 center 근처의 유효 업체가
선택 반경 안에서 map marker와 list 양쪽에 표시된다.
```

---

## Deploy 33 — 실제 업소 데이터 인입 또는 정규화

### 실행 조건

Deploy 32 진단에서 다음 중 하나일 때만 진행한다.

```text
원본 업체가 0개
유효 WGS84 coordinate가 0개
현재 데이터가 demo-only이고 실샵 위치에서 결과를 만들 수 없음
```

### 사용자 결과

> 선택 지역에서 실제 영업 중인 뷰티 업소가 반경 탐색 결과로 나온다.

### 우선 구현 전략

1. **기존 데이터 source를 먼저 수리한다.**
2. 부족하면 소상공인 상권정보의 WGS84 lat/lng 기반 **작은 지역 snapshot**을 사용한다.
3. 시사회/실샵 대상 지역만 먼저 지원한다.
4. 전국 동기화, 실시간 crawler, 복잡한 ETL은 오늘 밤 하지 않는다.

### 안전한 데이터 패키징

```text
assets/data/our_area/<region>_beauty_shops.json
```

권장 최소 필드:

```json
{
  "source": "public-business-data",
  "sourceId": "...",
  "name": "...",
  "category": "hair|barber|nail|skin|tattoo|makeup|other",
  "address": "...",
  "latitude": 37.0,
  "longitude": 127.0,
  "status": "operating",
  "updatedAt": "YYYY-MM-DD"
}
```

### 금지

```text
개별 업소의 매출 추정
전화번호 수집·노출 확대
새 DB schema/migration
실시간 외부 API를 클라이언트에서 직접 호출
API key를 GitHub Pages에 노출
전국 단위 완벽 데이터 ETL
```

---

## Deploy 34 — 위치 권한·중심 변경 회복 UX

### 사용자 결과

> 현재 위치를 사용할 수 없어도 사용자는 0개 화면에 갇히지 않고, 현재 지도 중심 또는 기본 지역을 기준으로 업체를 계속 찾는다.

### 구현

- 상단에 탐색 기준 표시
  - “현재 위치 기준”
  - “지도 중심 기준”
  - “기본 지역 기준”
- geolocation 실패/거부 시 짧은 안내
  - “현재 위치를 사용할 수 없어 지도 중심으로 찾고 있어요.”
- CTA 최대 2개
  - “현재 위치 다시 사용”
  - “지도 중심으로 찾기”
- permission dialog를 반복적으로 강제하지 않는다.

---

## Deploy 35 — 업종 필터의 실제 데이터 매핑

### 사용자 결과

> 헤어/바버/네일/피부/타투 등 선택한 카테고리에 맞는 실제 업소가 결과에 나온다.

### 구현

- public source의 원본 업종 문자열을 SORI의 소수 표준 카테고리로 map한다.
- 매핑되지 않는 값은 `other`로 보존하고, 선택 필터에서 조용히 제외한다.
- 목록 상단의 카테고리 명칭과 filter의 실제 값이 일치해야 한다.
- 업종이 불명확한 데이터는 “기타 뷰티”로 표시할 수 있지만 false precision을 만들지 않는다.

---

## Deploy 36 — 우리 지역 필드 수렴

### 목적

새 기능 확장이 아니라, 아래 흐름을 대표 위치에서 반복 가능하게 만든다.

```text
우리 지역 진입
→ 현재 위치 또는 fallback center 확인
→ 1/3/5/10km 반경 변경
→ 카테고리 변경
→ 결과 수 변화
→ map marker + list 일치
→ 업체 카드 열기
→ 지도에서 보기
→ Naver Map fallback 확인
→ 0건일 때 반경 넓히기
```

### 처리 대상

- list/map count 불일치
- distance 표기 오류
- 지도 marker tap과 카드 정보 불일치
- 위치 실패에서 조용한 0건
- CTA 접근 불가
- Pages에서 asset load 실패

### 처리하지 않을 것

- 예약 연동
- 리뷰/랭킹
- 지도 UI 재설계
- 상권 AI
- 외부 API 실시간 동기화

---

# 6. 필드 기능 Acceptance Criteria

## A. 데이터

- [ ] 원본 업체 데이터가 1개 이상 로드된다.
- [ ] 유효 WGS84 좌표를 가진 업체가 1개 이상 존재한다.
- [ ] 영업/운영 상태가 제공되는 경우 폐업 업체를 기본 결과에서 제외한다.
- [ ] 업소명·업종·주소 중 최소 두 개가 표시 가능하다.
- [ ] 거리 표시는 좌표가 유효하고 같은 center 기준으로 계산된 경우만 한다.

## B. 중심·반경

- [ ] map, circle, list, count가 동일한 `AreaSearchCenter`를 사용한다.
- [ ] radius UI km와 filter meter가 일관된다.
- [ ] 1/3/5/10km 등 반경 변경 시 기대한 결과 수가 변한다.
- [ ] 현재 위치 실패 시 map/default center fallback이 있다.
- [ ] 0건은 실제 조건 0건과 시스템/데이터 실패로 구분된다.

## C. 탐색

- [ ] 선택 반경/카테고리/결과 수가 상단에 보인다.
- [ ] map marker와 list 항목은 같은 결과 집합이다.
- [ ] 카드에는 이름·업종·거리 또는 주소가 보인다.
- [ ] 데이터가 충분할 때 0건 empty state가 아닌 실제 목록이 보인다.
- [ ] 0건이면 반경 넓히기로 다음 결과를 찾을 수 있다.

## D. 외부 연결

- [ ] 업체 카드의 지도 CTA는 기존 지도/Place URL을 우선 사용한다.
- [ ] 없으면 좌표 → 주소 → 업체명+지역 순서로 fallback한다.
- [ ] 식별값이 없으면 CTA는 숨긴다.
- [ ] FlutterMap pan/zoom과 RegionMapExploreSheet는 유지한다.

## E. 신뢰·표시 원칙

- [ ] 출처·기준일이 가능한 데이터는 detail/footer에 표시한다.
- [ ] 지역·업종 통계를 개별 업소 매출처럼 표시하지 않는다.
- [ ] 정확하지 않은 거리를 표시하지 않는다.
- [ ] 고객 개인정보나 내부 샵 정보는 우리 지역 결과에 노출하지 않는다.

---

# 7. 자료 수집 체크리스트

오늘 야간에 에이전트가 확보·기록할 자료다.

## 코드 자료

```text
[ ] region_nearby_map_section.dart와 현재 map/list filter 위치
[ ] 업체 entity/model의 좌표·주소·업종 필드명
[ ] 현재 source/load repository/store
[ ] radius state와 단위
[ ] map center와 marker source
[ ] geolocation 호출 및 failure fallback
[ ] 지도 외부 URL launcher helper
[ ] 0건 empty state와 반경 확장 handler
```

## 데이터 자료

```text
[ ] 현재 원본 업체 총수
[ ] 좌표 보유 수
[ ] 유효 WGS84 좌표 수
[ ] invalid/missing 좌표 예시 3개
[ ] 현재 실샵/시사회 center 인근 업체 수
[ ] 1/3/5/10km 반경별 업체 수
[ ] category별 업체 수
[ ] 데이터 source, 기준일, coordinate system
```

## 공식 외부 자료 후보

```text
[ ] 행정안전부 생활 미용업 인허가 데이터
[ ] 소상공인시장진흥공단 상가(상권)정보
[ ] 시사회/실샵 지역 지자체 미용업 인허가 데이터
[ ] 국세청 통계로 보는 생활업종 (집계 지표 단계에서만)
```

---

# 8. 에이전트 야간 실행 명령

```text
오늘 야간의 단일 목표는 SORI ‘우리 지역’ 필드를 100% 작동시키는 것이다.

100%의 의미:
사용자가 반경 안 실제 뷰티 업소를 찾고,
업체를 이해하고,
지도에서 확인하고,
결과가 없거나 위치를 못 가져와도 다음 행동으로 회복할 수 있는 상태.

첫 작업은 Deploy 32다.
15분 안에 center/radius/source/coordinate/filter count diagnostics를 만든다.
추측하거나 UI를 더 꾸미지 않는다.

진단에 따라:
- source/load 문제면 source를 수리한다.
- 좌표 문제면 WGS84 파싱/좌표계 문제를 수리한다.
- center 불일치면 AreaSearchCenter 하나로 통합한다.
- 위치 실패면 map center/default region fallback을 만든다.
- 데이터가 실제로 없으면 대상 실샵 지역의 작은 public-data snapshot을 assets에 추가한다.

Deploy 32를 analyze/test/build/CI/Pages까지 끝낸다.
그 다음 데이터 필요 여부에 따라 Deploy 33,
위치 회복 Deploy 34,
카테고리 실제 매핑 Deploy 35,
필드 수렴 Deploy 36 순서로 멈추지 않고 진행한다.

각 PR은 사용자 결과 하나, production 파일 최대 4개다.
새 map SDK, 실시간 crawler, API key 노출, DB migration,
예약/결제/AI/지도 재설계는 하지 않는다.

완료 보고에는 반드시 아래 숫자를 쓴다:
- search center/source
- radius unit
- raw source count
- valid WGS84 count
- each radius filter count
- map/list count consistency
- PR/SHA/CI/Pages
```

---

# 9. 완료 보고 형식

```md
# Our Area Field Delivery Report

## P0 Diagnosis
- Search center/source:
- Map center:
- Radius UI/filter units:
- Raw shops:
- Valid WGS84 coordinates:
- 1km / 3km / 5km / 10km counts:
- Root cause:

## Deployed
| Deploy | User result | PR | SHA | Tests | Pages |

## Field acceptance
- Map/list same result set:
- Radius works:
- Category mapping works:
- Location fallback works:
- 0-result recovery works:
- Naver Map handoff works:

## Data provenance
- Source:
- Source date:
- Coordinate system:
- Supported initial area:

## Deferred
- Only non-field-core items
```

---

# 10. 최종 원칙

```text
우리 지역은 지도가 아니다.
우리 지역은 ‘내 주변에서 무엇을 발견하고, 무엇을 판단하고,
어디로 행동할지’를 즉시 알려주는 필드다.

빈 반경은 기능 미완성이다.
실제 업소 결과가 나오기 전까지 다른 기능으로 이동하지 않는다.

기존 지도 플랫폼을 이기려 하지 않는다.
SORI는 뷰티 업소 발견과 운영 판단의 시작점을 만들고,
검증·길찾기·상세는 가장 강한 외부 플랫폼에 연결한다.
```
