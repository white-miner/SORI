import 'package:flutter/material.dart';

import '../services/sori_store.dart';
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
