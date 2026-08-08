import 'package:flutter/foundation.dart';

import '../services/supabase_client.dart';
import 'memory_sori_repository.dart';
import 'sori_repository.dart';

/// Supabase 연동 stub — CRUD는 다음 단계에서 구현.
/// 키가 없거나 로드 실패 시 Memory 시드로 fallback.
class SupabaseSoriRepository implements SoriRepository {
  SupabaseSoriRepository({this.fallbackToMemory = true});

  final bool fallbackToMemory;

  @override
  bool get isRemote => true;

  @override
  Future<SoriSnapshot> loadInitialData() async {
    final client = SoriSupabase.clientOrNull;
    if (client == null) {
      debugPrint('SupabaseSoriRepository: client missing — memory fallback.');
      return MemorySoriRepository.createSeedSnapshot();
    }

    try {
      // TODO: shops / customers / customer_charts / customer_reviews select
      await client.from('shops').select('id').limit(1);
      debugPrint(
        'SupabaseSoriRepository: connected — remote CRUD not yet wired; '
        'using memory seed until phase-2.',
      );
      if (fallbackToMemory) {
        return MemorySoriRepository.createSeedSnapshot();
      }
      return SoriSnapshot(
        shop: MemorySoriRepository.createSeedSnapshot().shop,
        customers: const [],
        charts: const [],
        reviews: const [],
        aiReplies: const [],
        gallerySlides: const [],
      );
    } catch (e, st) {
      debugPrint('SupabaseSoriRepository load failed: $e\n$st');
      return MemorySoriRepository.createSeedSnapshot();
    }
  }
}
