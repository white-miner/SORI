import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// 샵 프로필 아바타 → Supabase Storage `shop_profiles`.
abstract final class ShopProfileStorage {
  static const bucket = 'shop_profiles';

  /// JPEG/PNG/WebP 바이트 업로드. 실패·미초기화 시 null.
  static Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String shopId,
    String contentType = 'image/jpeg',
    String extension = 'jpg',
  }) async {
    if (bytes.isEmpty) return null;
    final client = SoriSupabase.clientOrNull;
    if (client == null) return null;

    final safeShop = _safeSegment(shopId, 'unknown-shop');
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = _shortId();
    final ext = extension.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final safeExt = ext.isEmpty ? 'jpg' : ext;
    final path = '$safeShop/avatar_${id}_$stamp.$safeExt';

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e, st) {
      debugPrint('ShopProfileStorage.uploadAvatar failed: $e\n$st');
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
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
