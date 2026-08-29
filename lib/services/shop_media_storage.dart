import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// 샵 갤러리·소식 이미지 → `shop_profiles` 버킷 하위 경로.
abstract final class ShopMediaStorage {
  static const bucket = 'shop_profiles';

  static Future<String?> uploadGalleryImage({
    required Uint8List bytes,
    required String shopId,
  }) =>
      _upload(
        bytes: bytes,
        shopId: shopId,
        folder: 'gallery',
      );

  static Future<String?> uploadSeminarImage({
    required Uint8List bytes,
    required String shopId,
  }) =>
      _upload(
        bytes: bytes,
        shopId: shopId,
        folder: 'seminars',
      );

  static Future<String?> uploadPostImage({
    required Uint8List bytes,
    required String shopId,
  }) =>
      _upload(
        bytes: bytes,
        shopId: shopId,
        folder: 'posts',
      );

  static Future<String?> uploadEquipmentImage({
    required Uint8List bytes,
    required String shopId,
  }) =>
      _upload(
        bytes: bytes,
        shopId: shopId,
        folder: 'equipment',
      );

  static Future<String?> _upload({
    required Uint8List bytes,
    required String shopId,
    required String folder,
  }) async {
    if (bytes.isEmpty) return null;
    final client = SoriSupabase.clientOrNull;
    if (client == null) return null;

    final safeShop = _safeSegment(shopId, 'unknown-shop');
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = _shortId();
    final path = '$safeShop/$folder/${id}_$stamp.jpg';

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e, st) {
      debugPrint('ShopMediaStorage.$folder failed: $e\n$st');
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
