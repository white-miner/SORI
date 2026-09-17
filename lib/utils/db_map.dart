/// Supabase/PostgREST 행 맵 안전 파서.
abstract final class DbMap {
  static String asText(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String? asTextOrNull(dynamic value) {
    final text = asText(value);
    return text.isEmpty ? null : text;
  }

  /// Insert/Upsert용: 빈 문자열·공백을 JSON null로 정규화.
  static Object? nullIfBlank(String? value) => asTextOrNull(value);

  /// jsonb string[] 컬럼용 — null/빈 항목 제거, 절대 null 리스트 금지.
  static List<String> sanitizeStringList(Iterable<String>? values) {
    if (values == null) return const [];
    return values
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// TEXT 컬럼용 칩 병합 ("홍조, 얇은 피부").
  static String joinChips(Iterable<String>? values) =>
      sanitizeStringList(values).join(', ');

  static int asInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static bool asBool(dynamic value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value == null) return fallback;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }

  static DateTime? asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static DateTime asDateTimeOrNow(dynamic value) =>
      asDateTime(value) ?? DateTime.now();

  static List<String> asStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    final text = value.toString().trim();
    if (text.isEmpty) return const [];
    // TEXT에 쉼표 조인으로 저장된 레거시 값 복원
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
