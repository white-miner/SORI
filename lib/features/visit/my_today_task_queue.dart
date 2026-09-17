import '../../models/customer_chart.dart';

/// PRD v7.9 Phase 2 — 마이 오늘 업무 큐 (기록 미완료만 · payment_missing 없음).
class MyTodayTaskItem {
  const MyTodayTaskItem({
    required this.chartId,
    required this.customerId,
    required this.customerLabel,
    required this.title,
    required this.subtitle,
    this.visitCheckedAt,
  });

  final String chartId;
  final String customerId;
  final String customerLabel;
  final String title;
  final String subtitle;
  final DateTime? visitCheckedAt;
}

abstract final class MyTodayTaskQueue {
  MyTodayTaskQueue._();

  static bool hasSummary(CustomerChart c) {
    return c.treatmentSummary.trim().isNotEmpty ||
        c.directorInsight.trim().isNotEmpty;
  }

  /// §16.1: visitChecked && !hasSummary
  static bool isIncompleteRecord(CustomerChart c) {
    return c.visitChecked && !hasSummary(c);
  }

  /// 최근 방문확인 순 · 최대 [limit] · Timer/결제/노쇼 미사용.
  static List<MyTodayTaskItem> buildIncompleteRecordTasks({
    required List<CustomerChart> charts,
    required String Function(String customerId) customerNameOf,
    int limit = 3,
    DateTime? now,
  }) {
    final candidates = charts.where(isIncompleteRecord).toList()
      ..sort((a, b) {
        final ad = a.visitCheckedAt ?? a.createdAt;
        final bd = b.visitCheckedAt ?? b.createdAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

    final out = <MyTodayTaskItem>[];
    for (final c in candidates) {
      if (out.length >= limit) break;
      final cid = c.customerId.trim();
      if (cid.isEmpty || c.id.trim().isEmpty) continue;
      final name = customerNameOf(cid).trim();
      final label = name.isEmpty ? '고객' : name;
      final when = c.visitCheckedAt;
      final whenLabel = when == null ? '최근 방문' : _relativeVisitLabel(when, now);
      out.add(
        MyTodayTaskItem(
          chartId: c.id,
          customerId: cid,
          customerLabel: label,
          title: '$label 고객 · $whenLabel',
          subtitle: '시술 요약이 아직 없어요',
          visitCheckedAt: when,
        ),
      );
    }
    return out;
  }

  static String _relativeVisitLabel(DateTime at, DateTime? now) {
    final n = now ?? DateTime.now();
    final a = DateTime(at.year, at.month, at.day);
    final b = DateTime(n.year, n.month, n.day);
    final days = b.difference(a).inDays;
    if (days <= 0) return '오늘 방문';
    if (days == 1) return '어제 방문';
    return '$days일 전 방문';
  }
}
