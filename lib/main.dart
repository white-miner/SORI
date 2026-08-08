import 'package:flutter/material.dart';

import 'config/env.dart';
import 'data/repository_factory.dart';
import 'services/sori_store.dart';
import 'services/supabase_client.dart';
import 'views/my_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  await SoriSupabase.initialize();

  final store = SoriStore.instance;
  store.bindRepository(createSoriRepository());
  await store.bootstrap();

  // Hash routing 기본값 유지 → GitHub Pages `/#/review?token=...` 404 방지
  runApp(const MyApp());
}
