import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// 차트 전자 서명 PNG → Supabase Storage 업로드.
abstract final class ChartSignatureStorage {
  static const bucket = 'chart-signatures';

  /// PNG → data URL (업로드 실패·웹 PDF 재생성용 폴백).
  static String toDataUrl(Uint8List bytes) =>
      'data:image/png;base64,${base64Encode(bytes)}';

  /// 업로드 성공 시 public URL, 실패 시 data URL.
  static Future<String> uploadPngOrDataUrl({
    required Uint8List bytes,
    required String shopId,
    required String customerId,
  }) async {
    final uploaded = await uploadPng(
      bytes: bytes,
      shopId: shopId,
      customerId: customerId,
    );
    if (uploaded != null && uploaded.trim().isNotEmpty) return uploaded.trim();
    return toDataUrl(bytes);
  }

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
