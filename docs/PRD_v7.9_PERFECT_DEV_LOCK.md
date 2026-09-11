# SORI v7.9 — 완벽 개발 잠금 (Perplexity 회신 흡수)

**Status:** **PO Yes 1–7 확정** · **R1-1 chrome Expand 구현 완료** (파이프라인 교체 아님)  
**원 요청:** `docs/PRD_v7.9_PERFECT_DEV_MATERIALS_REQUEST.md`  
**회신일:** 2026-09-11  
**PO 확정:** 2026-09-11 · 1~7 Yes · R1-1 승인(요약 우선 chrome)  
**다음:** R1-2 (30초 접힘 콘텐츠) 별도 승인 후 · R1-3 완료 후 이동은 보류

---

## 0. 공통 잠금 (유지)

Timer SSOT · Payment 발명 금지 · Visit=`customer_charts` Expand ·  
커뮤니티 내리기 ≠ 홈 숨기기 · CTA 1 · glass=floating · 없는 상태 UI 발명 금지.

---

## R1. VisitSession — 10초 기록 (P0 · 최우선)

### 레이어

| 레이어 | 기본 | 내용 | 완료 관계 |
|---|---|---|---|
| 10초 | **항상 펼침** | 맥락 + 오늘의 케어 요약 1문장 + 칩 보조 + `기록 완료` | 직접 |
| 30초 | 접힘 | 고객 이야기 / 관찰 / 다음 관리 | 막지 않음 |
| 60초+ | 접힘·별도 | 사진 · B/A 후보(사진 있을 때만) | 막지 않음 |

### 권고 화면

```text
[오늘의 케어 요약] + [기록 완료]
접힘: [더 자세히 남기기] → 이야기/관찰/다음 관리
보조: [사진 추가] → B/A 후보는 사진 있을 때만
```

기각: SOAP 4칸 기본 펼침 · 사진 필수 완료 · 탭 4분할.

### 사진 미입력

- 미입력 = **배지 금지** · `선택 사항`/보조 문장만  
- 카피 A(권고): `사진은 필요할 때 추가할 수 있어요. 지금은 시술 요약만 남겨도 기록이 완료돼요.`  
- 완료 = `visitChecked && hasSummary` · 사진만으로 완료 금지

### 완료 직후

```text
기록 완료 → 짧은 확인
primary: [고객 상세 보기]
secondary: [다음 일정 보기] (일정 실제 존재 시만)
자동 홈 복귀 금지
```

### Phase

| Phase | 목적 | 비범위 |
|---|---|---|
| **R1-1** | 요약+완료 CTA · 보조 접기 | Timer · Payment · CASCADE |
| R1-2 | 30초 접힘 | 자동 visitChecked · 결제 |
| R1-3 | 사진/B/A 진입 · 완료 후속 | 자동 공개 · 동의 자동 |

**R1-1만 먼저 승인해도 핵심 가치 성립.**

---

## R2. 홈 vs 커뮤니티 피드

### 역할

| | 홈 | 커뮤니티 |
|---|---|---|
| 목적 | 시술·일정 glance · 개인 B/A · 추천 1~3 | 탐색·글·세미나·반응·작성·저장 |
| Boost | **금지** | 조건부·라벨 필수 (v7.9 미구현 권고) |

### 재사용

동일 `community_posts` + **FeedQueryConfig(surface)** + Shared PostCard + chrome 분리.  
위젯 전체 복제·완전 동일 재사용 기각.

### Phase

R2-1 config · R2-2 chrome · R2-3 CTA/헤더.

---

## R3. Whisper / Compose

- 내부 enum/API/analytics **유지**  
- UI만 `CategoryPresentationMap`  
- Whisper 노출 → **조용한 이야기**  
- filled CTA 1 · 칩 최대 5 · 역할 혼용 금지  

금지 영문 대체: Analytics→경영, Dashboard→사장 책상, Compose→글 쓰기, Feed→글 모아보기/추천 글, Unpublish→커뮤니티 공개 중단 등 (요청서 표 유지).

---

## R4. AppSettings

순서: 계정 → 내 샵과 공개 → 알림 → 앱 환경 → 고급.  
모드 전환: 설정 toggle **숨김** → 셸 결과형  
`고객 화면으로 보기` / `사장 책상으로 돌아가기`.  
실험·디버그·Payment 설정은 축소/고급.

---

## R5. HomeTimerStage

- chrome-only로 위계 가능 = **Yes**  
- `_onTick`/FlipClock/산식/병렬 시계 **절대 금지**  
- **지금은 보류** = Yes (R1·R2 후)

---

## R6. 검수 · 5분 스모크

요청서 화면별 통과/실패 문장 + 8스텝 스모크 채택.  
VisitSession 통과: *요약 한 문장 남기면 완료 가능함이 즉시 보인다.*

---

## PO Yes/No (확정 대기)

| # | 질문 | PO |
|---|---|---|
| 1 | R1 기본 = 요약+기록완료만 펼침 · 사진·관찰·다음관리 접힘? | **Yes** |
| 2 | 완료 후 primary=고객 상세 · secondary=다음 일정(있을 때만) · 자동 홈 금지? | **Yes** |
| 3 | 홈=glance+가벼운 발견 · 작성/댓글/탐색=커뮤니티만? | **Yes** |
| 4 | community_posts 공유 + surface별 config/chrome/CTA 분리? | **Yes** |
| 5 | Whisper 노출=`조용한 이야기` · 내부 key 유지? | **Yes** |
| 6 | 모드 전환=셸 결과형 action · 설정 toggle 숨김? | **Yes** |
| 7 | HomeTimerStage chrome은 R1·R2 후 보류? | **Yes** |

**전부 Yes면** → 다음 구현 승인 단위는 **R1-1만** (요약 위계·접기·완료 CTA · ≤5파일).

---

## 변경 로그

| 날짜 | 내용 |
|------|------|
| 2026-09-11 | Perplexity 회신 흡수 · 구현 금지 · PO Yes/No 대기 |
| 2026-09-11 | PO 1–7 전부 Yes · R1-1 구현 대기 |
| 2026-09-11 | **R1-1 구현** — 요약 히어로 · Plan 상세 접기 · CTA brand · pop/consent 계약 유지 |
