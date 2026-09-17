import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../data/repository_factory.dart';
import 'sori_auth_coordinator.dart';
import 'sori_store.dart';
import 'supabase_client.dart';

/// Env → Supabase → 저장소. 실패를 샘플 성공으로 숨기지 않는다.
abstract final class AppBootstrap {
  static Future<void> connect(SoriStore store) async {
    try {
      await Env.load();
      if (!Env.hasSupabaseConfig) {
        store.bindRepository(createSoriRepository());
        store.markSampleBackend(
          '서버 설정이 없습니다. 지금 보이는 내용은 샘플이며 이 기기에 저장되지 않습니다.',
        );
        return;
      }
      final ready = await SoriSupabase.initialize();
      if (!ready) {
        store.bindRepository(createSoriRepository());
        store.markSampleBackend(
          '서버에 연결하지 못했습니다. 샘플이 표시 중이며 저장되지 않습니다.',
        );
        return;
      }
      store.bindRepository(createSoriRepository());
      store.clearSampleBackend();
      await store.bootstrap();
      await SoriAuthCoordinator.instance.start();
    } catch (e, st) {
      debugPrint('AppBootstrap.connect failed: $e\n$st');
      store.bindRepository(createSoriRepository());
      store.markSampleBackend(
        '서버에 연결하지 못했습니다. 샘플이 표시 중이며 저장되지 않습니다.',
      );
    } finally {
      if (store.authHydrating && store.session == null) {
        store.setAuthHydrating(false);
      }
    }
  }
}
