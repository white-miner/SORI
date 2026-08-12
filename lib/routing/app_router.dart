import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../views/admin_chart_writer_page.dart';
import '../views/app_shell_page.dart';
import '../views/care_report_page.dart';
import '../views/customer_review_page.dart';
import '../views/entry_home_page.dart';
import '../views/my_app.dart';
import '../views/splash_page.dart';

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
    // fragment 없는 path 기반 배포 호환
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
    // /chart/{customerId}  (create 제외)
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

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final rawName = settings.name ?? home;
    final uri = Uri.parse(rawName);
    final path = _normalizePath(uri.path);
    final query = Map<String, String>.from(uri.queryParameters);

    final page = query['page'];
    final tokenFromQuery = query['token'] ?? '';

    // 고객 딥링크 — 어드민 셸 완전 미마운트
    if (path == review || page == 'review') {
      final token = tokenFromQuery.isNotEmpty
          ? tokenFromQuery
          : (settings.arguments is String ? settings.arguments as String : '');
      return _fadeRoute(
        settings: settings,
        child: CustomerReviewPage(
          store: SoriStore.instance,
          token: token,
        ),
      );
    }

    // 카카오 알림톡 랜딩 — `/#/care-report/:chartId`
    final careChartId = _careReportChartId(path, query, settings.arguments);
    if (careChartId != null) {
      return _fadeRoute(
        settings: settings,
        child: CareReportPage(
          store: SoriStore.instance,
          chartId: careChartId,
        ),
      );
    }

    // 차트 작성 — `/#/chart/create?customerId=` 또는 `/#/chart/{customerId}`
    final chartRoute = _parseChartCreate(path, query, settings.arguments);
    if (chartRoute != null) {
      final store = SoriStore.instance;
      final customer = store.findCustomer(chartRoute.customerId);
      final existing = chartRoute.chartId == null
          ? null
          : store.findChartById(chartRoute.chartId!);
      return _fadeRoute(
        settings: settings,
        child: AdminChartWriterPage(
          store: store,
          customerId: chartRoute.customerId,
          customer: customer,
          existingChart: existing,
          forceQuickChart: chartRoute.forceQuickChart,
        ),
      );
    }

    if (path == app || path == admin) {
      return _fadeRoute(
        settings: settings,
        child: const AppShellPage(),
      );
    }

    if (path == login) {
      return _fadeRoute(
        settings: settings,
        child: EntryHomePage(
          initialToken: page == 'review' ? null : tokenFromQuery,
        ),
      );
    }

    if (path == home || path.isEmpty) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => SplashPage(
          initialToken: page == 'review' ? null : tokenFromQuery,
        ),
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => Scaffold(
        backgroundColor: const Color(0xFFF8F7FC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('페이지를 찾을 수 없습니다'),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRouter.home,
                    (_) => false,
                  );
                },
                child: const Text(
                  '홈으로',
                  style: TextStyle(color: MyApp.soriPurple),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ({String customerId, String? chartId, bool forceQuickChart})?
      _parseChartCreate(
    String path,
    Map<String, String> query,
    Object? arguments,
  ) {
    String? customerId;
    String? chartId = (query['chartId'] ?? query['chart_id'] ?? '').trim();
    if (chartId.isEmpty) chartId = null;
    final quick = query['quick'] == '1' ||
        query['quick'] == 'true' ||
        query['forceQuickChart'] == '1';

    if (path == chartCreate || pageIsChartCreate(query)) {
      customerId =
          (query['customerId'] ?? query['customer_id'] ?? '').trim();
    } else if (path.startsWith('$chart/')) {
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2 &&
          segments[0] == 'chart' &&
          segments[1] != 'create') {
        customerId = Uri.decodeComponent(segments[1]);
      }
    }

    if (customerId == null || customerId.isEmpty) {
      if (arguments is Map) {
        customerId = '${arguments['customerId'] ?? ''}'.trim();
        final argChart = '${arguments['chartId'] ?? ''}'.trim();
        if (argChart.isNotEmpty) chartId = argChart;
      } else if (arguments is String && arguments.trim().isNotEmpty) {
        customerId = arguments.trim();
      }
    }

    if (customerId == null || customerId.isEmpty) return null;
    return (
      customerId: Uri.decodeComponent(customerId),
      chartId: chartId,
      forceQuickChart: quick,
    );
  }

  static bool pageIsChartCreate(Map<String, String> query) =>
      query['page'] == 'chart' || query['page'] == 'chart-create';

  static String? _careReportChartId(
    String path,
    Map<String, String> query,
    Object? arguments,
  ) {
    if (query['page'] == 'care-report') {
      final fromQuery = (query['chartId'] ?? query['id'] ?? '').trim();
      if (fromQuery.isNotEmpty) return Uri.decodeComponent(fromQuery);
    }
    if (path == careReport || path.startsWith('$careReport/')) {
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2 && segments[0] == 'care-report') {
        return Uri.decodeComponent(segments[1]);
      }
      if (arguments is String && arguments.trim().isNotEmpty) {
        return arguments.trim();
      }
    }
    return null;
  }

  static PageRouteBuilder<void> _fadeRoute({
    required RouteSettings settings,
    required Widget child,
  }) {
    return PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 420),
    );
  }

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
