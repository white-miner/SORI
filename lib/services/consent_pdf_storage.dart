import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// 전자 동의서 PDF → `consent_pdfs` Public Storage.
abstract final class ConsentPdfStorage {
  static const bucket = 'consent_pdfs';

  static Future<String?> uploadPdf({
    required Uint8List bytes,
    required String shopId,
    required String customerId,
    required String chartId,
  }) async {
    if (bytes.isEmpty) return null;
    final client = SoriSupabase.clientOrNull;
    if (client == null) return null;

    final safeShop = shopId.trim().isEmpty ? 'unknown-shop' : shopId.trim();
    final safeCustomer =
        customerId.trim().isEmpty ? 'unknown-customer' : customerId.trim();
    final safeChart = chartId.trim().isEmpty ? 'chart' : chartId.trim();
    final path =
        '$safeShop/$safeCustomer/${safeChart}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e, st) {
      debugPrint('ConsentPdfStorage.uploadPdf failed: $e\n$st');
      return null;
    }
  }
}
