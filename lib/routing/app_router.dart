import 'package:flutter/material.dart';

/// 레거시 경로 헬퍼 — 실제 네비게이션은 [createSoriGoRouter] (go_router).
class AppRouter {
  static const String home = '/';
  static const String login = '/login';
  static const String app = '/app';
  static const String admin = '/admin'; // 하위 호환 → /app
  static const String review = '/review';
  static const String careReport = '/care-report';

  /// 차트 작성 SSOT 경로 — `/#/chart/create?customerId=`
  static const String chartCreate = '/chart/create';
  static const String chart = '/chart';

  /// 브라우저 해시/쿼리에서 초기 라우트 복원 (F5 대응).
  static String resolveInitialRoute() {
    final frag = Uri.base.fragment.trim();
    if (frag.isNotEmpty) {
      final normalized = frag.startsWith('/') ? frag : '/$frag';
      return normalized;
    }
    final path = _normalizePath(Uri.base.path);
    if (path != home && path.isNotEmpty) {
      final q = Uri.base.query;
      return q.isEmpty ? path : '$path?$q';
    }
    return home;
  }

  /// `/chart/create?customerId=...&chartId=...&quick=1`
  static String buildChartCreateLocation({
    required String customerId,
    String? chartId,
    bool forceQuickChart = false,
  }) {
    final q = <String, String>{
      'customerId': customerId.trim(),
      if (chartId != null && chartId.trim().isNotEmpty)
        'chartId': chartId.trim(),
      if (forceQuickChart) 'quick': '1',
    };
    return Uri(path: chartCreate, queryParameters: q).toString();
  }

  static String? chartCustomerIdFromUri(Uri uri) {
    final query = uri.queryParameters;
    final fromQuery = (query['customerId'] ?? query['customer_id'] ?? '').trim();
    if (fromQuery.isNotEmpty) return Uri.decodeComponent(fromQuery);

    final path = _normalizePath(uri.path);
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 &&
        segments[0] == 'chart' &&
        segments[1] != 'create') {
      return Uri.decodeComponent(segments[1]);
    }
    return null;
  }

  /// `Uri.base` 해시 프래그먼트까지 포함해 customerId 추출.
  static String? chartCustomerIdFromBrowser() {
    final frag = Uri.base.fragment.trim();
    if (frag.isNotEmpty) {
      final normalized = frag.startsWith('/') ? frag : '/$frag';
      return chartCustomerIdFromUri(Uri.parse(normalized));
    }
    return chartCustomerIdFromUri(Uri.base);
  }

  static String? chartCustomerIdFromSettings(RouteSettings? settings) {
    final name = settings?.name;
    if (name == null || name.isEmpty) return null;
    return chartCustomerIdFromUri(Uri.parse(name));
  }

  static bool pageIsChartCreate(Map<String, String> query) =>
      query['page'] == 'chart' || query['page'] == 'chart-create';

  static String _normalizePath(String path) {
    var p = path.trim();
    if (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    if (p.toLowerCase().startsWith('/sori/')) {
      p = p.substring(5);
    } else if (p.toLowerCase() == '/sori') {
      p = '/';
    }
    if (!p.startsWith('/')) {
      p = '/$p';
    }
    return p;
  }
}
