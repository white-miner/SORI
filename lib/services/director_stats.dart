import '../services/sori_store.dart';

/// 원장 마이페이지용 월간 통계 요약.
class DirectorMonthlyStats {
  const DirectorMonthlyStats({
    required this.reviewsThisMonth,
    required this.chartsThisMonth,
    required this.naverConversionPercent,
    required this.topChips,
  });

  final int reviewsThisMonth;
  final int chartsThisMonth;
  final double naverConversionPercent;
  final List<({String chip, int count})> topChips;

  static DirectorMonthlyStats fromStore(SoriStore store, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final monthStart = DateTime(n.year, n.month, 1);

    bool inMonth(DateTime? d) {
      if (d == null) return false;
      return !d.isBefore(monthStart) &&
          d.year == n.year &&
          d.month == n.month;
    }

    final monthCharts = store.charts.where((c) {
      final d = c.visitCheckedAt ?? c.feedbackLineOpenedAt;
      if (d != null) return inMonth(d);
      return false;
    }).toList();

    final chartsBasis =
        monthCharts.isNotEmpty ? monthCharts : store.charts.toList();
    final chartIds = chartsBasis.map((c) => c.id).toSet();

    final monthReviews = store.reviews.where((r) {
      if (chartIds.contains(r.chartId)) return true;
      if (r.acceptedAt != null) return inMonth(r.acceptedAt);
      if (r.naverRegisteredAt != null) return inMonth(r.naverRegisteredAt);
      return monthCharts.isEmpty;
    }).toList();

    final reviewCount = monthReviews.isNotEmpty
        ? monthReviews.length
        : store.reviews.length;
    final naverCount = (monthReviews.isNotEmpty ? monthReviews : store.reviews)
        .where((r) => r.naverRegistered)
        .length;
    final conversion =
        reviewCount == 0 ? 0.0 : (naverCount / reviewCount) * 100;

    final chipCounts = <String, int>{};
    for (final r in (monthReviews.isNotEmpty ? monthReviews : store.reviews)) {
      for (final chip in r.puzzleSelections) {
        final key = chip.trim();
        if (key.isEmpty) continue;
        chipCounts[key] = (chipCounts[key] ?? 0) + 1;
      }
    }
    for (final c in chartsBasis) {
      for (final chip in [
        ...c.concernChips,
        ...c.firstVisitFearChips,
        ...c.revisitFeedbackChips,
      ]) {
        final key = chip.trim();
        if (key.isEmpty) continue;
        chipCounts[key] = (chipCounts[key] ?? 0) + 1;
      }
    }

    final top = chipCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 =
        top.take(3).map((e) => (chip: e.key, count: e.value)).toList();

    return DirectorMonthlyStats(
      reviewsThisMonth: reviewCount,
      chartsThisMonth: chartsBasis.length,
      naverConversionPercent: conversion,
      topChips: top3,
    );
  }
}
