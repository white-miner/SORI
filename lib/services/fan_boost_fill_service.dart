import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'supabase_client.dart';

/// Post-purchase OpenAI upgrade for Boost & Fill (when pg_net unavailable).
abstract final class FanBoostFillService {
  static Future<void> tryEdgeUpgrade({
    required String chartId,
    String jobId = '',
  }) async {
    final client = SoriSupabase.clientOrNull;
  final cid = chartId.trim();
  final jid = jobId.trim();
    if (client == null || cid.isEmpty) return;

    try {
      final res = await client.functions.invoke(
        'ai-case-story',
        body: {
          'chart_id': cid,
          'mode': 'dual',
          if (jid.isNotEmpty) 'job_id': jid,
          'internal_fan_fill': true,
        },
      );
      final data = res.data;
      if (data is Map && data['error'] != null) {
        debugPrint('fan boost edge upgrade: ${data['error']}');
      }
    } catch (e, st) {
      debugPrint('fan boost edge upgrade failed: $e\n$st');
    }
  }

  static String? jobIdFromPurchase(Map<String, dynamic> raw) {
    final fill = raw['ai_fill'];
    if (fill is Map) {
      final skipped = fill['skipped'];
      if (skipped == false) {
        final id = fill['job_id']?.toString().trim() ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  static bool edgeQueuedFromPurchase(Map<String, dynamic> raw) {
    final fill = raw['ai_fill'];
    if (fill is Map && fill['edge_queued'] == true) return true;
    return false;
  }

  static Map<String, dynamic>? parseRaw(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }
}
