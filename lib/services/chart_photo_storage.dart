import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// 미연결 staging 사진 삭제 결과. 메타 제거는 Storage 성공 뒤에만 한다.
class StagingPhotoDiscardResult {
  const StagingPhotoDiscardResult({
    required this.discarded,
    this.storageRemoveCount = 0,
    this.blockedByChartRef = false,
    this.storageFailed = false,
  });

  final bool discarded;
  final int storageRemoveCount;
  final bool blockedByChartRef;
  final bool storageFailed;
}

/// 차트 Before/After 사진 → Supabase Storage `chart_photos` (WebP only).
abstract final class ChartPhotoStorage {
  static const bucket = 'chart_photos';

  static const _publicMarker = '/object/public/$bucket/';

  /// Tests replace Storage remove. `null` restores the real client call.
  @visibleForTesting
  static Future<bool> Function(String path)? debugRemoveHandler;

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

  /// Public URL 또는 object key → `chart_photos` 객체 경로.
  static String? objectPathFromPublicUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.startsWith('data:')) return null;

    final markerAt = value.indexOf(_publicMarker);
    if (markerAt >= 0) {
      var path = value.substring(markerAt + _publicMarker.length);
      path = path.split('?').first.split('#').first;
      path = Uri.decodeFull(path);
      return path.isEmpty ? null : path;
    }

    if (value.contains('://')) return null;
    final path = value.replaceFirst(RegExp(r'^/+'), '');
    return path.isEmpty ? null : path;
  }

  /// Staging 원본 삭제. 경로를 못 읽거나 클라이언트가 없으면 false.
  /// [uploadWebp] 시그니처는 변경하지 않는다.
  static Future<bool> removeByPublicUrl(String url) async {
    final path = objectPathFromPublicUrl(url);
    if (path == null || path.isEmpty) return false;

    final handler = debugRemoveHandler;
    if (handler != null) {
      try {
        return await handler(path);
      } catch (e, st) {
        debugPrint('ChartPhotoStorage.debugRemoveHandler failed: $e\n$st');
        return false;
      }
    }

    final client = SoriSupabase.clientOrNull;
    if (client == null) return false;

    try {
      await client.storage.from(bucket).remove([path]);
      return true;
    } catch (e, st) {
      debugPrint('ChartPhotoStorage.removeByPublicUrl failed: $e\n$st');
      return false;
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
