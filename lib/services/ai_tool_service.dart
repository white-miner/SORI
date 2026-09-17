import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/ai_tool.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import 'ai_case_story_service.dart';
import 'supabase_client.dart';

/// AI Tool Split & Micro — server quota + Edge generation.
abstract final class AiToolService {
  static Future<AiToolQuota> loadQuota(String shopId) async {
    final client = SoriSupabase.clientOrNull;
    if (client == null || shopId.trim().isEmpty) {
      return const AiToolQuota();
    }
    try {
      final raw = await client.rpc(
        'get_ai_tool_quota',
        params: {'p_shop_id': shopId.trim()},
      );
      if (raw is Map) {
        return AiToolQuota.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (e, st) {
      debugPrint('get_ai_tool_quota failed: $e\n$st');
    }
    return const AiToolQuota();
  }

  static Future<List<ShopPromoCredit>> loadPromoCredits(String shopId) async {
    final client = SoriSupabase.clientOrNull;
    if (client == null || shopId.trim().isEmpty) return const [];
    try {
      final raw = await client.rpc(
        'get_shop_promo_credits',
        params: {'p_shop_id': shopId.trim()},
      );
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => ShopPromoCredit.fromMap(Map<String, dynamic>.from(e)))
            .where((c) => c.balance > 0)
            .toList();
      }
    } catch (e, st) {
      debugPrint('get_shop_promo_credits failed: $e\n$st');
    }
    return const [];
  }

  static Future<AiToolPurchaseResult> purchase({
    required String shopId,
    required String chartId,
    required AiToolMode mode,
  }) async {
    final client = SoriSupabase.clientOrNull;
    if (client == null) {
      return const AiToolPurchaseResult(
        ok: false,
        message: 'Supabase not configured',
      );
    }
    try {
      final raw = await client.rpc(
        'purchase_ai_tool',
        params: {
          'p_shop_id': shopId.trim(),
          'p_chart_id': chartId.trim(),
          'p_sku': mode.sku,
        },
      );
      if (raw is Map) {
        return AiToolPurchaseResult.fromMap(Map<String, dynamic>.from(raw));
      }
      return const AiToolPurchaseResult(ok: false, message: 'empty response');
    } catch (e, st) {
      debugPrint('purchase_ai_tool failed: $e\n$st');
      final msg = e.toString();
      if (msg.contains('insufficient points')) {
        final haveMatch = RegExp(r'have (\d+)').firstMatch(msg);
        final needMatch = RegExp(r'need (\d+)').firstMatch(msg);
        return AiToolPurchaseResult.insufficientPoints(
          have: int.tryParse(haveMatch?.group(1) ?? '') ?? 0,
          need: int.tryParse(needMatch?.group(1) ?? '') ?? mode.priceEcho,
        );
      }
      rethrow;
    }
  }

  static Future<void> completeJob({
    required String jobId,
    required Map<String, dynamic> result,
    String status = 'done',
    String errorMessage = '',
  }) async {
    final client = SoriSupabase.clientOrNull;
    if (client == null || jobId.trim().isEmpty) return;
    try {
      await client.rpc(
        'complete_ai_tool_job',
        params: {
          'p_job_id': jobId.trim(),
          'p_result': result,
          'p_status': status,
          'p_error_message': errorMessage,
        },
      );
    } catch (e, st) {
      debugPrint('complete_ai_tool_job failed: $e\n$st');
    }
  }

  /// Charge via RPC then call Edge with job_id + mode.
  static Future<AiToolDraft> generate({
    required String shopId,
    required String chartId,
    required AiToolMode mode,
    Customer? customer,
    CustomerChart? chart,
  }) async {
    final purchaseResult = await AiToolService.purchase(
      shopId: shopId,
      chartId: chartId,
      mode: mode,
    );
    if (!purchaseResult.ok || purchaseResult.jobId.isEmpty) {
      throw StateError(
        purchaseResult.message.isEmpty ? 'AI 결제 실패' : purchaseResult.message,
      );
    }

    final client = SoriSupabase.clientOrNull;
    Map<String, dynamic>? map;
    if (client != null) {
      try {
        final res = await client.functions.invoke(
          'ai-case-story',
          body: {
            'chart_id': chartId.trim(),
            'mode': mode == AiToolMode.regenerate
                ? 'marketing'
                : mode.name,
            'job_id': purchaseResult.jobId,
          },
        );
        final data = res.data;
        if (data is Map) {
          map = Map<String, dynamic>.from(data);
        } else if (data is String) {
          final decoded = jsonDecode(data);
          if (decoded is Map) map = Map<String, dynamic>.from(decoded);
        }
      } catch (e, st) {
        debugPrint('ai-case-story invoke failed: $e\n$st');
      }
    }

    AiToolDraft draft;
    if (map != null && map['error'] == null) {
      draft = AiToolDraft.fromJson(map, mode: mode);
      if (draft.marketingBody.isNotEmpty || draft.clinicalReport.isNotEmpty) {
        await completeJob(jobId: purchaseResult.jobId, result: map);
        return draft;
      }
    }

    if (chart != null) {
      final legacy = AiCaseStoryService.localFallback(
        chart: chart,
        customer: customer,
      );
      draft = AiToolDraft(
        title: legacy.title,
        marketingBody: legacy.body,
        clinicalReport: _clinicalFallback(chart),
        hashtags: legacy.hashtags,
        source: 'local_fallback',
        mode: mode,
      );
    } else {
      draft = AiToolDraft(
        title: '임상 케이스',
        marketingBody: 'AI 연결이 불안정합니다. 잠시 후 다시 시도해 주세요.',
        clinicalReport: '',
        source: 'local_fallback',
        mode: mode,
      );
    }

    await completeJob(
      jobId: purchaseResult.jobId,
      result: {
        'title': draft.title,
        'body': draft.marketingBody,
        'clinical_report': draft.clinicalReport,
        'hashtags': draft.hashtags,
        'source': draft.source,
      },
      status: 'done',
    );
    return draft;
  }

  static String _clinicalFallback(CustomerChart chart) {
    final care = chart.careName.trim().isEmpty ? '케어' : chart.careName.trim();
    final concern = chart.concernChips.isNotEmpty
        ? chart.concernChips.join(', ')
        : '피부 컨디션';
    final device = (chart.deviceInfo ?? '').trim();
    final insight = chart.directorInsight.trim().isNotEmpty
        ? chart.directorInsight.trim()
        : chart.treatmentSummary.trim();
    final deviceLine = device.isEmpty ? '' : '\n- 사용 기기: $device';
    return '【임상 참고 요약 · 의료 진단 아님】\n'
        '- 시술: $care\n'
        '- 주요 고민: $concern$deviceLine\n'
        '- 원장 메모: ${insight.isEmpty ? '기록 없음' : insight}';
  }
}
