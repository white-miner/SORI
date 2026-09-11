# SORI — 완벽 개발을 위한 추가 자료 요청서

**Status:** Draft · 조사·컨설팅 요청 · **회신 흡수됨** → `docs/PRD_v7.9_PERFECT_DEV_LOCK.md` · **구현 금지(PO Yes/No·Phase 승인 전)**  
**작성:** Cursor (2026-09-11)  
**PO:** 마인드  
**대상:** Perplexity (1차) · 필요 시 Claude 교차 검수  
**근거 계약:** `docs/SORI_DESIGN_LAWS.md` · `docs/SORI_GLASS_PERFORMANCE.md` · `docs/SORI_DESIGN_RECONSTRUCTION_INVENTORY.md` · `docs/PRD_v7.9_MY_PAGE_MASTER.md` · `docs/PRD_v7.9_UI_UX_BRIEF.md` · `docs/PRD_v7.9_HOME_CASE_HIDE.md`

> 목적: 남은 P0/P1을 **추측 없이** 잠그기 위한 빈칸만 채운다.  
> 예쁘게 만들지 말고, **작업 상태 · 기록 완결 · 시간 흐름 · 신뢰**가 보이게.

---

## 0. 이미 잠긴 전제 (재조사·장문 재서술 금지)

| # | 잠금 |
|---|------|
| 1 | 3면: 홈(시술 glance) · 사장 책상(사후·경영) · 공개 프로필(신뢰·전환) |
| 2 | Timer SSOT = `VisitTimerStore` / `_onTick` / FlipClock — **삭제·병렬 시계 금지** |
| 3 | Payment SSOT 미완 — `payment_missing`·금액 발명 금지 · A/B는 라벨 분리만 |
| 4 | Visit ≈ `customer_charts` · Expand only · CASCADE 삭제 금지 |
| 5 | B/A 커뮤니티 = 「피드에서 내리기」(`caseShared`) · 홈 = 「홈에서 숨기기」(`home_hidden_at`) **완전 분리** |
| 6 | 경영 ZONE1 ★ = 시간당 수익 · 입력은 Level 3 |
| 7 | 공개 프로필 filled CTA = 예약/문의 1 · 팔로우 secondary |
| 8 | Glass = floating만 · sheet 기본 solid · PillNav blur 1 |
| 9 | filled primary CTA 화면당 1 · brand=`SoriTokens.brand` · primary charcoal 전면 교체 금지 |
| 10 | 없는 상태 UI 발명 금지 (`visitChecked`·`hasSummary`·note·B/A 공개만) |

---

## 1. 완료된 재구성 (조사 불필요)

- Shell glass 예산 · 사장 책상 오늘 위계 · 고객차트/VisitSession CTA · 홈 탭 한국어  
- 지도 Peek/북마크 · 경영 헤드라인 · 공개 프로필 CTA · 홈 케이스 숨김 · ShootHub 전/후  

**남은 핵심만 조사한다.**

---

## 2. 조사 필요 영역 (우선순위 고정)

### R1. VisitSession — 「10초 기록」작업대 (P0 · 최우선)

**현상:** 다단 파이프라인·CTA·보조 액션이 한 화면에 겹쳐 **10초 완결**이 안 보임.  
**이미 함:** B/A FAB → AppBar 보조 · phase CTA 유지.  
**질문:**

1. 10초 / 30초 / 60초+ 레이어를 **접기 규칙**으로 쓸 때, 기본 펼침은 무엇만인가? (표)  
2. 「기록 완료」조건을 `visitChecked && hasSummary`로 둘 때, 사진 미입력은 오류가 아님을 UI에서 어떻게 표현하는가? (카피 2안 · 배지 금지 여부)  
3. 완료 직후 다음 행동 1개만 남긴다면: 고객 상세 / 다음 일정 / 홈 복귀 중 **권고 1안**과 금지 CTA.  
4. Phase 분할 ≤3 · 각 Phase 파일 수 감각(제품 단위) · **VisitTimerStore·Payment·차트 CASCADE 비범위** 명시.

### R2. UnifiedHomeFeed ×2 — 홈 vs 커뮤니티 역할 분리 (P0)

**현상:** 고객/원장 홈과 커뮤니티가 **같은 피드 위젯·자산**을 공유해 목적 중복.  
**질문:**

1. 홈 발견면 vs 커뮤니티 광장의 **콘텐츠 허용 표** (넣어도 됨 / 넣으면 안 됨).  
2. 동일 `community_posts`를 두 면에 쓸 때: 필터·정렬·카드 chrome만 다르게 할지, **라우트·헤더·CTA만 다르게** 할지 권고 1안.  
3. Boost/광고는 어느 면에만 허용인가.  
4. Expand 단계: 위젯 복제 금지 전제에서 **최소 분리 순서** 3단계.

### R3. Compose / Whisper — 한국어 카테고리 (P1)

**현상:** Whisper 등 영문 카테고리·톤이 원장 문해력과 어긋남.  
**질문:**

1. WhisperAtoms(또는 동등 카테고리)를 **한국어 라벨만** 바꿀 때, 내부 enum/키는 유지하는 Expand 규칙.  
2. 금지 영문 목록(Analytics/Dashboard/Whisper 노출명 등)과 대체 한국어 표.  
3. 작성 화면 filled CTA 1개 규칙과 카테고리 칩 과밀 방지(최대 칩 수).

### R4. AppSettings — 모드 스위치 혼재 (P1)

**현상:** 원장/고객·알림·실험 플래그가 한 화면에 섞여 저빈도 설정이 위험해 보임.  
**질문:**

1. 설정 섹션 위계: 계정 · 샵 공개 · 알림 · 고급 — 권고 순서.  
2. **모드 전환**(원장↔고객)을 설정에 둘지, 프로필/셸에 둘지. 실수 방지 1규칙.  
3. 이번 Phase에서 **숨길 항목** vs **남겨둘 항목** 표 (기능 삭제 금지·진입만 축소).

### R5. HomeTimerStage chrome-only (P0 · 범위 확인)

**현상:** inventory에 “UI만”으로 남아 있음.  
**질문:**

1. 플립시계 **유지** 전제에서 chrome(여백·라벨·세그먼트 칩)만 손대도 DESIGN LAWS 위계가 성립하는가?  
2. 손대면 안 되는 픽셀/동작 체크리스트 5줄 (`_onTick`·잔여시간 표시 계약 포함).  
3. **지금은 보류**해도 되는가? (예: VisitSession·Feed 분리가 더 급함) Yes/No + 이유 1줄.

### R6. 전수 검수표 · Acceptance (마무리용)

**질문:**

1. DESIGN LAWS 3초 위계 + UI 브리프 검수 3문항을 **화면별 체크리스트**로 압축(홈·책상오늘·고객·Visit·경영·공개·지도·촬영).  
2. 각 화면 “통과/실패” 기준 1문장.  
3. PO가 실기기에서 볼 **5분 스모크 시나리오** 8스텝 이내.

---

## 3. 산출물 형식 (필수)

| 규칙 | 내용 |
|------|------|
| 길이 | R1–R6 각각 **표 또는 짧은 불릿** · 장문 IA 재탕 금지 |
| 권고 | 영역마다 **권고 1안** + 기각 대안 1줄 |
| 근거 | URL 또는 벤치 제품명 (없어도 “근거 없음·PO 판단” 명시) |
| Phase | Expand · ≤5파일/커밋 감각 · 금지 목록 |
| 끝 | **PO Yes/No 질문 ≤7개** |
| 상단 고정 | `Status: Draft · 자료 요청 · Approved 아님 · 구현 금지` |

---

## 4. 금지 (회신에 넣지 말 것)

- Timer/`_onTick`/FlipClock 제거·교체  
- Payment·노쇼·자동 visitChecked 상태 발명  
- 차트/Visit CASCADE 삭제 · `caseShared`와 `home_hidden_at` 합치기  
- Instagram형 전면 리디자인 · 멀티지점·직원 권한·자동환불  
- “보관함/복구센터” 신규 면 발명 (홈 숨김 복구는 **후속 Phase**로만 언급)  
- primary charcoal 전면 토큰 교체  

---

## 5. Perplexity에 붙일 짧은 프롬프트 (복붙)

```text
SORI 1인 샵 앱 — 남은 P0/P1 완벽 개발용 자료 요청.
문서: docs의 「완벽 개발을 위한 추가 자료 요청서」R1~R6을 그대로 답하라.

잠금(재서술 금지): Timer SSOT 유지 · Payment 발명 금지 · Visit=customer_charts Expand ·
B/A 커뮤니티 내리기 ≠ 홈 숨기기 · CTA 화면당 1 · glass=floating only · 없는 상태 UI 발명 금지.

우선: R1 VisitSession 10초 기록 → R2 홈/커뮤니티 피드 분리 → R3 Whisper 한국어 →
R4 설정 → R5 Timer chrome 보류 여부 → R6 검수표.

산출: 권고 1안 표 · Phase≤3 · 금지 목록 · PO Yes/No ≤7.
구현 코드·파일명 추측 금지. Status: Draft · Approved 아님 · 구현 금지.
```

---

## 6. 회신 후 Cursor 작업 순서 (참고 · 구현은 별도 승인)

1. 회신을 `docs/PRD_v7.9_*_LOCK.md` 또는 MASTER 부록으로 흡수  
2. PO가 R1→R2→… 순 **Phase 승인**  
3. 커밋 1 = 논리 1 · ≤5파일 · 테스트 실행 증명  
4. 전수 검수표로 P0 마감  

**다음 구현 기본 후보(승인 전):** R1 VisitSession 10초 UX.
