import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import 'app_shell_page.dart';
import 'my_app.dart';

/// 고객 홈 — 내 프로필 + 다니는 샵 + 소통하는 리뷰 타임라인.
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key, required this.store});

  final SoriStore store;

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final session = store.session!;
    final customerId = session.customerId;
    final charts = customerId == null
        ? <CustomerChart>[]
        : store.chartsForCustomer(customerId);
    final openCharts = customerId == null
        ? <CustomerChart>[]
        : store.openFeedbackChartsForCustomer(customerId);

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: ModeProfileHeader(
            store: store,
            title: session.name,
            subtitle: '${session.phone} · ${session.providerLabel}',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _ShopCard(store: store),
              const SizedBox(height: 16),
              const Text(
                '소통하는 리뷰',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (charts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        '아직 매칭된 시술 차트가 없어요',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '원장님이 방문 확인 후 보내 준 링크로도 접속할 수 있어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              else
                ...charts.map((chart) {
                  final review = store.reviewForChart(chart.id);
                  final open = chart.hasFeedbackLine;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: open
                            ? () {
                                Navigator.of(context).pushNamed(
                                  '${AppRouter.review}?token=${Uri.encodeQueryComponent(chart.feedbackToken!)}',
                                );
                              }
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('아직 방문 확인 전이라 후기를 작성할 수 없어요'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: open
                                      ? MyApp.soriPurple.withValues(alpha: 0.12)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${chart.visitNumber}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: open
                                        ? MyApp.soriPurple
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chart.careName.isNotEmpty
                                          ? chart.careName
                                          : chart.treatmentSummary,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      open
                                          ? (review == null
                                              ? '후기 작성 가능'
                                              : '후기 ${review.status.name}')
                                          : '방문 확인 대기',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                open ? Icons.chevron_right : Icons.lock_outline,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              if (openCharts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '열려 있는 피드백 ${openCharts.length}건',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final shop = store.shop;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: MyApp.soriPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.storefront, color: MyApp.soriPurple),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내가 다니는 샵',
                  style: TextStyle(fontSize: 11, color: MyApp.soriPurple),
                ),
                const SizedBox(height: 2),
                Text(
                  shop.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  shop.phone ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
