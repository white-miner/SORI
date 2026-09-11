# SORI — Global Design Reconstruction Inventory

**Status:** In progress · Checkpoint before reconstruction  
**Date:** 2026-09-11  
**Laws:** `docs/SORI_DESIGN_LAWS.md` · `docs/SORI_GLASS_PERFORMANCE.md`  
**Constraint:** Timer / Payment / Visit / 동의·B-A 보호 · Expand only

> 기존 화면·기능은 유지한 채 새 디자인 시스템으로 **교체**(삭제·도메인 리팩터 금지).

---

## 0. 전수 요약

| Tier | 대략 수 | 초점 |
|-----:|--------:|------|
| P0 | ~15 | Shell·GNB glass, VisitLauncher(홈 3목적), Timer 표시(로직 비침), 우리지역 지도, 고객차트 CTA, VisitSession, sheet glass 남용, 피드 중복 |
| P1 | ~35 | CRM hub, B/A, 공개 프로필, 경영, compose, 영어 탭 라벨 |
| P2 | ~55 | 세미나·프로그램 sheet·케어 고객·engagement |
| P3 | ~25 | deprecated CommunityPage, legacy admin, debug |

**교차 위반:** English (`My Feed`/`Program`/`Timer`/`Shop`/`AI`/`Whisper`) · GNB+AppBar+map 동시 glass · customer home=community 동일 위젯 · Director My 6탭 목적 혼재 · `SoriTokens.primary`가 charcoal이라 DESIGN LAW Purple CTA와 불일치 → **토큰 Expand로 brand/semantic 추가, primary 즉시 전면 교체 금지**.

---

## 1. Inventory (우선 재구성)

| 화면/컴포넌트 | 현재 목적 | 위반 법칙 | 문제 | 개선 방향 | 우선순위 |
|---|---|---|---|---|---|
| FloatingPillNav | 전역 이동 | glass 예산 | ~~중첩 blur~~ · 선택 brand · 원장「책상」 | blur 1(바만) | P0 ✓ |
| AppBar cluster | 셸 액션 | glass 예산 | ~~BackdropFilter~~ → opaque 92% · hit 48 | glass 0 | P0 ✓ |
| showSoriModalBottomSheet | 공용 sheet | glass 남용 | 기본 solid · glass는 Peek 전용 API | solid default | P0 ✓ |
| VisitLauncherPage | 홈 glance | 목적 1 | ~~영문 3탭~~ → 오늘/프로그램/타이머 · brand 밑줄 | glance 라벨(타이머 SSOT 유지) | P0 ✓ |
| HomeTimerStage | 타이머 표시 | — | UI만 손댐 | **VisitTimerStore/_onTick 금지** · chrome만 | P0 |
| RegionNearbyMapSection | 지역 탐색 | 상세 저장 | Peek CTA brand · 저장함→상세 · 글/세미나 상세 북마크 | P1 ✓ |
| CustomerChartPage | 고객 맥락 | CTA 과다 | ~~후기 AppBar~~ → ⋮ · FAB=본기록 · brand · KPI 축소 | P0 ✓ |
| VisitSessionPage | Visit 완결 | CTA 혼재 | ~~B/A FAB~~ → AppBar 보조 · phase CTA 유지 | P0 ✓ |
| VisitSessionPage | Visit 완결 | 목적 혼재 | ~~다단 동등~~ → R1-1 요약 히어로 · R1-2 이야기/관찰 접힘 · 파이프라인 유지 | 10초+30초 UX | P0 ✓ R1-1·R1-2 |
| showSoriModalBottomSheet | 공용 sheet | glass 남용 | 리스트 sheet까지 glass | solid default · Peek만 glass | P0 |
| UnifiedHomeFeed ×2 | 발견 | 목적 중복 | home=community | surface 역할 분리 | P0 |
| DirectorMyPageView | 사장 책상 | 영어·위계 | 탭 한국어 · 오늘=큐→경영peek→일정 | P0 ✓ |
| ShootHub / B/A | 촬영 | 영어 | ~~Before/After~~ → 전/후 · brand CTA | 한국어 + CTA 절제 | P1 ✓ |
| BizDashboard | 경영 | 위계 | ~~입력 우선·카드 과밀~~ → ★시간당 1 · A/B 라벨 · 입력 Level3 | 헤드라인 우선 | P1 ✓ |
| DirectorFandomProfile | 공개 프로필 | CTA | ~~팔로우 filled~~ → 예약/문의 brand 1 · 팔로우 secondary | 공개 전환 CTA | P1 ✓ |
| AppSettingsPage | 설정 | — | 모드 스위치 혼재 | 저빈도 정리 | P1 |
| Compose / Whisper | 작성 | 영어 | Whisper | 한국어 카테고리 | P1 |
| Program / Seminar sheets | 보조 | sheet 폭증 | — | solid sheet · CTA 1 | P2 |
| AI mock surfaces | — | 상태 발명 | mock | 계약 있는 것만 · 없으면 숨김 | P2 |
| Deprecated CommunityPage | — | — | 레거시 | 삭제 금지 · 진입만 축소 | P3 |

전체 라우트 SSOT: `lib/routing/sori_router.dart`. Shell: `lib/views/app_shell_page.dart`.

---

## 2. 구현 순서 (승인된 전역 명령 · 논리 커밋 분할)

1. ✅ DESIGN LAWS / GLASS PERFORMANCE 문서·rules  
2. ✅ Inventory 본 문서  
3. Design token Expand (`semantic` / `brand` / motion) — **primary charcoal 유지 + purple brand 추가**  
4. 공통: `SoriPressable`, Primary/Secondary/Destructive, EmptyState, GlassIconButton(지도용)  
5. Sheet 기본 solid · glass Peek만  
6. 우리지역 지도 WIP 완성·안정화  
7. FloatingPillNav / AppBar glass 예산  
8. 사장 책상·홈 glance·고객·방문 기록 UI  
9. 경영·공개 프로필·커뮤니티  
10. 전수 검수표

보호: Timer / Payment / Visit / customer_charts / 동의 B/A / destructive SQL.

---

## 3. Checkpoint

```text
branch: backup/pre-global-design-reconstruction
message: chore: checkpoint before global SORI design reconstruction
```
