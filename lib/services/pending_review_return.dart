/// 계산대 QR → 카카오 OAuth 후 `/#/review?token=` 복귀용 토큰 보존.
class PendingReviewReturn {
  PendingReviewReturn._();

  static const queryKey = 'sori_review_token';

  static String? _token;

  static void save(String token) {
    final t = token.trim();
    _token = t.isEmpty ? null : t;
  }

  /// 브라우저 쿼리(`?sori_review_token=`)와 메모리 값을 합쳐 꺼낸다.
  static String? peek() {
    final fromQuery = Uri.base.queryParameters[queryKey]?.trim() ?? '';
    if (fromQuery.isNotEmpty) {
      _token = fromQuery;
      return fromQuery;
    }
    final mem = _token?.trim() ?? '';
    return mem.isEmpty ? null : mem;
  }

  static String? take() {
    final t = peek();
    _token = null;
    return t;
  }

  static String reviewLocation(String token) {
    final encoded = Uri.encodeQueryComponent(token.trim());
    return '/review?token=$encoded';
  }
}
