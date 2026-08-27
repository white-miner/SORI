import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../theme/crm_ring_tokens.dart';

enum CrmRingStatus { excellent, caution, warning, critical, neutral }

class CrmRingVisual {
  const CrmRingVisual({
    required this.status,
    required this.gradientColors,
    required this.animate,
    required this.tooltipLabel,
  });

  final CrmRingStatus status;
  final List<Color> gradientColors;
  final bool animate;
  final String tooltipLabel;
}

/// 고객 CRM 상태 → 프로필 링 시각 속성.
abstract final class CustomerCrmStatusResolver {
  static CrmRingVisual resolve(Customer customer, List<CustomerChart> charts) {
    final now = DateTime.now();
    final customerCharts = charts
        .where((c) => c.customerId == customer.id)
        .toList()
      ..sort((a, b) {
        final ad = a.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

    final daysSinceVisit = _daysSince(customer.lastTreatmentDate, now);
    final daysSinceCreated = customer.createdAt != null
        ? now.difference(customer.createdAt!).inDays
        : daysSinceVisit;
    final latest = customerCharts.isEmpty ? null : customerCharts.first;
    final hasCharts = customerCharts.isNotEmpty;

    // Neutral: 신규 7일 유예 & 차트 없음
    if (!hasCharts && daysSinceCreated <= CrmRingTokens.neutralGraceDays) {
      return const CrmRingVisual(
        status: CrmRingStatus.neutral,
        gradientColors: [CrmRingTokens.neutralColor, CrmRingTokens.neutralColor],
        animate: false,
        tooltipLabel: '신규 고객 · 상태 판단 전',
      );
    }

    final remain = customer.membershipRemainingVisits;
    final hasMembership = customer.isMembershipCustomer;

    // Red (critical) — worst wins
    if (daysSinceVisit >= CrmRingTokens.redDays ||
        !hasCharts ||
        (hasMembership && remain >= 1 && daysSinceVisit >= CrmRingTokens.orangeDays) ||
        (latest != null &&
            !latest.visitChecked &&
            daysSinceVisit >= 30)) {
      return CrmRingVisual(
        status: CrmRingStatus.critical,
        gradientColors: const [CrmRingTokens.redStart, CrmRingTokens.redEnd],
        animate: true,
        tooltipLabel: !hasCharts
            ? '차트 없음 · CRM 액션 필요'
            : '$daysSinceVisit일 미방문 · CRM 액션 필요',
      );
    }

    // Orange
    if (daysSinceVisit >= CrmRingTokens.orangeDays ||
        (latest?.needsAfterPhoto ?? false) ||
        (hasMembership && remain <= 2 && daysSinceVisit >= CrmRingTokens.yellowDays)) {
      return CrmRingVisual(
        status: CrmRingStatus.warning,
        gradientColors: const [CrmRingTokens.orangeStart, CrmRingTokens.orangeEnd],
        animate: true,
        tooltipLabel: latest?.needsAfterPhoto ?? false
            ? 'After 사진 대기 · 관리 필요'
            : '$daysSinceVisit일 미방문 · 이탈 징후',
      );
    }

    // Yellow
    if (daysSinceVisit >= CrmRingTokens.yellowDays ||
        (latest != null && !latest.visitChecked && daysSinceVisit <= 14) ||
        (hasMembership && daysSinceVisit >= CrmRingTokens.yellowDays)) {
      return CrmRingVisual(
        status: CrmRingStatus.caution,
        gradientColors: const [CrmRingTokens.yellowStart, CrmRingTokens.yellowEnd],
        animate: true,
        tooltipLabel: latest != null && !latest.visitChecked
            ? '최근 차트 미확정 · 확인 필요'
            : '$daysSinceVisit일 미방문 · 관리 주의',
      );
    }

    // Green
    return const CrmRingVisual(
      status: CrmRingStatus.excellent,
      gradientColors: [CrmRingTokens.greenStart, CrmRingTokens.greenEnd],
      animate: true,
      tooltipLabel: '활성 고객 · 정상 관리 중',
    );
  }

  static int _daysSince(DateTime date, DateTime now) {
    final d = DateTime(date.year, date.month, date.day);
    final n = DateTime(now.year, now.month, now.day);
    return n.difference(d).inDays.clamp(0, 9999);
  }
}
