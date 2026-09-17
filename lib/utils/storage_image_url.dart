import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../services/chart_photo_storage.dart';
import '../services/supabase_client.dart';

/// Supabase Storage / DB에 저장된 이미지 경로를 HTTPS 절대 URL로 정규화.
abstract final class StorageImageUrl {
  /// null·빈 문자열 → null. 상대 경로·object path → public HTTPS.
  static String? resolve(String? raw, {String bucket = ChartPhotoStorage.bucket}) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    if (value.startsWith('data:')) return value;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    // `/storage/v1/object/public/...` 또는 `storage/v1/...`
    final storagePath = value.startsWith('/') ? value : '/$value';
    if (storagePath.contains('/storage/v1/')) {
      final base = Env.supabaseUrl;
      if (base.isEmpty) {
        debugPrint('StorageImageUrl: SUPABASE_URL missing for $storagePath');
        return null;
      }
      return '$base$storagePath';
    }

    // object key만 있는 경우: shopId/.../file.webp
    final path = value.replaceFirst(RegExp(r'^/+'), '');
    final client = SoriSupabase.clientOrNull;
    if (client != null) {
      try {
        return client.storage.from(bucket).getPublicUrl(path);
      } catch (e) {
        debugPrint('StorageImageUrl.getPublicUrl failed: $e path=$path');
      }
    }

    final base = Env.supabaseUrl;
    if (base.isEmpty) {
      debugPrint('StorageImageUrl: cannot resolve relative path=$path');
      return null;
    }
    return '$base/storage/v1/object/public/$bucket/$path';
  }

  static bool isNetworkUrl(String? url) {
    final u = url?.trim() ?? '';
    return u.startsWith('http://') || u.startsWith('https://');
  }
}
