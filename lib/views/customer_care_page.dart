import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/membership_progress.dart';
import '../widgets/sori_card.dart';
import '../widgets/sori_empty_state.dart';

/// 고객 케어 탭 — 회원권 현황 + 시술 기록 아코디언.
class CustomerCareTab extends StatefulWidget {
  const CustomerCareTab({super.key, required this.store});

  final SoriStore store;

  @override
  State<CustomerCareTab> createState() => _CustomerCareTabState();
}

class _CustomerCareTabState extends State<CustomerCareTab> {
  int? _expandedVisit;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final customerId = store.session?.customerId;
    final customer =
        customerId == null ? null : store.findCustomer(customerId);
    final charts = customerId == null
        ? <CustomerChart>[]
        : store.chartsForCustomer(customerId).toList()
      ..sort((a, b) => a.visitNumber.compareTo(b.visitNumber));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const Text(
            '내 케어',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _MembershipHeroCard(customer: customer),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('예약 요청을 원장님께 전달했어요'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: SoriTokens.primary,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text(
                '📅 다음 방문 예약 요청하기',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '시술 기록',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (charts.isEmpty)
            const SoriEmptyState(
              icon: Icons.spa_outlined,
              message: '진행 중인 케어 내역이 없습니다.',
              subtitle: '방문 후 원장님이 차트를 작성하면\n회차별 기록이 여기에 표시됩니다',
            )
          else
            ...charts.map((chart) {
              final expanded = _expandedVisit == chart.visitNumber;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CareAccordionCard(
                  chart: chart,
                  expanded: expanded,
                  onToggle: () {
                    setState(() {
                      _expandedVisit =
                          expanded ? null : chart.visitNumber;
                    });
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MembershipHeroCard extends StatelessWidget {
  const _MembershipHeroCard({required this.customer});

  final Customer? customer;

  @override
  Widget build(BuildContext context) {
    if (customer == null || !customer!.isMembershipCustomer) {
      return SoriCard(
        child: Column(
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              '등록된 회원권이 없습니다.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '원장님이 회원권을 등록하면\n잔여 횟수가 여기에 표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    final c = customer!;
    return SoriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '현재 이용 중인 회원권',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            c.membershipServiceName.isNotEmpty
                ? c.membershipServiceName
                : '회원권',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          MembershipProgressView(
            customer: c,
            showServiceName: false,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                label: '총 횟수',
                value: '${c.membershipTotalVisits}',
              ),
              _Metric(
                label: '차감',
                value: '${c.membershipUsedVisits}',
              ),
              _Metric(
                label: '잔여',
                value: '${c.membershipRemainingVisits}',
                emphasize: c.isMembershipLow,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color =
        emphasize ? SoriTokens.warningText : SoriTokens.primary;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: SoriTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CareAccordionCard extends StatelessWidget {
  const _CareAccordionCard({
    required this.chart,
    required this.expanded,
    required this.onToggle,
  });

  final CustomerChart chart;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visitDate = chart.visitCheckedAt;
    final title =
        chart.careName.isNotEmpty ? chart.careName : chart.treatmentSummary;

    return SoriCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(SoriTokens.radiusLg),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: SoriTokens.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${chart.visitNumber}회차',
                      style: const TextStyle(
                        color: SoriTokens.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? '케어 기록' : title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (visitDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '방문 ${_fmt(visitDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.expand_more,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: SoriTokens.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    '원장님 케어 리포트',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    chart.directorInsight.isNotEmpty
                        ? chart.directorInsight
                        : (chart.treatmentSummary.isNotEmpty
                            ? chart.treatmentSummary
                            : '작성된 리포트가 아직 없어요'),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PhotoSlot(
                          label: 'Before',
                          hasPhoto: chart.beforeImageUrl != null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PhotoSlot(
                          label: 'After',
                          hasPhoto: chart.afterImageUrl != null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.label, required this.hasPhoto});

  final String label;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: SoriTokens.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoriTokens.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasPhoto ? Icons.image_outlined : Icons.hide_image_outlined,
            color: SoriTokens.primary,
          ),
          const SizedBox(height: 6),
          Text(
            hasPhoto ? '$label 첨부됨' : '$label 없음',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SoriTokens.primary,
            ),
          ),
        ],
      ),
    );
  }
}
