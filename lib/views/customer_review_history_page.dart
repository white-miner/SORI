import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';
import '../widgets/sori_empty_state.dart';
import 'ikea_review_composer_page.dart';

/// 고객용 리뷰 작성/내역 화면.
class CustomerReviewHistoryPage extends StatelessWidget {
  const CustomerReviewHistoryPage({super.key, required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final customerId = store.session?.customerId;
    final reviews = customerId == null
        ? <CustomerReview>[]
        : store.reviews.where((r) => r.customerId == customerId).toList();

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('내 소통 리뷰'),
        backgroundColor: Colors.white,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: reviews.isEmpty
          ? const SoriEmptyState(
              icon: Icons.rate_review_outlined,
              message: '아직 작성된 리뷰가 없습니다',
              subtitle: '방문 확인 후 리뷰를 조립하면\n여기에 내역이 쌓여요',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: reviews.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => IkeaReviewComposerPage(store: store),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text(
                      '새 리뷰 조립하기',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                }
                final review = reviews[index - 1];
                CustomerChart? chart;
                for (final c in store.charts) {
                  if (c.id == review.chartId) {
                    chart = c;
                    break;
                  }
                }
                return SoriCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: SoriTokens.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              chart == null
                                  ? '리뷰'
                                  : '${chart.visitNumber}회차',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: SoriTokens.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            review.status.dbValue,
                            style: const TextStyle(
                              fontSize: 11,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        review.displayText.isEmpty
                            ? (review.puzzleSelections.isEmpty
                                ? '작성 중인 리뷰'
                                : review.puzzleSelections.join(' · '))
                            : review.displayText,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
