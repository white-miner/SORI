import '../models/customer.dart';
import '../models/customer_membership.dart';
import '../models/customer_merge_preview.dart';
import '../models/customer_review.dart';
import '../models/customer_chart.dart';

/// 클라이언트 병합 미리보기 계산 (로컬 Store 데이터).
abstract final class CustomerMergeService {
  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// 최근 방문일 기준 Primary 추천.
  static String suggestPrimaryId(List<Customer> customers) {
    if (customers.isEmpty) return '';
    final sorted = [...customers]
      ..sort((a, b) => b.lastTreatmentDate.compareTo(a.lastTreatmentDate));
    return sorted.first.id;
  }

  static bool phonesMismatch(List<Customer> customers) {
    final normalized = customers
        .map((c) => normalizePhone(c.phone))
        .where((p) => p.length >= 8)
        .toSet();
    return normalized.length > 1;
  }

  static List<CustomerMembership> mergeMembershipsCombineByName(
    List<Customer> customers,
  ) {
    final map = <String, CustomerMembership>{};
    for (final c in customers) {
      for (final m in c.memberships) {
        if (m.totalVisits <= 0) continue;
        final key = m.serviceName.trim().isEmpty ? '회원권' : m.serviceName.trim();
        final existing = map[key];
        if (existing == null) {
          map[key] = m;
        } else {
          final total = existing.totalVisits + m.totalVisits;
          final used = (existing.usedVisits + m.usedVisits).clamp(0, total);
          DateTime? exp;
          if (existing.expiresAt != null && m.expiresAt != null) {
            exp = existing.expiresAt!.isAfter(m.expiresAt!)
                ? existing.expiresAt
                : m.expiresAt;
          } else {
            exp = existing.expiresAt ?? m.expiresAt;
          }
          map[key] = existing.copyWith(
            totalVisits: total,
            usedVisits: used,
            expiresAt: exp,
            paidAmount: existing.paidAmount + m.paidAmount,
          );
        }
      }
    }
    return map.values.toList();
  }

  static CustomerMergePreview buildPreview({
    required List<Customer> selected,
    required List<CustomerChart> charts,
    required List<CustomerReview> reviews,
    String? primaryId,
  }) {
    final candidates = selected
        .map(
          (c) => CustomerMergeCandidate(
            customer: c,
            chartCount: charts.where((ch) => ch.customerId == c.id).length,
            reviewCount: reviews.where((r) => r.customerId == c.id).length,
            membershipRemain: c.membershipRemainingVisits,
          ),
        )
        .toList();

    final suggested = primaryId ?? suggestPrimaryId(selected);
    final primary = selected.firstWhere(
      (c) => c.id == suggested,
      orElse: () => selected.first,
    );

    return CustomerMergePreview(
      candidates: candidates,
      suggestedPrimaryId: suggested,
      phoneMismatch: phonesMismatch(selected),
      totalChartsAfter: candidates.fold<int>(0, (s, c) => s + c.chartCount),
      totalReviewsAfter: candidates.fold<int>(0, (s, c) => s + c.reviewCount),
      mergedMemberships: mergeMembershipsCombineByName(selected),
      primaryName: primary.name,
    );
  }
}
