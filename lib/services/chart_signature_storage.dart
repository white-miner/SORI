import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// 차트 전자 서명 PNG → Supabase Storage 업로드.
abstract final class ChartSignatureStorage {
  static const bucket = 'chart-signatures';

  /// 업로드 실패·미초기화 시 null 반환 (차트 저장은 계속 진행).
  static Future<String?> uploadPng({
    required Uint8List bytes,
    required String shopId,
    required String customerId,
  }) async {
    if (bytes.isEmpty) return null;
    final client = SoriSupabase.clientOrNull;
    if (client == null) return null;

    final safeShop = shopId.trim().isEmpty ? 'unknown-shop' : shopId.trim();
    final safeCustomer =
        customerId.trim().isEmpty ? 'unknown-customer' : customerId.trim();
    final path =
        '$safeShop/$safeCustomer/${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e, st) {
      debugPrint('ChartSignatureStorage.uploadPng failed: $e\n$st');
      return null;
    }
  }
}
