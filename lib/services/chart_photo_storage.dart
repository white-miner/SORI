import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// 차트 Before/After 사진 → Supabase Storage `chart_photos` (WebP only).
abstract final class ChartPhotoStorage {
  static const bucket = 'chart_photos';

  /// WebP 바이트 업로드. 실패·미초기화 시 null.
  static Future<String?> uploadWebp({
    required Uint8List bytes,
    required String shopId,
    required String customerId,
    required String kind, // before | after
  }) async {
    if (bytes.isEmpty) return null;
    final client = SoriSupabase.clientOrNull;
    if (client == null) return null;

    final safeShop = _safeSegment(shopId, 'unknown-shop');
    final safeCustomer = _safeSegment(customerId, 'unknown-customer');
    final safeKind = kind.trim().isEmpty ? 'photo' : kind.trim();
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = _shortId();
    final path = '$safeShop/$safeCustomer/${id}_${stamp}_$safeKind.webp';

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/webp',
              upsert: true,
            ),
          );
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e, st) {
      debugPrint('ChartPhotoStorage.uploadWebp failed: $e\n$st');
      return null;
    }
  }

  static String _safeSegment(String raw, String fallback) {
    final t = raw.trim();
    if (t.isEmpty) return fallback;
    return t.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  static String _shortId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
