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
- 사용자 승인: 최종 계획 실행. 범위 내 개발 진행 가능. 이번 실행에서 커밋·운영 배포는 별도 수행하지 않는다.
- 단계별 코드/테스트 변경을 5파일 이하로 분할한다. 기준 문서 자체의 중단/승인 지점을 존중한다.

## 단계 상태

| 단계 | 상태 | 범위 |
|---|---|---|
| 1 | 완료 | 문진→상담 근거 표시, 실제 고객의 직접 상담 입력, 문진 변경 후 재승인 |
| 2 | 완료 | 지난 방문 맥락 확인과 오늘 확인한 재방문 반응 작성·복원 |
| 3 | 대기 | 상담→관리→변화 연결 |
| 4 | 대기 | 미확인·샘플 기본값·피부/체형 공통 표현 |
| 5 | 대기 | 저장 순서·완료·재조회·복구 |
| 6 | 대기 | 실제 촬영·부위별 사진·리포트 |
| 7 | 대기 | 최소 기록 동선·복사·선택 상세 |
| 후속 | 별도 승인 | 음성 공급자·정책, 체형 실측 저장 확장 |

## 현재 작업: 단계 2 완료

- 수정 범위: `lib/features/chart_visit/chart_visit_flow_page.dart`, `lib/features/chart_visit/consultation_intake_context.dart`, `test/chart_visit_preview_test.dart`, `test/chart_visit_consult_context_test.dart`. 모델/DB/기존 저장 함수 변경 금지.
- 변경 전 기준: `flutter test test/chart_visit_preview_test.dart test/chart_visit_record_test.dart test/chart_workspace_page_test.dart` → 11개 PASS. Supabase 미초기화 및 샘플 사진 HTTP400 로그는 있었으나 테스트 실패 없음.
- 완료 조건: 같은 session의 문진이 상담에 보임, 직접 기록→적용, 이전 단계 편집 후 값 유지, 360px/넓은 화면 레이아웃 검증.
- 완료 결과: 상담 화면 상단에 이번 방문 문진 원문과 안전정보 확인 상태를 표시하고, live 모드에서는 샘플 녹음 대신 직접 상담 작성을 제공한다. 상담 승인 후 문진·안전정보가 바뀌면 승인을 해제하고 재적용을 요구한다.
- 검증: `flutter analyze --no-pub lib/features/chart_visit/chart_visit_flow_page.dart lib/features/chart_visit/consultation_intake_context.dart test/chart_visit_consult_context_test.dart test/chart_visit_preview_test.dart` → No issues found. 관련 4개 테스트 파일 → 15개 PASS.
- 실제 렌더링: 로컬 `http://127.0.0.1:8136/#/chart-visit`에서 390×844와 1024×900을 확인했다. 문진 원문, 직접 상담 작성, 적용 전 상태, 하단 `차트에 적용` CTA가 표시되며 넓은 화면도 좌측 고객·단계/우측 작성 영역으로 유지된다.
- 웹 빌드: `flutter build web --no-pub` → `build/web` 생성 성공. 기존 `flutter_tts` WebAssembly dry-run 경고 3건은 의존성 코드에서 발생했으며 일반 Web 빌드를 막지 않았다.
- 제한: 실제 인증 고객과 Supabase 저장 왕복은 이번 단계 범위가 아니며 검증하지 않았다. 샘플 모드의 `샘플 상담 시작`은 기존 미리보기용으로만 남아 있다.
- 커밋·배포: 이 체크포인트 갱신 후 실행한다.

## 검증 및 변경 이력

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

- 초기 체크포인트 생성. 코드 완료나 배포 완료를 의미하지 않는다.
- 2026-09-29: 구현/검증 에이전트가 사용량 한도로 중단. flow·문진 context 위젯·테스트 2개 파일이 작업 중인 상태로 보존됨. 검증 완료로 취급하지 않는다.
- 2026-09-30 재개: 기존 diff를 유지하고 단계1 구현·검증을 완료했다. 상담 승인 이후 문진 변경 시 `consultApplied`를 해제하고, 같은 세션에서는 재확인 문구를 표시하며, 재진입 후에도 `아직 차트에 적용되지 않았습니다.` 상태가 유지된다.
- 로컬 시각 검수: `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8136 --no-pub`로 실행한 화면에서 390×844 및 1024×900 렌더링을 확인했다. 초기 DDC 로딩 후 정상 표시되었고 콘솔 오류 없이 상담 원문·직접 상담·적용 CTA를 확인했다.
