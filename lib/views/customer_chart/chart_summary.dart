import '../../models/customer_chart.dart';

/// 고객 차트 요약 바용 순수 계산. Store·Repository에 의존하지 않는다.
///
/// 누적 결제: [ChartDbColumns.writeKeys]에 금액 컬럼이 없어 항상 0.
/// (U1 — 없는 필드를 만들지 않음. UI는 0일 때 '—' 표기.)
class ChartSummary {
  const ChartSummary({
    required this.visitCount,
    required this.totalPaid,
    required this.remainingCredit,
    required this.daysSinceLast,
  });

  final int visitCount;
  final int totalPaid;
  final int? remainingCredit;
  final int? daysSinceLast;

  static ChartSummary from(
    List<CustomerChart> charts, {
    int? remainingCredit,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);

    DateTime? latest;
    for (final c in charts) {
      final raw = c.createdAt ?? c.visitCheckedAt;
      if (raw == null) continue;
      final day = DateTime(raw.year, raw.month, raw.day);
      if (latest == null || day.isAfter(latest)) latest = day;
    }

    int? daysSince;
    if (latest != null) {
      daysSince = today.difference(latest).inDays;
      if (daysSince < 0) daysSince = 0;
    }

    // 잔여 선불권 SSOT = Customer.membershipRemainingVisits (P8 정리 전까지 고정)
    // membership_tickets / program_memberships 를 직접 읽지 않는다 — 숫자가 갈린다
    return ChartSummary(
      visitCount: charts.length,
      totalPaid: 0,
      remainingCredit: remainingCredit,
      daysSinceLast: daysSince,
    );
  }
}
