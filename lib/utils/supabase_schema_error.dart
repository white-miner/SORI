/// PostgREST 스키마 캐시 관련 오류 판별.
///
/// 마이그레이션이 아직 적용되지 않았거나 캐시가 갱신되지 않은 상태는
/// 네트워크 장애 같은 일시적 실패와 성격이 다르다. 재시도해도 소용이 없고,
/// 클라이언트는 해당 기능을 로컬 폴백으로 낮춰서 계속 동작해야 한다.
library;

/// 스키마 미적용/캐시 미갱신으로 인한 오류인지 판별한다.
///
/// - `PGRST205` — 테이블을 스키마 캐시에서 찾지 못함
/// - `PGRST202` — 함수(RPC)를 스키마 캐시에서 찾지 못함
/// - `42P01` / `42883` — Postgres의 undefined_table / undefined_function
bool isMissingSchemaError(Object error) {
  final text = error.toString();
  return text.contains('PGRST205') ||
      text.contains('PGRST202') ||
      text.contains('42P01') ||
      text.contains('42883') ||
      text.contains('schema cache');
}
