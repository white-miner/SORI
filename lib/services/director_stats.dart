import '../services/sori_store.dart';

/// 리뷰 통계 조회 기간.
enum ReviewStatsPeriod {
  day,
  week,
  month,
  year,
}

extension ReviewStatsPeriodX on ReviewStatsPeriod {
  String get label => switch (this) {
        ReviewStatsPeriod.day => '일',
        ReviewStatsPeriod.week => '주',
        ReviewStatsPeriod.month => '월',
        ReviewStatsPeriod.year => '년',
      };

  DateTime startOf(DateTime now) {
    switch (this) {
      case ReviewStatsPeriod.day:
        return DateTime(now.year, now.month, now.day);
      case ReviewStatsPeriod.week:
        return now.subtract(const Duration(days: 7));
      case ReviewStatsPeriod.month:
        return now.subtract(const Duration(days: 30));
      case ReviewStatsPeriod.year:
        return now.subtract(const Duration(days: 365));
    }
  }
}

/// 원장 마이페이지용 기간별 통계 요약.
class DirectorPeriodStats {
  const DirectorPeriodStats({
    required this.reviewsWritten,
    required this.chartsWritten,
    required this.naverConversionPercent,
    required this.topChips,
  });

  /// 기간 내 작성된 리뷰 수.
  final int reviewsWritten;

  /// 기간 내 차트(케어) 작성 건수.
  final int chartsWritten;

  /// AI 후기 작성 후 네이버 공유(등록) 전환율 %.
  final double naverConversionPercent;
  final List<({String chip, int count})> topChips;

  static DirectorPeriodStats fromStore(
    SoriStore store, {
    ReviewStatsPeriod period = ReviewStatsPeriod.month,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final start = period.startOf(n);

    bool inRange(DateTime? d) {
      if (d == null) return false;
      return !d.isBefore(start) && !d.isAfter(n);
    }

    final periodCharts = store.charts.where((c) {
      final d = c.visitCheckedAt ?? c.createdAt ?? c.feedbackLineOpenedAt;
      return inRange(d);
    }).toList();

    final periodReviews = store.reviews.where((r) {
      final d = r.acceptedAt ?? r.naverRegisteredAt;
      if (inRange(d)) return true;
      return periodCharts.any((c) => c.id == r.chartId);
    }).toList();

    final reviewCount = periodReviews.length;
    final naverCount = periodReviews.where((r) => r.naverRegistered).length;
    final conversion =
        reviewCount == 0 ? 0.0 : (naverCount / reviewCount) * 100;

    final chipCounts = <String, int>{};
    for (final r in periodReviews) {
      for (final chip in r.puzzleSelections) {
        final key = chip.trim();
        if (key.isEmpty) continue;
        chipCounts[key] = (chipCounts[key] ?? 0) + 1;
      }
    }
    for (final c in periodCharts) {
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

    return DirectorPeriodStats(
      reviewsWritten: reviewCount,
      chartsWritten: periodCharts.length,
      naverConversionPercent: conversion,
      topChips: top3,
    );
  }
}

/// @Deprecated — [DirectorPeriodStats] 사용.
typedef DirectorMonthlyStats = DirectorPeriodStats;

extension DirectorMonthlyStatsCompat on DirectorPeriodStats {
  int get reviewsThisMonth => reviewsWritten;
  int get chartsThisMonth => chartsWritten;
}
