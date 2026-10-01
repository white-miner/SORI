# 디지털 차트지 실행 체크포인트

기준: [최종 기획서](SORI_DIGITAL_CHART_PRODUCT_SPEC.md)

## 재개 방법

1. AGENTS.md, docs/SORI_VISUAL_STANDARD.md, docs/CONTRACTS.md와 위 기획서를 읽는다.
2. `git status --short`와 해당 파일 diff를 확인한다. 기존 작업을 삭제/덮어쓰거나 초기화하지 않는다.
3. 아래 마지막 완료 지점과 진행 중 작업을 읽고, 실제 파일 및 테스트 결과와 대조한다.
4. 진행 중 작업만 이어서 검증한다. 완료 단계는 새 변경의 영향이 있을 때만 재검증한다.
5. 각 작업 종료 또는 중단 전에 이 문서에 변경 파일, 테스트 명령/결과, 미확인 항목, 다음 행동을 갱신한다.

사용량 제한 해제 후 자동 실행은 보장되지 않는다. 사용자가 'SORI_DIGITAL_CHART_PROGRESS.md를 읽고 이어서 개발하라'고 요청하면 이 체크포인트부터 재개한다. 자동화·예약은 설정하지 않았다.

## 작업 시작 상태

- 시작일: 2026-09-29
- 브랜치: fix/market-key-encoding
- 시작 HEAD: 3a4624c9d3f55536de220105d4683b5c9e1879b0
- 기존 untracked: docs/SORI-market-fix-deploy-2026-09-25.md, supabase/.temp/, 앞서 작성한 기획 문서 2개. 보존한다.
- 사용자 승인: 최종 계획 실행 및 후속 지시로 완료분 커밋·운영 배포 승인.
- 단계별 코드/테스트 변경을 5파일 이하로 분할한다. 기준 문서 자체의 중단/승인 지점을 존중한다.

## 단계 상태

| 단계 | 상태 | 범위 |
|---|---|---|
| 1 | 완료 | 문진→상담 근거 표시, 실제 고객의 직접 상담 입력, 문진 변경 후 재승인 |
| 2 | 완료 | 지난 방문 맥락 확인과 오늘 확인한 재방문 반응 작성·복원 |
| 3 | 구현·관련 테스트·로컬 UI 검수 완료 | 상담→관리→변화 연결, 실제 서버 왕복 미확인 |
| 4 | 4A·4B 로컬 구현·검증 완료 | 미확인·샘플 기본값·피부/체형 공통 표현 |
| 5 | 대기 | 저장 순서·완료·재조회·복구 |
| 6 | 대기 | 실제 촬영·부위별 사진·리포트 |
| 7 | 대기 | 최소 기록 동선·복사·선택 상세 |
| 후속 | 별도 승인 | 음성 공급자·정책, 체형 실측 저장 확장 |

## 현재 작업: 단계 4A·4B 완료 · 배포 차단 원인 재현

- 다음 우선 작업은 Stage 5의 단계형 작성기 저장 순서다. 지연된 draft 요청을 붙잡고 완료한 뒤 해제하면 `completed → draft` 순서로 쓰인다. 아래 4B의 배포 검증 기록을 먼저 읽는다.
- 홈 CHART의 자동저장 직렬화 회귀 테스트는 통과하지만, 별도 `ChartVisitFlowPage`는 같은 보호가 없다. 두 경로를 구분한다.

- 홈 CHART의 실제 진입점은 `ChartVisitWorkspace`다. 아래 Stage 3에서 이 진입점에도 문진을 보며 직접 상담하고 적용하는 UI를 연결했다.
- Stage 4A·4B를 완료했다. Stage 5~7 및 실제 인증 고객 서버 왕복은 아직 완료되지 않았으며 전체 디지털 차트 완성으로 취급하지 않는다.
- 아래 '단계 1~2 완료 기록'과 Stage 3 최신 이력을 구분해서 읽는다.

### 단계 1~2 완료 기록

- 수정 범위: `lib/features/chart_visit/chart_visit_flow_page.dart`, `lib/features/chart_visit/consultation_intake_context.dart`, `test/chart_visit_preview_test.dart`, `test/chart_visit_consult_context_test.dart`. 모델/DB/기존 저장 함수 변경 금지.
- 변경 전 기준: `flutter test test/chart_visit_preview_test.dart test/chart_visit_record_test.dart test/chart_workspace_page_test.dart` → 11개 PASS. Supabase 미초기화 및 샘플 사진 HTTP400 로그는 있었으나 테스트 실패 없음.
- 완료 조건: 같은 session의 문진이 상담에 보임, 직접 기록→적용, 이전 단계 편집 후 값 유지, 360px/넓은 화면 레이아웃 검증.
- 완료 결과: 상담 화면 상단에 이번 방문 문진 원문과 안전정보 확인 상태를 표시하고, live 모드에서는 샘플 녹음 대신 직접 상담 작성을 제공한다. 상담 승인 후 문진·안전정보가 바뀌면 승인을 해제하고 재적용을 요구한다.
- 검증: `flutter analyze --no-pub lib/features/chart_visit/chart_visit_flow_page.dart lib/features/chart_visit/consultation_intake_context.dart test/chart_visit_consult_context_test.dart test/chart_visit_preview_test.dart` → No issues found. 관련 4개 테스트 파일 → 15개 PASS.
- 실제 렌더링: 로컬 `http://127.0.0.1:8136/#/chart-visit`에서 390×844와 1024×900을 확인했다. 문진 원문, 직접 상담 작성, 적용 전 상태, 하단 `차트에 적용` CTA가 표시되며 넓은 화면도 좌측 고객·단계/우측 작성 영역으로 유지된다.
- 웹 빌드: `flutter build web --no-pub` → `build/web` 생성 성공. 기존 `flutter_tts` WebAssembly dry-run 경고 3건은 의존성 코드에서 발생했으며 일반 Web 빌드를 막지 않았다.
- 제한: 실제 인증 고객과 Supabase 저장 왕복은 이번 단계 범위가 아니며 검증하지 않았다. 샘플 모드의 `샘플 상담 시작`은 기존 미리보기용으로만 남아 있다.
- 커밋·배포: Stage 1~2 코드 `431cb79`를 main에 push했고 Pages #552 배포 성공. 아래 배포 검증 참고.

## 검증 및 변경 이력

### 2026-10-01 Stage 4B

- 변경 파일 5개: chart_visit_flow_page.dart, chart_visit_workspace.dart, test/chart_visit_preview_test.dart, test/chart_workspace_page_test.dart, 이 체크포인트.
- 두 작성 화면 모두 빈 안전정보를 '미확인'으로 표시하고 편집에 미확인/없음/있음을 구분했다. 반응은 비어 있다는 이유만으로 없음이 선택되지 않는다. 마지막 반응 칩 해제도 미확인으로 돌아간다.
- 체형·등/하체/어깨·목 불편·붓기 고민과 이완/순환/체형 목표를 기존 선택 목록에 확장했다. 피부 점수는 선택 영역으로 접고 단계형 작성기에서 고민 선택 없이도 피부 체크·사진 구간에 접근 가능하게 했다. 실제 체형 실측과 사진 촬영 연결 확대는 Stage 6 범위로 남는다.
- 관련 테스트 46 PASS. 기존 관리 삭제 테스트는 자동 삽입된 샘플에 의존하지 않고 명시적 관리 fixture를 준비하도록 변경하여 삭제·번호 재정렬·재열기 검증을 유지했다. 관련 UI 2개 파일 분석 No issues found.
- 전체 `flutter test --no-pub --reporter expanded`: 811 PASS / 기존 동일 9 FAIL(피드·홈·boost·golden). 이번 관련 신규 실패 없음. 로그 `%TEMP%/sori-4b-full-test.log`.
- 앱 `flutter build web --no-pub --release --base-href /SORI/` 성공(Built build/web, exit 0), 로컬 검수 앱 release 빌드도 성공. 기존 flutter_tts Wasm 경고 유지. 360×800에서 실제 홈 고객 선택→미확인 6항목→알레르기 없음 선택→등 불편/이완 선택→임시저장→재열기 조작 확인. 재열기 시 알레르기 없음과 나머지 미확인, 빈 관리 단계가 보존됐다. 1024×900 재열기 렌더링 확인. 단계형 작성기에서 고민 미선택 상태에도 피부 체크/사진 영역 노출, 체형 고민 선택 후 상세 질문 노출 확인. 서버/실기기 검증을 대체하지 않는 메모리 저장소 검수다.
- 캡처: `%TEMP%/sori-stage4-captures/01-unknown-mobile.png`, `02-body-mobile.png`, `03-reopened-tablet.png`, `04-optional-skin-mobile.png`. 검수 앱 소스 `%TEMP%/sori-stage4-preview.dart`, 빌드 `sori-stage4-preview-web`, 로컬 포트 8138.
- **배포 차단 재현**: `%TEMP%/sori-deployment-order-test.dart`를 `flutter test --no-pub`로 실행. fake ChartVisitGateway.saveDraft를 Completer로 지연시킨 뒤 실제 UI의 마지막 완료/고객 CHART를 누르고 draft를 해제했다. 기대 `['draft', 'completed']`, 실제 `['completed', 'draft']`로 실패했다. 첫 시도는 탭이 화면 밖이어서 무효였고, 390×844 및 ensureVisible 후 pumpAndSettle로 고쳐 두 번째 시도에서 요청 순서 역전을 재현했다. 로그 `%TEMP%/sori-deployment-order.log`.
- 원인: ChartVisitFlowPage._finishVisit가 debounce 타이머 및 이미 진행 중인 _persistDraft를 대기하지 않고 gateway.complete를 호출한다. 별도 화면에서 마지막에 도착한 draft patch가 완료 상태를 덮을 수 있다. 실제 운영 DB 변조는 하지 않았다.
- 다음 Stage 5에서 재현 테스트를 정식 회귀 테스트에 편입하고 저장 직렬화·완료 중 중복 탭 방지·실패 재시도·진행 중 편집/이탈을 검증한다. live 위저드의 사진 토글/완료 화면과 실제 저장 시점도 미해결이므로 운영 완성으로 배포하지 않는다. 원격 push·배포 없음.

### 2026-10-01 Stage 4A

- 사용자 승인에 따라 4A(변환/기본값)·4B(작성 화면)를 각 5파일 이하 커밋으로 분할했다.
- 4A 파일: chart_visit_mock.dart, chart_visit_live.dart, chart_visit_record.dart, test/chart_visit_record_test.dart, 이 체크포인트.
- 새 방문과 빈 방문 복원 시 기본 관리 5단계를 자동 생성하지 않는다. 기존 refillDefaultSteps 인자는 호출 호환을 위해 유지한다. 명시적 샘플 생성자는 미리보기용으로 유지한다.
- 빈 안전정보는 빈 값으로 보존한다. '없음'과 '해당 없음'은 실제 기록이 있을 때만 유지한다. 빈 초안 재개 시 고객 최신 정보로 당시 스냅샷을 덮지 않는다.
- 관리 반응은 기존 care_reactions JSON의 has_reaction을 null(미확인)/false(명시적 없음)/true(반응 있음)로 구분한다. 기존 false는 그대로 읽으며 과거 기록을 추정해 일괄 수정하지 않는다. DB 변경 없음.
- 변경 전 기존 특성화 테스트 2 PASS. 변경 후 저장/복원 테스트 5 PASS, 관련 4개 Dart 분석 No issues found, release 웹 빌드 성공(기존 flutter_tts Wasm dry-run 경고 유지).
- 4A만으로 화면 완료를 의미하지 않는다. 4B에서 두 작성기의 빈 값 표시·미확인 선택·반응 요약·체형 입력을 연결하고 위젯/실제 렌더링을 검증한다. 아직 운영 배포하지 않는다.


### 2026-10-01 Stage 3

- 변경 파일 5개: `lib/features/chart_visit/visit_record_context.dart`, `lib/features/chart_visit/chart_visit_flow_page.dart`, `lib/views/chart_workspace/chart_visit_workspace.dart`, `test/chart_visit_stage_link_test.dart`, 이 체크포인트.
- 홈 CHART에 상담 아코디언을 연결했다. 오늘 문진·지난 방문을 보며 직접 상담 작성→명시적 적용이 가능하다. 문진 변경 시 재확인이 필요하며 실제 관리 내용은 자동 변경하지 않는다.
- 관리에 승인된 상담 판단·원하는 변화를 표시한다. 변화 기록에는 실제 입력된 관리 단계·부위·특이 반응을 표시하고 각 원문으로 돌아가는 버튼을 연결했다. 목표를 실제 관리로 대신 표시하지 않는다.
- 전후 변화의 사전 점수는 오늘 문진에서 읽는다. 사전 점수가 없으면 비교 저장을 막고 미기록으로 안내한다. 기준 변경 시 기존 비교를 자동 덮어쓰지 않고 재확인 표시 및 명시적 편집을 제공한다.
- 변경 대화상자 중 최초 자동저장으로 session이 바뀌는 경우에도 결과 변경만 현재 session에 적용한다. 기존 저장 함수·DB·라우트·B&A·전자동의는 변경하지 않았다.
- 관련 테스트 재실행: `flutter test --no-pub test/chart_visit_stage_link_test.dart test/chart_visit_preview_test.dart test/chart_visit_consult_context_test.dart test/chart_visit_record_test.dart test/chart_workspace_page_test.dart` → **40 PASS**, exit 0. 360×800·1024×900에서 글자 1.3배, 홈 진입·상담 적용·관리·변화·재진입, 기준 누락/변경/취소를 검증했다.
- 관련 4개 Dart 파일 `flutter analyze --no-pub` → **No issues found**. `flutter build web --no-pub` → **Built build/web**. 기존 flutter_tts Wasm dry-run 경고는 일반 JS 빌드를 막지 않았다.
- 실제 브라우저: 로컬 메모리 저장소 검수 앱에서 홈 CHART→고객 선택→상담 직접 작성→적용→관리에서 같은 판단 확인→변화 기록에서 관리 내용·특이 반응 확인→홍조 4→2 저장을 조작했다. 360×800과 1024×900 실제 렌더링에서 내용·고정 하단 행동의 겹침은 관찰되지 않았다. 검수 앱은 실제 `ChartWorkspacePage`와 `AppTheme`를 사용하지만 운영 인증/서버 검증을 대체하지 않는다.
- 캡처: `%TEMP%/sori-stage3-captures/01-care-mobile.png`, `02-result-mobile.png`, `03-result-tablet.png`. 임시 검수 소스와 빌드는 저장소 밖 `%TEMP%/sori-stage3-preview.dart`, `sori-stage3-preview-web`에 보존했다.
- 미확인: 실제 인증 고객 Supabase 저장·새로고침 왕복, 실기기 키보드/카메라, Stage 4~7 배포 조건. 빈 안전정보와 샘플 기본값 문제가 남으므로 이번 중간 단계를 운영 완성으로 배포하지 않는다(최종 기획서 18~19절).
- 전체 테스트: `flutter test --no-pub --reporter expanded` → **805 PASS / 9 FAIL**, exit 1. 실패 테스트명은 앞서 main에서 확인한 동일 9건(피드·홈·boost·golden)이며 이번 CHART 관련 신규 실패는 없다. 전체 통과로 보고하지 않는다. 로그는 `%TEMP%/sori-stage3-full-test.log`.
- 이 묶음은 로컬 커밋으로 보존하며 운영 push·배포는 하지 않는다. 승인된 전체 제품의 완료 조건은 아직 미충족이다.
- 다음 재개: Stage 3 커밋 상태 확인 → Stage 4 관련 모델/변환/표시·호출부 조사 → 5파일 이하 묶음으로 구현. 무관한 시장 문서 및 `supabase/.temp/`를 포함하지 않는다.

### 2026-09-30 Stage 2A

- 이번 작업 파일 5개: `chart_visit_mock.dart`, `chart_visit_live.dart`, `consultation_intake_context.dart`, `test/chart_visit_preview_test.dart`, 이 체크포인트.
- `PastVisit`에 기존 방문 본문·실제 관리명·날짜 존재 여부를 추가로 전달한다. 보호 대상 저장 함수, DB, 라우트는 변경하지 않았다.
- 상담에서 지난 방문의 날짜·실제 단계/부위·특이 반응·다음 계획을 읽고, 당시 목표·변화·홈케어를 펼쳐볼 수 있다. 다른 과거 방문 선택 가능. 목표를 실제 관리로 대체하거나 빈 값을 정상 상태로 만들지 않는다.
- 현재 방문·draft·미래 날짜는 제외하며, 날짜가 없는 기록은 '방문 날짜 미기록'으로 구분한다. 과거 기록이 없다고 신규 고객이라고 추정하지 않는다.
- 과거 방문 선택/펼침 상태는 현재 작성 세션에만 보관한다. 과거 데이터를 오늘 기록에 복사하지 않으며 재진입·화면 크기 변경 시 선택 유지 테스트를 추가했다.
- 테스트: `flutter test --no-pub test/chart_visit_preview_test.dart test/chart_visit_consult_context_test.dart test/chart_visit_record_test.dart test/chart_workspace_page_test.dart` → **19 PASS**. 기존 Supabase 미초기화·샘플 이미지 HTTP400 경고는 재현되나 테스트 실패 없음.
- 분석: `flutter analyze --no-pub lib/features/chart_visit/chart_visit_mock.dart lib/features/chart_visit/chart_visit_live.dart lib/features/chart_visit/consultation_intake_context.dart test/chart_visit_preview_test.dart` → **No issues found**.
- 실제 시각 검수: 로컬 샘플 앱 360×844와 1024×900에서 지난 날짜 선택·상세 펼침·스크롤·하단 진행 버튼을 확인했다. 크기 변경 시 선택 초기화를 발견해 세션 상태로 보완했으며, 재생성 회귀 테스트 통과. 운영 고객 데이터 조회 및 Supabase 왕복은 미실행.
- 웹 빌드: 선택 유지 보완 후 `flutter build web --no-pub` → **Built build/web**, exit 0. 기존 `flutter_tts` Wasm dry-run 경고 3건은 일반 JS 빌드를 막지 않았다.
- DB 변경·커밋·배포 없음. 기존 작업 및 무관한 untracked 파일 보존.
- 다음 작업 **Stage 2B**: 오늘 확인한 '지난 방문 이후 반응'을 참조 방문 ID와 함께 별도 필드로 저장·복원하고 상담 판단과 구분한다. 기존 `visit_intake` JSON의 확장 키를 검토하되 생성/승인 상담요약이나 `owner_note`에 섞지 않는다. 모델·세션·UI·테스트·체크포인트 5파일 묶음으로 진행한다. Stage 2 전체 완료로 취급하지 않는다.

### 2026-09-30 Stage 2B

- `ConsultationIntakeContext`에 선택한 지난 방문 이후의 고객 반응 입력을 추가했다. 반응은 선택한 과거 `customer_charts.id`를 키로 하는 `revisit_feedback`로 현재 방문의 기존 `visit_intake` JSON 안에 저장한다.
- 고객 반응은 상담 요약의 생성·승인 내용과 분리하고, 입력이 바뀌면 상담 적용 상태를 다시 확인하도록 한다. 과거 방문의 관리·반응·다음 계획을 오늘 기록으로 자동 복사하거나 확정하지 않는다.
- `ChartVisitSession` 복원·직렬화와 `ChartVisitRecord` 패치를 연결했다. 새 테이블·컬럼·마이그레이션은 추가하지 않았고 기존 저장 계약을 유지했다.
- 검증: `flutter test --no-pub test/chart_visit_preview_test.dart test/chart_visit_consult_context_test.dart test/chart_visit_record_test.dart test/chart_workspace_page_test.dart` → **19 PASS**. `flutter analyze --no-pub` 관련 파일 → **No issues found**. `flutter build web --no-pub` → **Built build/web**.
- Stage 2 완료 조건: 지난 방문을 선택해 참고하고, 오늘 고객 반응을 별도로 기록·복원하며, 상담 적용 여부를 구분한다. 실제 인증 고객의 Supabase 왕복은 별도 통합 검증이 필요하다.

### 2026-09-30 main 통합·배포 검증

- 로컬 변경을 stash로 보존한 뒤 origin/main을 rebase하고 재적용했다. 충돌 시 최신 main의 시장 인허가 조회 구현을 유지했다. 무관한 untracked 문서와 CLI 임시 파일은 보존하고 커밋에서 제외했다.
- main 통합 후 관련 4개 테스트 파일 **35 PASS** (`+35: All tests passed!`), 관련 7개 Dart 파일 분석 **No issues found**, 웹 빌드 성공. 앞선 진행 메시지의 36개 표기는 정정한다.
- 코드 커밋: `431cb7931fae41a679dfdd0a6a50c6a969b6b872`. Pages Run `36661514066` / #552 build·deploy 성공. 실제 서비스 HTTP 200, HTML sori-build=552 및 flutter_bootstrap.js?v=552 확인.
- 전체 CI: 800 PASS / 9 FAIL. 직전 main `0f60c2b`의 Run `36294430781`에서도 동일 9개 피드·홈·boost·golden 테스트 실패(792 PASS / 9 FAIL). 이번 CHART 추가로 신규 실패한 테스트는 확인되지 않았다. 전체 CI 통과로 보고하지 않는다.
- 운영 /#/chart-visit의 샘플 모드에서 390×844 상담 화면의 문진·지난 방문·고객 반응 입력 UI를 확인했다. 반응 입력 후 CARE 왕복에서 값 유지도 확인했다. 이 경로는 서버에 저장하지 않는 샘플이며 실제 인증 고객 DB 왕복 검증을 대체하지 않는다.
- 다음 구현: 최종 제품 기획서 Stage 3(상담→관리→변화 연결). Stage 3~7은 아직 완료되지 않았다.

- 초기 체크포인트 생성. 코드 완료나 배포 완료를 의미하지 않는다.
- 2026-09-29: 구현/검증 에이전트가 사용량 한도로 중단. flow·문진 context 위젯·테스트 2개 파일이 작업 중인 상태로 보존됨. 검증 완료로 취급하지 않는다.
- 2026-09-30 재개: 기존 diff를 유지하고 단계1 구현·검증을 완료했다. 상담 승인 이후 문진 변경 시 `consultApplied`를 해제하고, 같은 세션에서는 재확인 문구를 표시하며, 재진입 후에도 `아직 차트에 적용되지 않았습니다.` 상태가 유지된다.
- 로컬 시각 검수: `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8136 --no-pub`로 실행한 화면에서 390×844 및 1024×900 렌더링을 확인했다. 초기 DDC 로딩 후 정상 표시되었고 콘솔 오류 없이 상담 원문·직접 상담·적용 CTA를 확인했다.
