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
import 'widgets/app_scroll_behavior.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // GitHub Pages `/#/...` 딥링크 유지
    setUrlStrategy(HashUrlStrategy());

    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformDispatcher.onError: $error\n$stack');
      return true;
    };
    ErrorWidget.builder = (details) {
      debugPrint('ErrorWidget swallowed: ${details.exception}');
      final raw = details.exceptionAsString();
      if (raw.toLowerCase().contains('oauth state') ||
          raw.toLowerCase().contains('code verifier') ||
          raw.toLowerCase().contains('pkce')) {
        return const ColoredBox(
          color: Color(0xFF0A0A0C),
          child: SizedBox.expand(),
        );
      }
      return const ColoredBox(
        color: Color(0xFF0A0A0C),
        child: SizedBox.expand(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '일시적인 표시 오류가 있었습니다.\n이 화면을 닫고 다시 시도해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFA1A1AA),
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

    // 시스템 UI만 동기적으로 맞춘 뒤 즉시 첫 프레임.
    // Web에서는 edgeToEdge가 viewPadding/터치 좌표계를 어긋나게 할 수 있어 제외.
    if (!kIsWeb) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    }
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    );

    // Seed 스냅샷으로 UI를 먼저 띄우고, 네트워크·Auth는 백그라운드.
    final store = SoriStore.instance;
    store.setAuthHydrating(true); // 세션 복구 전 로그인 깜빡임 방지
    runApp(
      const ScrollConfiguration(
        behavior: SoriScrollBehavior(),
        child: MyApp(),
      ),
    );
    unawaited(_warmStart(store));
  }, (error, stack) {
    debugPrint('runZonedGuarded: $error\n$stack');
  });
}

/// Env → Supabase → bootstrap → Auth. UI는 이미 표시된 상태.
Future<void> _warmStart(SoriStore store) async {
  try {
    await Env.load();
    await SoriSupabase.initialize();
    store.bindRepository(createSoriRepository());
    await Future.wait<void>([
      store.bootstrap(),
      SoriAuthCoordinator.instance.start(),
    ]);
  } catch (e, st) {
    debugPrint('warmStart failed: $e\n$st');
  } finally {
    // coordinator hydrate가 이미 false로 내렸을 수 있음 — 미로그인 콜드스타트 정리
    if (store.authHydrating && store.session == null) {
      store.setAuthHydrating(false);
    }
  }
}
