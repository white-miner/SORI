# SORI — 버그 3건 트리아지 · Perplexity 회신 잠금

**Status:** Phase A·B·C **Approved** · 구현 완료 · 배포  
**작성:** Cursor (2026-09-11)  
**회신:** Perplexity (터치·B/A 카피·맵 중심·Edge Secret·GPS 웹)  
**원 요청:** 본 문서 초안 Q1–Q3  
**헬퍼 확인:** `showSoriSolidBottomSheet` = `useRootNavigator: true` + `isScrollControlled: true`(기본). clearance는 헬퍼가 자동 주입하지 않음 → **scroll content bottom padding**에 `kSoriFloatingNavClearance` 적용.  
**Phase C 참고:** GPS CTA는 geolocator 미도입으로 **보류**(C.1). 주소·Biz 폴백·center 전달·주소 CTA 선배포.---

## 0. 코드로 이미 확정 (재조사 금지)

(초안 §0 유지)

- 주간 셀 개별 제스처 없음 · 시트는 raw `showModalBottomSheet` · Timer 무관  
- B/A kebab 내리기=차트 보존 · 허브 발견성 갭 · 사진 삭제는 차트 경로 존재  
- 맵 문구 = `_center == null` · GPS 미사용 · Biz 주소 폴백 미연결  

---

## 1. Perplexity 권고 → **잠금 후보** (PO Yes 시 계약)

### A. 홈 주간 · 「오늘 일정」시트

| 항목 | 잠금 |
|------|------|
| 셀 개별 탭 | **Phase A 비채택** — 스트립은 표시 전용 |
| 카드 탭 | 유지 → `오늘 일정` 시트만 |
| 세로 hit | 시각은 작아도 **셀 영역 최소 48dp 높이** (Material) / iOS 44pt 하한 충족 목적 |
| 시트 | `showSoriSolidBottomSheet` · `useRootNavigator: true` · `isScrollControlled: true` |
| 하단 | 스크롤 **콘텐츠**에 `SafeArea + kSoriFloatingNavClearance` |
| 긴 목록 | scrollable child 기본 · (선택) DraggableScrollableSheet |
| 비범위 | Timer · 셀별 요일 딥링크 · 마이 CRUD |

**권고 1안 (잠금 문장):**  
주간 7일 스트립은 셀별 탭을 추가하지 않고 카드 전체 탭으로 `오늘 일정` 시트만 연다. 시트는 Sori 공통 헬퍼 + rootNavigator + scroll + nav clearance. 셀은 최소 48dp 세로 hit.

### B. B/A 내리기 vs 삭제 카피

| 동작 | 라벨 | 결과 | 금지 |
|------|------|------|------|
| 피드/성공사례 | **피드에서 내리기** | 커뮤니티 비노출 · 차트·사진·Visit 유지 · featured는 렌더 필터 | 차트/사진 파괴 · 동의 변경 |
| 차트관리/아카이브 | **커뮤니티 공개 중단** | 동일 | 동일 |
| 사진 | **사진 삭제** (필요 시 **영구 삭제** 확인) | 차트 URL 제거 · 모든 공개면 즉시 비노출 | 차트 row·다른 Visit 삭제 |
| 대표 | **대표 사례에서 제외** | 프로필만 · `caseShared` 유지 | 커뮤니티 자동 철회 |

**권고 1안:** `삭제`/`영구 삭제`는 원본 사진 파기 화면에만. 공개면은 `피드에서 내리기`/`커뮤니티 공개 중단`으로 통일. Unpublish SSOT는 kebab과 동일하게 linked post 정리.

### C. 우리지역 맵 중심

```
1. 사용자 탭 후 허용된 GPS (선택 · 자동 요청 금지)
2. Shop 저장 lat/lng
3. Shop 주소 → resolve_address → lat/lng
4. BizProfile 주소 → resolve_address → lat/lng
5. 실패 → 빈 상태 + 주소 입력 CTA
금지: 임의 서울/대한민국 중심
```

| 잠금 | 내용 |
|------|------|
| adm 없이 lat/lng | **맵 중심 OK** · adm은 필터/라벨 보조 |
| Kakao REST 키 | Flutter Web/번들 **금지** · Edge Secret `KAKAO_REST_API_KEY`만 |
| GPS 거부/timeout | 오류 화면 금지 · **기존 주소 중심을 null로 덮지 않음** |
| 타일 실패 | `_center == null`과 **분리 진단** (URL/Referer/CSP/403) |
| Phase C MVP | 우선 **Biz fallbackAddress + center 전달 + 주소 CTA** · GPS는 같은 Phase 또는 C.1 |

---

## 2. Phase 분할

| Phase | 목적 | 허용 | 금지 | ≤5 파일 초안 |
|-------|------|------|------|----------------|
| **A** ✅ | 스케줄 hit·시트 | 48dp 셀 높이 · `showSori*` · scroll · clearance | 셀별 탭 · Timer | done |
| **B** ✅ | B/A 내리기 발견성·SSOT | `unpublishBaFromCommunity` · 허브 「내리기」 · kebab 카피 | 차트 CASCADE · SQL | done |
| **C** ✅ | 맵 중심 | Biz 주소 폴백 · center 실어주기 · 주소 CTA | 가짜 서울 · REST 키 클라 · GPS(C.1) | done |

**공통 비범위:** Timer/`_onTick` · Payment · 일정 CRUD · SQL 마이그레이션 · 차트 row 삭제.

### Acceptance (보강 잠금)

| Phase | 문장 |
|-------|------|
| **A** | 오늘 일정 시트의 마지막 일정 행·닫기·주요 CTA는 FloatingPillNav 위로 충분히 스크롤 가능해야 하며, clearance는 외부 margin이 아닌 **scroll content bottom padding**에 적용한다. |
| **B** | 모든 공개 중단 진입점은 동일한 unpublish helper를 호출해야 하며, helper 호출 전후 `caseShared`와 linked `community_posts` 상태가 테스트에서 검증되어야 한다. |
| **C** | GPS 실패·거부는 `mapCenter`를 null로 설정하는 사유가 아니며, 이미 계산된 Shop/Biz 중심을 그대로 유지한다. 주소 후보가 모두 없거나 지오코딩 실패한 경우에만 center를 null로 둔다. |

**승인 순서:** A → B → C (각각 별도 승인·커밋).

---

## 3. PO 승인 문구 (복붙용)

### Phase A — **Approved**

> Phase A 승인: 홈 주간 스트립은 표시 전용·카드 전체 탭 유지. 셀 세로 hit ≥48dp. 「오늘 일정」은 `showSoriSolidBottomSheet`(rootNavigator·scroll·nav clearance). 셀별 날짜 탭·Timer·마이 CRUD 비범위. clearance는 scroll content bottom padding.
### Phase B

> Phase B 승인: B/A는 `피드에서 내리기`/`커뮤니티 공개 중단`으로 통일하고 unpublish 시 linked post까지 정리. 차트·사진·Visit 비파괴. 샵 허브에 내리기 진입. `영구 삭제`는 사진 파기만. SQL·차트 CASCADE 금지.

### Phase C

> Phase C 승인: 맵 중심 = (선택 GPS) → Shop 좌표 → Shop/Biz 주소 지오코딩 → 주소 CTA. adm 없어도 lat/lng면 중심 사용. 가짜 서울 금지. Kakao REST는 Edge Secret만. GPS는 사용자 탭 후에만·거부 시 주소 중심 유지.

---

## 4. 변경 로그

| 날짜 | 내용 |
|------|------|
| 2026-09-11 | 조사 요청 초안 |
| 2026-09-11 | Perplexity 회신 잠금 · Phase A/B/C 승인 문구 · **구현 금지** |
| 2026-09-11 | 최종 검토 AC 3문 · **Phase A Approved** · 헬퍼 clearance=content padding |
