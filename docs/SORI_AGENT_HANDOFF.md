# SORI — 클로드 역할과 앱 설정

에이전트가 껍데기만 만들지 않도록, 역할과 현재 세팅을 한곳에 고정한다.
비밀값(anon key, service role, OpenAI 키)은 이 문서에 적지 않는다. 이름과 위치만 적는다.

## 0. 작업방식 SSOT (LOCKED)

**ChatGPT 직관 작업방식**이 기준이다. 바꾸지 않는다.

- `docs/SORI_CHATGPT_WORK_STYLE_LOCK.md`
- `.cursor/rules/50-chatgpt-work-style-lock.mdc`

출구 한 줄 → 입구·통로·출구 한 호흡 → 파이프 먼저 → 정직 실패 → 구식 제거 → 범위 한 줄 → 끝나면 끝.

## 1. 클로드(이 에이전트)의 역할

사용자는 기획한다. 에이전트는 개발자 언어로 번역한 뒤, **입구 → 통로 → 출구**가 닫힌 뒤에만 코드를 고친다.

하지 말 것:

- 기획 문장의 명사 하나만 보고 위젯을 새로 그린다.
- 시계 UI를 만들고 1초 동기화 파이프는 비워 둔다.
- 이미 있는 스토어 옆에 더미 타이머·더미 TTS를 또 만든다.
- 관련 없는 작업본(피드, B/A, 마이그레이션)을 같이 커밋한다.

할 것:

1. 원하는 결과(초가 줄어든다, 이 문장이 나온다)를 한 줄로 적는다.
2. 기존 SSOT 파일을 읽고 입구·통로·출구를 이름까지 짚는다.
3. 끊긴 칸만 고친다.
4. 그 경로를 검증하는 테스트를 돌린다.
5. 사용자가 커밋·푸시를 말했으면 그 파일만 올린다.

## 2. 타이머 현재 구조 (SSOT)

플립시계는 출구다. 숫자는 스토어가 넘긴 현재 구간 초다.

| 칸 | 파일 | 동작 |
| --- | --- | --- |
| 입구 | `lib/features/visit/visit_launcher_page.dart` `_openCareStart` | 케어 시작. 화면 전환 없음. 터치 직후 TTS prime. |
| 입구 | `lib/features/operation/visit_timer_store.dart` `startCare` / `jumpToStep` | 스텝 시작 시각을 찍고 틱을 켠다. |
| 통로 | 같은 파일 `_ensureTicking` → `_onTick` | 1초마다 `_onTick()` 호출 후 `notifyListeners()`. |
| 계산 | `lib/visit_kernel/models/visit_operation_timer.dart` `VisitTimerLiveSnapshot.compute` | `now - currentStepStartedAt` → `currentStepRemainingSeconds`. |
| 출구 | `lib/features/visit/widgets/home_timer_stage.dart` | 리스너 → `setState` → `FlipClockDisplay(style: darkGlass)`. |
| 리스트 | `lib/features/operation/widgets/care_timer_step_list.dart` | 탭 → 1.3배 `PressBounce` → `jumpToStep`. |
| 음성 | `lib/features/operation/care_timer_tts_service.dart` | `flutter_tts`. 파일 없음. |

금지:

- `Timer.periodic(..., (_) => _onTick)` — 호출이 아니다.
- 대기 화면에 시스템 시각을 중앙 시계로 넣기.
- 총 소요 시간을 중앙 플립에 넣기.

## 3. TTS 현재 세팅

패키지: `flutter_tts` ^4.2.3. 언어 `ko-KR`.

| | 앱 (iOS/Android) | 웹 |
| --- | --- | --- |
| rate | 0.43 | 0.92 |
| pitch | 1.18 | 1.12 |
| volume | 1.0 | 1.0 |

보이스: `getVoices` 점수제. 우선 Yuna Enhanced, Microsoft Heami/SunHi, Google Neural2/Wavenet-A. 남성·비한국어 제외.

멘트:

- 케어 시작: `케어를 시작합니다.`
- 케어 종료: `케어를 종료합니다.`
- 구간 점프/전환: `{구간명}을/를 진행합니다.` (이름 없으면 `다음 케어를 진행합니다.`)

웹은 사용자 터치 안에서 `CareTimerTtsService.primeFromUserGesture()` 가 먼저다. 안 하면 브라우저가 음성을 막는다.

## 4. GitHub

| 항목 | 값 |
| --- | --- |
| 원격 | `https://github.com/white-miner/SORI.git` |
| 기본 브랜치 | `main` |
| 최신 기준(이 문서 작성 시) | `46565f2` TTS 보이스 튜닝 |
| 웹 주소 | `https://white-miner.github.io/SORI/` |
| 배포 | `.github/workflows/deploy.yml` — `main` push 시 Flutter web → GitHub Pages |
| 테스트 | `.github/workflows/test.yml` — `main` push/PR 시 `flutter test` + golden |
| base href | `/SORI/` |
| 캐시 버스트 | `index.html`의 `SORI_BUILD_ID` → GitHub Actions run number |

로컬 셸: Windows PowerShell. `&&`로 명령을 잇지 않는다.

커밋은 사용자가 말할 때만. 푸시도 마찬가지. force push, hook 생략, git config 변경 금지.

## 5. Supabase

클라이언트: `supabase_flutter` ^2.9.1. 초기화 `lib/services/supabase_client.dart`. 설정 읽기 `lib/config/env.dart`.

환경 변수 (값은 `.env`와 GitHub Secrets. 커밋 금지):

| 키 | 용도 |
| --- | --- |
| `SUPABASE_URL` | 프로젝트 루트. `/rest/v1`이 붙어 있으면 제거. |
| `SUPABASE_ANON_KEY` | 클라이언트 publishable/anon. |
| `OPENAI_API_KEY` | 케이스 스토리 등. 없으면 해당 기능만 스킵. |
| `SITE_URL` | OAuth Site URL. 비거나 localhost면 `https://white-miner.github.io/SORI/` 로 강제. |

로드 순서: `--dart-define` → `.env` → (둘 다 비면) `.env.example`.
CI는 `.env`가 없으면 example을 복사하고, 실제 URL/키는 GitHub Secrets를 `--dart-define`으로 넣는다.

인증:

- 카카오 OAuth만. 이메일 매직링크 없음.
- 웹 redirect: `SITE_URL`
- 앱 redirect: `sori://login-callback`
- 카카오 스코프: nickname + profile image (account_email 없음)
- 대시보드 Site URL / Redirect URLs에 `https://white-miner.github.io/SORI/` 가 있어야 한다.

스키마: `supabase/migrations/`. 최신 번호대는 `116_accept_program_quote_v72.sql`. 이미 적용된 마이그레이션 파일을 수정하지 말고 다음 번호로 추가한다. 작업 트리에 삭제 표시된 `030_community_feed_conversion.sql`은 타이머 작업과 무관하다. 건드리지 않는다.

Edge Functions (`supabase/functions/`):

- `ai-case-story`
- `get-clinical-trends` / `refresh-clinical-trends`
- `get-shop-weather` / `get-shop-climate`

호스티드 함수는 `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`를 플랫폼이 주입한다. 서비스 롤 키를 클라이언트·문서·커밋에 넣지 않는다.

## 6. 앱 정체

| 항목 | 값 |
| --- | --- |
| 패키지 | `sori` (`pubspec.yaml`) |
| SDK | Dart ^3.12.2 |
| 버전 | `1.0.0+2026082811` (스토어 빌드 번호는 CI `github.run_number`가 덮을 수 있음) |
| 웹 타이틀 | 소통하는 리뷰, SORI |
| 홈 탭 | My Feed / Program / Timer |
| 타이머 탭 | 본문에 시계·컨트롤·구간 리스트·고객 연결. 풀스크린은 확대만. |

## 7. 에이전트가 막힐 때 보는 순서

1. 이 문서의 입구·통로·출구 표.
2. `VisitTimerStore`의 `_ensureTicking` / `_onTick`.
3. `HomeTimerStage._stepClockSeconds`가 무엇을 시계에 넣는지.
4. `.env` 존재 여부와 `Env.hasSupabaseConfig`. 키 값은 로그에 찍지 않는다.
5. 웹이면 터치 제스처 안에서 TTS prime이 있는지.
