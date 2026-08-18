import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'config/env.dart';
import 'data/repository_factory.dart';
import 'services/sori_auth_coordinator.dart';
import 'services/sori_store.dart';
import 'services/supabase_client.dart';
import 'views/my_app.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // GitHub Pages `/#/...` 딥링크 유지
    setUrlStrategy(HashUrlStrategy());

    // 전역 Error Boundary — 백그라운드/위젯 예외가 빨간 Exception 전체화면으로
    // 차트 작성 State 를 날리지 않도록 흡수한다.
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformDispatcher.onError: $error\n$stack');
      return true; // 처리됨 — 앱 크래시/전역 빨간 화면 방지
    };
    ErrorWidget.builder = (details) {
      debugPrint('ErrorWidget swallowed: ${details.exception}');
      return const ColoredBox(
        color: Color(0xFFF8F9FA),
        child: SizedBox.expand(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '일시적인 표시 오류가 있었습니다.\n이 화면을 닫고 다시 시도해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF636E72),
                  fontSize: 14,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    };

    // PWA/모바일 풀스크린 Touch UX — 노치·홈 인디케이터는 SafeArea로 처리
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
    );
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await Env.load();
    await SoriSupabase.initialize();

    final store = SoriStore.instance;
    store.bindRepository(createSoriRepository());
    await store.bootstrap();
    await SoriAuthCoordinator.instance.start();

    // Hash routing 기본값 유지 → GitHub Pages `/#/review?token=...` 404 방지
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('runZonedGuarded: $error\n$stack');
  });
}
