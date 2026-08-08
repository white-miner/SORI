import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../views/customer_review_page.dart';
import '../views/entry_home_page.dart';
import '../views/main_shell_page.dart';
import '../views/my_app.dart';

class AppRouter {
  static const String home = '/';
  static const String admin = '/admin';
  static const String review = '/review';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final rawName = settings.name ?? home;
    final uri = Uri.parse(rawName);
    final path = _normalizePath(uri.path);
    final query = Map<String, String>.from(uri.queryParameters);

    // Query-parameter fallback: /?page=review&token=...
    final page = query['page'];
    final tokenFromQuery = query['token'] ?? '';

    if (path == review || page == 'review') {
      final token = tokenFromQuery.isNotEmpty
          ? tokenFromQuery
          : (settings.arguments is String ? settings.arguments as String : '');
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => CustomerReviewPage(
          store: SoriStore.instance,
          token: token,
        ),
      );
    }

    if (path == admin) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const MainShellPage(),
      );
    }

    if (path == home || path.isEmpty) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => EntryHomePage(
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
