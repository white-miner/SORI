import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/sori_share.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/review_qr_modal.dart';
import '../widgets/sori_card.dart';
import 'customer_link_popup.dart';

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

  Future<void> _shareCustomerLink(Customer customer) async {
    final chart = widget.store.latestChart(customer.id);
    final token = chart?.feedbackToken;
    if (chart == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('리뷰 링크가 아직 없어요. 방문 확인 후 다시 시도해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await SoriShare.shareReviewLink(
      url: SoriStore.buildCustomerReviewUrl(token),
      customerName: customer.name,
      careName: chart.careName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _todayDone;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '💬 리뷰 관리',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      showShopReviewQrModal(context, store: widget.store),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                  label: const Text(
                    'QR',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: SoriTokens.primary,
                  ),
                ),
              ],
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
                      final hasLink = chart?.feedbackToken != null;

                      return SoriCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                  onPressed:
                                      sent ? null : () => _requestReview(c),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: SoriTokens.primary,
                                    disabledBackgroundColor: SoriTokens.primary
                                        .withValues(alpha: 0.35),
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
                            if (hasLink) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _shareCustomerLink(c),
                                      icon: const Icon(
                                        Icons.ios_share_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        '링크 공유하기',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: SoriTokens.primary,
                                        side: const BorderSide(
                                          color: SoriTokens.primary,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () => showCustomerLinkPopup(
                                      context,
                                      chart: chart!,
                                      store: widget.store,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: SoriTokens.primary,
                                      side: const BorderSide(
                                        color: SoriTokens.primary,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.qr_code_2_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
