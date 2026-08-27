import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import 'supabase_client.dart';

/// AI 임상 스토리 생성 결과 (피드 body + 외부 복사용 hashtags).
class AiCaseStoryDraft {
  const AiCaseStoryDraft({
    required this.title,
    required this.body,
    required this.hashtags,
    this.source = 'unknown',
  });

  final String title;
  final String body;
  final List<String> hashtags;
  final String source;

  /// Instagram paste: body + blank line + hashtags.
  String get clipboardPayload {
    final tags = hashtags
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .map((h) => h.startsWith('#') ? h : '#$h')
        .join(' ');
    final story = body.trim();
    if (tags.isEmpty) return story;
    if (story.isEmpty) return tags;
    return '$story\n\n$tags';
  }

  factory AiCaseStoryDraft.fromJson(Map<String, dynamic> map) {
    final rawTags = map['hashtags'];
    List<String> tags = const [];
    if (rawTags is List) {
      tags = rawTags.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawTags is String && rawTags.trim().isNotEmpty) {
      tags = rawTags
          .split(RegExp(r'\s+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return AiCaseStoryDraft(
      title: (map['title'] as String?)?.trim() ?? '',
      body: (map['body'] as String?)?.trim() ?? '',
      hashtags: tags,
      source: (map['source'] as String?)?.trim() ?? 'unknown',
    );
  }
}

class AiCaseStoryUsage {
  const AiCaseStoryUsage({
    required this.used,
    required this.limit,
  });

  final int used;
  final int limit;

  int get remaining => (limit - used).clamp(0, limit);
  bool get exhausted => remaining <= 0;

  String get chipLabel => '무료 $remaining/$limit회';
}

/// Edge `ai-case-story` 클라이언트 + 월 3회 무료 카운트(로컬, P0a).
abstract final class AiCaseStoryService {
  static const freeLimit = 3;

  static String _monthKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    return 'ai_case_story_usage_${n.year}-$m';
  }

  static Future<AiCaseStoryUsage> loadUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_monthKey()) ?? 0;
    return AiCaseStoryUsage(used: used.clamp(0, freeLimit), limit: freeLimit);
  }

  static Future<AiCaseStoryUsage> consumeUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _monthKey();
    final used = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, used);
    return AiCaseStoryUsage(used: used.clamp(0, 999), limit: freeLimit);
  }

  /// Edge 우선. 실패 시 비식별 로컬 폴백 (공유 루프 유지).
  static Future<AiCaseStoryDraft> generate({
    required CustomerChart chart,
    Customer? customer,
  }) async {
    final client = SoriSupabase.clientOrNull;
    if (client != null) {
      try {
        final res = await client.functions.invoke(
          'ai-case-story',
          body: {'chart_id': chart.id},
        );
        final data = res.data;
        Map<String, dynamic>? map;
        if (data is Map) {
          map = Map<String, dynamic>.from(data);
        } else if (data is String) {
          final decoded = jsonDecode(data);
          if (decoded is Map) map = Map<String, dynamic>.from(decoded);
        }
        if (map != null && map['error'] == null) {
          final draft = AiCaseStoryDraft.fromJson(map);
          if (draft.body.isNotEmpty) return draft;
        }
        debugPrint('ai-case-story edge soft-fail: $data');
      } catch (e, st) {
        debugPrint('ai-case-story invoke failed: $e\n$st');
      }
    }
    return localFallback(chart: chart, customer: customer);
  }

  static AiCaseStoryDraft localFallback({
    required CustomerChart chart,
    Customer? customer,
  }) {
    final ageBand = _ageBand(customer?.koreanAge ?? chart.feedAge);
    final gender = customer?.gender?.label ??
        (chart.feedGenderLabel?.trim().isNotEmpty == true
            ? chart.feedGenderLabel!.trim()
            : null);
    final who = [ageBand, gender].whereType<String>().join(' ');
    final care = chart.careName.trim().isEmpty ? '케어' : chart.careName.trim();
    final concern = chart.concernChips.isNotEmpty
        ? chart.concernChips.first
        : '피부 컨디션';
    final device = (chart.deviceInfo ?? '').trim();
    final insight = chart.directorInsight.trim().isNotEmpty
        ? chart.directorInsight.trim()
        : chart.treatmentSummary.trim();
    final mid = device.isEmpty ? '' : ' $device를 활용해';
    final tail = insight.isNotEmpty
        ? insight
        : '시술 전후 변화를 기록해 두었습니다. 개인 식별 정보는 포함되지 않습니다.';
    var body =
        '${who.isEmpty ? '고객' : who} 분의 $concern 고민에 맞춰 $care를 진행했습니다.$mid $tail';
    if (body.length > 420) body = body.substring(0, 420);

    final tags = <String>['#SORI', '#비포애프터', '#에스테틱'];
    final careTag = care.replaceAll(RegExp(r'\s+'), '');
    if (careTag.isNotEmpty) tags.add('#${careTag.length > 12 ? careTag.substring(0, 12) : careTag}');

    return AiCaseStoryDraft(
      title: '$care · 임상 케이스',
      body: body,
      hashtags: tags,
      source: 'local_fallback',
    );
  }

  static String? _ageBand(int? age) {
    if (age == null || age < 0 || age > 120) return null;
    final decade = (age ~/ 10) * 10;
    final rem = age % 10;
    if (decade < 10) return '10대';
    if (rem <= 2) return '$decade대 초반';
    if (rem <= 5) return '$decade대 중반';
    return '$decade대 후반';
  }
}
