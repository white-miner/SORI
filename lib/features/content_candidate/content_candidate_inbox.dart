import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/customer_chart.dart';
import '../../utils/consent_publish_gate.dart';

/// 로컬 콘텐츠 후보함. DB 스키마 없이 chartId + 상태만 둔다.
enum ContentCandidateStatus { queued, ready }

class ContentCandidateCard {
  const ContentCandidateCard({
    required this.chartId,
    required this.imageUrl,
    required this.serviceSummary,
    required this.createdAt,
    required this.status,
  });

  final String chartId;
  final String? imageUrl;
  final String serviceSummary;
  final DateTime? createdAt;
  final ContentCandidateStatus status;

  String get statusLabel => switch (status) {
        ContentCandidateStatus.queued => '후보',
        ContentCandidateStatus.ready => '발행 준비 완료',
      };
}

class ContentCandidateInbox extends ChangeNotifier {
  ContentCandidateInbox({Map<String, ContentCandidateStatus>? seed})
      : _entries = {...?seed};

  static const prefKey = 'sori_content_candidate_inbox_v1';

  static ContentCandidateInbox instance = ContentCandidateInbox();

  final Map<String, ContentCandidateStatus> _entries;

  @visibleForTesting
  void debugReset() {
    _entries.clear();
    notifyListeners();
  }

  Map<String, ContentCandidateStatus> get entries =>
      Map.unmodifiable(_entries);

  bool contains(String chartId) => _entries.containsKey(chartId.trim());

  /// 공개·발행 가능 B/A. 동의 게이트는 [canPublishBa] 재사용(규칙 변경 없음).
  static bool isEligible(CustomerChart chart) {
    if (!chart.hasBeforeImage || !chart.hasAfterImage) return false;
    if (chart.caseShared) return false;
    return canPublishBa(chart).allowsPublish;
  }

  /// 카드용 공개 투영 — 실명·전화·note·insight 없음.
  static ContentCandidateCard cardFor(
    CustomerChart chart,
    ContentCandidateStatus status,
  ) {
    final pub = chart.asPublicFeedProjection();
    final after = pub.afterImageUrl?.trim();
    final before = pub.beforeImageUrl?.trim();
    final image = (after != null && after.isNotEmpty)
        ? after
        : ((before != null && before.isNotEmpty) ? before : null);
    final care = pub.careName.trim();
    return ContentCandidateCard(
      chartId: chart.id,
      imageUrl: image,
      serviceSummary: care.isEmpty ? '케어' : care,
      createdAt: pub.createdAt ?? pub.visitCheckedAt,
      status: status,
    );
  }

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _entries
        ..clear()
        ..addAll({
          for (final e in decoded.entries)
            if (e.key.toString().trim().isNotEmpty)
              e.key.toString(): e.value.toString() == 'ready'
                  ? ContentCandidateStatus.ready
                  : ContentCandidateStatus.queued,
        });
      notifyListeners();
    } catch (_) {
      // keep current
    }
  }

  Future<bool> enqueue(CustomerChart chart) async {
    if (!isEligible(chart)) return false;
    final id = chart.id.trim();
    if (id.isEmpty || _entries.containsKey(id)) return false;
    _entries[id] = ContentCandidateStatus.queued;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<bool> markReady(String chartId) async {
    final id = chartId.trim();
    if (!_entries.containsKey(id)) return false;
    _entries[id] = ContentCandidateStatus.ready;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefKey,
      jsonEncode({
        for (final e in _entries.entries) e.key: e.value.name,
      }),
    );
  }
}
