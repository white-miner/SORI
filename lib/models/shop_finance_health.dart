import 'customer.dart';
import 'customer_membership.dart';
import 'membership_ticket.dart';
import 'shop.dart';

/// 재무 건전성 + Hell-Zone 스냅샷.
class ShopFinanceHealth {
  const ShopFinanceHealth({
    required this.laborDebtWon,
    required this.totalRemainingSessions,
    required this.monthlyCapa,
    required this.hellZoneThreshold,
    required this.isHellZone,
    required this.singlePayRevenueWon,
    required this.membershipPayDebtWon,
    required this.debtRiskCustomers,
  });

  /// Σ (per_session_value × 잔여 횟수)
  final int laborDebtWon;

  /// 전체 남은 횟수 총합
  final int totalRemainingSessions;

  final int monthlyCapa;

  /// CAPA × 1.2
  final int hellZoneThreshold;

  final bool isHellZone;

  /// 단과 결제(순수익) — 이번 달 추정 MOCK/집계
  final int singlePayRevenueWon;

  /// 회원권 결제(부채) — 이번 달 추정
  final int membershipPayDebtWon;

  final List<DebtRiskCustomer> debtRiskCustomers;

  double get capaUtilization {
    if (monthlyCapa <= 0) return 0;
    return totalRemainingSessions / monthlyCapa;
  }
}

class DebtRiskCustomer {
  const DebtRiskCustomer({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.remainingVisits,
    required this.totalVisits,
    required this.reason,
    required this.laborDebtWon,
    this.lastPromotionSentAt,
  });

  final String customerId;
  final String name;
  final String phone;
  final int remainingVisits;
  final int totalVisits;
  final String reason;
  final int laborDebtWon;
  final DateTime? lastPromotionSentAt;
}

/// 샵 재무 지표 집계.
abstract final class ShopFinanceAnalyzer {
  static const double hellZoneRatio = 1.2;

  static ShopFinanceHealth analyze({
    required Shop shop,
    required List<Customer> customers,
    List<MembershipTicket> tickets = const [],
    int? singlePayRevenueWon,
    int? membershipPayDebtWon,
  }) {
    final capa = shop.monthlyCapa <= 0 ? 100 : shop.monthlyCapa;
    final threshold = (capa * hellZoneRatio).round();

    var laborDebt = 0;
    var remaining = 0;

    if (tickets.isNotEmpty) {
      for (final t in tickets.where((t) => t.shopId == shop.id || shop.id.isEmpty)) {
        remaining += t.remainingVisits;
        laborDebt += t.laborDebtWon;
      }
    } else {
      for (final c in customers) {
        for (final m in c.memberships) {
          remaining += m.remainingVisits;
          laborDebt += m.laborDebtWon;
        }
      }
    }

    // 단과/회원권 매출 분리 — 호출부 미지정 시 부채 대비 추정
    final membershipPay = membershipPayDebtWon ??
        customers.fold<int>(
          0,
          (sum, c) =>
              sum +
              c.memberships.fold<int>(0, (s, m) => s + m.paidAmount),
        );
    final singlePay = singlePayRevenueWon ??
        (laborDebt > 0
            ? (laborDebt * 0.42).round()
            : 4200000);

    final risks = findDebtRiskCustomers(customers);

    return ShopFinanceHealth(
      laborDebtWon: laborDebt,
      totalRemainingSessions: remaining,
      monthlyCapa: capa,
      hellZoneThreshold: threshold,
      isHellZone: remaining > threshold,
      singlePayRevenueWon: singlePay,
      membershipPayDebtWon: membershipPay,
      debtRiskCustomers: risks,
    );
  }

  /// 등록 6개월+ & 잔여 ≥50% OR 마지막 방문 60일+ & 잔여>0
  static List<DebtRiskCustomer> findDebtRiskCustomers(
    List<Customer> customers, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final sixMonthsAgo = n.subtract(const Duration(days: 183));
    final sixtyDaysAgo = n.subtract(const Duration(days: 60));
    final out = <DebtRiskCustomer>[];

    for (final c in customers) {
      final synced = c.withSyncedMembershipMirrors();
      final remaining = synced.membershipRemainingVisits;
      if (remaining <= 0) continue;

      final total = synced.memberships.isNotEmpty
          ? synced.memberships.fold<int>(0, (s, m) => s + m.totalVisits)
          : synced.membershipTotalVisits;
      if (total <= 0) continue;

      final remainingRatio = remaining / total;
      final registeredAt = synced.createdAt ??
          n.subtract(const Duration(days: 200)); // 시드 폴백
      final lastVisit = synced.lastTreatmentDate;

      String? reason;
      if (!registeredAt.isAfter(sixMonthsAgo) && remainingRatio >= 0.5) {
        reason = '등록 6개월+ · 잔여 ${(remainingRatio * 100).round()}%';
      } else if (lastVisit.isBefore(sixtyDaysAgo)) {
        final days = n.difference(lastVisit).inDays;
        reason = '미방문 $days일 · 잔여 $remaining회';
      }
      if (reason == null) continue;

      final debt = synced.memberships.fold<int>(
        0,
        (s, m) => s + m.laborDebtWon,
      );

      out.add(
        DebtRiskCustomer(
          customerId: synced.id,
          name: synced.name,
          phone: synced.phone,
          remainingVisits: remaining,
          totalVisits: total,
          reason: reason,
          laborDebtWon: debt,
          lastPromotionSentAt: synced.lastPromotionSentAt,
        ),
      );
    }

    out.sort((a, b) => b.laborDebtWon.compareTo(a.laborDebtWon));
    return out;
  }

  /// Hell-Zone 데모용 — 시드 데이터가 CAPA를 넘도록 보정값 포함.
  static ShopFinanceHealth demoOverlay(ShopFinanceHealth base) {
    if (base.totalRemainingSessions > base.hellZoneThreshold) {
      return base;
    }
    // 데모: CAPA 100 기준 잔여 132회 · 부채 약 1,584만
    return ShopFinanceHealth(
      laborDebtWon: base.laborDebtWon > 0 ? base.laborDebtWon : 15840000,
      totalRemainingSessions:
          base.totalRemainingSessions > 0 ? base.totalRemainingSessions : 132,
      monthlyCapa: base.monthlyCapa,
      hellZoneThreshold: base.hellZoneThreshold,
      isHellZone: true,
      singlePayRevenueWon: base.singlePayRevenueWon > 0
          ? base.singlePayRevenueWon
          : 6840000,
      membershipPayDebtWon: base.membershipPayDebtWon > 0
          ? base.membershipPayDebtWon
          : 12600000,
      debtRiskCustomers: base.debtRiskCustomers,
    );
  }
}

extension CustomerMembershipFinanceX on CustomerMembership {
  // already on model
}
