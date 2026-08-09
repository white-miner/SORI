import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/env.dart';
import 'data/repository_factory.dart';
import 'services/sori_store.dart';
import 'services/supabase_client.dart';
import 'views/my_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Hash routing 기본값 유지 → GitHub Pages `/#/review?token=...` 404 방지
  runApp(const MyApp());
}
