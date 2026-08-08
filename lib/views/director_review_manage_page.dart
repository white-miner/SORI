import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';

/// 원장용 리뷰 관리 — 오늘 케어 완료 고객에게 후기 요청.
class DirectorReviewManagePage extends StatefulWidget {
  const DirectorReviewManagePage({super.key, required this.store});

  final SoriStore store;

  @override
  State<DirectorReviewManagePage> createState() =>
      _DirectorReviewManagePageState();
}

class _DirectorReviewManagePageState extends State<DirectorReviewManagePage> {
  final Set<String> _requestedIds = {};

  List<Customer> get _todayDone {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDate = widget.store.customersForDate(today);
    if (byDate.isNotEmpty) return byDate;
    // 방문 확인된 차트 보유 고객 우선
    final checked = widget.store.customers.where((c) {
      final chart = widget.store.latestChart(c.id);
      return chart?.visitChecked == true;
    }).toList();
    if (checked.isNotEmpty) return checked;
    return widget.store.customers;
  }

  void _requestReview(Customer customer) {
    setState(() => _requestedIds.add(customer.id));
    widget.store.markReviewRequested(customer.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${customer.name}님께 후기 요청을 보냈어요 💌'),
        backgroundColor: SoriTokens.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _todayDone;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              '💬 리뷰 관리',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textPrimary,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '오늘 케어 완료 고객에게 후기를 요청해 보세요',
              style: TextStyle(
                fontSize: 13,
                color: SoriTokens.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('오늘 케어 완료 고객이 없어요'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final c = list[index];
                      final chart = widget.store.latestChart(c.id);
                      final sent = _requestedIds.contains(c.id) ||
                          widget.store.isReviewRequested(c.id);

                      return SoriCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: SoriTokens.primarySoft,
                              child: Text(
                                c.name.characters.first,
                                style: const TextStyle(
                                  color: SoriTokens.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    chart == null
                                        ? c.treatmentType
                                        : '${chart.visitNumber}회차 · ${chart.careName.isNotEmpty ? chart.careName : c.treatmentType}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: SoriTokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: sent ? null : () => _requestReview(c),
                              style: FilledButton.styleFrom(
                                backgroundColor: SoriTokens.primary,
                                disabledBackgroundColor:
                                    SoriTokens.primary.withValues(alpha: 0.35),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                sent ? '요청 완료' : '💌 후기 요청하기',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
