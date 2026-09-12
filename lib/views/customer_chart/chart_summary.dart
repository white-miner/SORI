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
    this.latestChangeLine,
  });

  final int visitCount;
  final int totalPaid;
  final int? remainingCredit;
  final int? daysSinceLast;

  /// 최근 시술명과 B/A 상태. 값이 없으면 UI에서 숨긴다.
  final String? latestChangeLine;

  /// 방문번호가 가장 큰 차트 1건. 없으면 null.
  static CustomerChart? latestChart(Iterable<CustomerChart> charts) {
    CustomerChart? latest;
    for (final c in charts) {
      if (latest == null || c.visitNumber > latest.visitNumber) {
        latest = c;
      }
    }
    return latest;
  }

  /// 존재하는 시술명·사진 상태만 이어 붙인다. placeholder 없음.
  static String? changeLineFor(CustomerChart? chart) {
    if (chart == null) return null;
    final care = chart.careName.trim();
    final ba = chart.hasBeforeImage && chart.hasAfterImage
        ? 'B/A 있음'
        : (chart.needsAfterPhoto ? 'After 촬영 필요' : null);
    final parts = <String>[
      if (care.isNotEmpty) care,
      ?ba,
    ];
    if (parts.isEmpty) return null;
    return parts.join('  ·  ');
  }

  static ChartSummary from(
    List<CustomerChart> charts, {
    int? remainingCredit,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);

    DateTime? latestDay;
    for (final c in charts) {
      final raw = c.createdAt ?? c.visitCheckedAt;
      if (raw == null) continue;
      final day = DateTime(raw.year, raw.month, raw.day);
      if (latestDay == null || day.isAfter(latestDay)) latestDay = day;
    }

    int? daysSince;
    if (latestDay != null) {
      daysSince = today.difference(latestDay).inDays;
      if (daysSince < 0) daysSince = 0;
    }

    // 잔여 선불권 SSOT = Customer.membershipRemainingVisits (P8 정리 전까지 고정)
    // membership_tickets / program_memberships 를 직접 읽지 않는다 — 숫자가 갈린다
    return ChartSummary(
      visitCount: charts.length,
      totalPaid: 0,
      remainingCredit: remainingCredit,
      daysSinceLast: daysSince,
      latestChangeLine: changeLineFor(latestChart(charts)),
    );
  }
}
