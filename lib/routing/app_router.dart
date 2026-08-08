import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../views/customer_review_page.dart';
import '../views/main_shell_page.dart';
import '../views/my_app.dart';

class AppRouter {
  static const String admin = '/';
  static const String adminAlias = '/admin';
  static const String review = '/review';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final rawName = settings.name ?? admin;
    final uri = Uri.parse(rawName);
    final path = _normalizePath(uri.path);

    if (path == review) {
      final token = uri.queryParameters['token'] ??
          (settings.arguments is String ? settings.arguments as String : '');
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => CustomerReviewPage(
          store: SoriStore.instance,
          token: token,
        ),
      );
    }

    if (path == admin || path == adminAlias || path.isEmpty) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const MainShellPage(),
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
              const Text(
                '페이지를 찾을 수 없습니다',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRouter.admin,
                    (_) => false,
                  );
                },
                child: const Text(
                  '원장용 어드민으로',
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
    // GitHub Pages base `/SORI` may appear in some deep-link cases.
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
