# 디자인 골든 기준선 (D0-1)

디자인 개편(`docs/sori-design-overhaul-plan.md`) 전 화면 12개를 **360px · 1280px** 로 고정한 골든 24장입니다.
앱 코드는 바꾸지 않았고, 이후 디자인 PR 이 화면을 바꾸면 이 골든으로 전후를 보여 줍니다.

| # | 화면 | 위젯 |
|---|---|---|
| 01 | 로그인 | `EntryHomePage` |
| 02 | DESK 빈 상태 | `VisitLauncherPage` (차트 0건) |
| 03 | DESK 기록 3건 | `VisitLauncherPage` (B&A 차트 3건) |
| 04 | 고객 목록 | `DirectorCustomersTab` |
| 05 | 고객 차트 | `CustomerChartPage` |
| 06 | 차트 방문 미리보기 | `ChartVisitRoutePage` (`/chart-visit`) |
| 07 | B&A 상세 | `BeforeAfterComparePage` |
| 08 | 커뮤니티 피드 | `CommunityPage` |
| 09 | 원장 프로필 갤러리 | `DirectorFandomProfilePage(isOwner: false)` |
| 10 | 희망 일정 요청 | `CareScheduleLeadPage` |
| 11 | 케어 리포트(정상) | `CareReportPage` |
| 12 | 케어 리포트(없음·만료) | `CareReportPage` (없는 chartId) |

## 실행

```bash
cp .env.example .env              # 처음 한 번
tool/design_goldens.sh            # 커밋된 기준선과 비교
tool/design_goldens.sh --update   # 기준선 갱신 → PR 에 전후 이미지 첨부
tool/design_goldens.sh --compare  # origin/main 과 현재 트리를 같은 날 그려 build/design_goldens_compare/ 에 저장
```

- 테스트는 `@Tags(['golden'])` 이고 **`SORI_DESIGN_GOLDENS=1` 일 때만** 돕니다. 일반 `flutter test` 에서는 24개 모두 skip 이라 기존 결과에 영향이 없습니다.
- Linux(CI `ubuntu-latest`)에서 만들었습니다. Windows/macOS 는 안티앨리어싱이 달라 0.5% 까지만 허용합니다(`test/support/tolerant_golden_comparator.dart`). 갱신은 Linux(또는 CI)에서 하세요.

## 결정성

- **글꼴:** 운영 웹은 Google Fonts 의 Work Sans(라틴)·Instrument Serif 를 받고, 한글은 CanvasKit 이 Noto Sans/Serif KR 로 폴백합니다. `fonts/` 에는 이것을 합친 서브셋 글꼴(라틴 + KS X 1001 한글 2,350자 + 코드에 쓰인 한글, OFL)을 두었습니다. 테스트에서만 `flutter/assets` 채널을 목으로 바꿔 google_fonts 가 이 파일을 "번들 글꼴"로 찾게 합니다. 앱의 `pubspec.yaml` 은 그대로이고 네트워크도 쓰지 않습니다.
  - 생성: google/fonts 의 가변 TTF → fontTools `instancer`(400/500/600/700/800) → `subset` → `merge`(Work Sans + Noto Sans KR). GSUB/GPOS 는 합칠 때 빠집니다(커닝 차이는 아주 작음).
- **사진:** http(s) 이미지 요청에는 `fixtures/before.png` · `after.png` 를 돌려줍니다(URL 에 `after` 가 있으면 after). Google Fonts 요청은 400 입니다.
- **데이터:** `MemorySoriRepository` 시드 + 테스트에서 고정 날짜의 B&A 차트 3건을 넣습니다. `SharedPreferences` 와 `path_provider` 는 목입니다.
- **시계 (한계):** 앱이 `DateTime.now()` 를 직접 씁니다(lib 432곳). libfaketime 으로 테스트 프로세스 시계를 고정해 봤지만 flutter_tester 가 수십 배 느려져(테스트 1개에 5분 이상) 쓰지 않았습니다. 그래서 '오늘'이 보이는 화면(02·03 DESK, 04 고객 목록 주간 띠 등)은 기준선 날짜 **2026-10-17 (KST)** 가 아닌 날에는 비교가 실패할 수 있습니다. 디자인 PR 에서는 `--compare` 로 같은 날 그려 비교하세요. 근본 해결은 `clock` 패키지 주입(앱 코드 변경, 별도 승인)입니다.
- **알려진 표시 한계:** `fontFamily` 가 지정되지 않은 일부 버튼 글자(예: 10번 "희망 일정 보내기", 11번 하단 버튼)는 flutter_tester 기본 글꼴(네모)로 보입니다. 운영 웹에서는 정상으로 보이는 글자입니다. 테마 글꼴을 따르지 않는 컴포넌트라는 뜻이라, D0-4 테마 연결에서 함께 고칩니다.
