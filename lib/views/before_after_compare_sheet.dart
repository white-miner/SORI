import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import 'my_app.dart';

/// 고객 차트 B/A 사진 슬라이더 비교 뷰어.
Future<void> showBeforeAfterCompareSheet({
  required BuildContext context,
  required List<CustomerChart> charts,
}) {
  final pairs = charts
      .where(
        (c) =>
            (c.beforeImageUrl?.trim().isNotEmpty ?? false) &&
            (c.afterImageUrl?.trim().isNotEmpty ?? false),
      )
      .toList();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: pairs.isEmpty ? 0.4 : 0.78,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '관리 경과 비교 (B/A)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: pairs.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              '비교할 Before/After 사진이 아직 없습니다.\n차트에 사진을 첨부한 뒤 다시 열어 주세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                height: 1.4,
                                color: SoriTokens.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          itemCount: pairs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 18),
                          itemBuilder: (_, index) {
                            final chart = pairs[index];
                            final title = chart.careName.isNotEmpty
                                ? chart.careName
                                : '${chart.visitNumber}회차 관리';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${chart.visitNumber}회차 · 슬라이더를 좌우로 움직여 비교하세요',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                BeforeAfterSlider(
                                  height: 240,
                                  before: ChartImagePane(
                                    url: chart.beforeImageUrl,
                                    fallbackLabel: 'Before',
                                    tone: MyApp.soriPurple,
                                  ),
                                  after: ChartImagePane(
                                    url: chart.afterImageUrl,
                                    fallbackLabel: 'After',
                                    tone: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
