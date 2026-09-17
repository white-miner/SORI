import '../models/customer_review.dart';
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
///
/// - 작성된 리뷰: `customer_reviews` 중 status != draft (고객 작성 완료/진행만)
/// - 차트 작성(케어): `customer_charts` 생성 건수만 독립 집계
class DirectorPeriodStats {
  const DirectorPeriodStats({
    required this.reviewsWritten,
    required this.chartsWritten,
    required this.naverConversionPercent,
    required this.topChips,
  });

  /// 기간 내 작성된 리뷰 수 (DRAFT 제외).
  final int reviewsWritten;

  /// 기간 내 차트(케어) 작성 건수 — 리뷰와 무관.
  final int chartsWritten;

  /// AI 후기 작성 후 네이버 공유(등록) 전환율 %.
  final double naverConversionPercent;
  final List<({String chip, int count})> topChips;

  /// DB `status` 값 `'draft'` 와 동일 — 차트 저장 시 자동 초안은 통계에서 제외.
  static bool isCompletedReview(CustomerReview r) =>
      r.status != ReviewStatus.draft;

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

    // 1) 차트 작성(케어) — customer_charts 생성 시각만 독립 집계
    final periodCharts = store.charts.where((c) {
      final d = c.createdAt ?? c.visitCheckedAt ?? c.feedbackLineOpenedAt;
      return inRange(d);
    }).toList();

    // 2) 작성된 리뷰 — status != draft 만 (차트 초안 자동 생성분 제외)
    final periodReviews = store.reviews.where((r) {
      if (!isCompletedReview(r)) return false;
      final completedAt = r.acceptedAt ?? r.naverRegisteredAt;
      if (inRange(completedAt)) return true;
      // 완료 상태인데 시각이 없으면 해당 차트 생성일이 기간 안일 때만 귀속
      if (completedAt != null) return false;
      final chart = store.findChartById(r.chartId);
      if (chart == null) return false;
      final chartAt =
          chart.createdAt ?? chart.visitCheckedAt ?? chart.feedbackLineOpenedAt;
      return inRange(chartAt);
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
