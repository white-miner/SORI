import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';

/// Director picks a shared B/A chart to link as seminar source case.
Future<String?> showSeminarChartPickerSheet(
  BuildContext context, {
  required SoriStore store,
  String? selectedChartId,
}) {
  final shopId = store.shop.id.trim();
  final charts = store.charts
      .where(
        (c) =>
            c.caseShared &&
            c.isConsentSigned &&
            (shopId.isEmpty || c.shopId == shopId),
      )
      .toList()
    ..sort((a, b) {
      final ad = a.feedPostedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.feedPostedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

  return showSoriSolidBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SoriSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '원본 B/A 게시물 불러오기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '이 세미나를 열게 된 케이스를 선택하세요. 상세 페이지에 피드 카드로 노출됩니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (charts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '공유된 B/A 게시물이 없습니다. 먼저 케이스를 커뮤니티에 공유해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: SoriTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: charts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final chart = charts[index];
                  final selected = chart.id == selectedChartId;
                  return _ChartPickTile(
                    chart: chart,
                    selected: selected,
                    onTap: () => Navigator.pop(ctx, chart.id),
                  );
                },
              ),
            ),
          if (selectedChartId != null && selectedChartId.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text(
                '연동 해제',
                style: TextStyle(
                  color: SoriTokens.systemRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ChartPickTile extends StatelessWidget {
  const _ChartPickTile({
    required this.chart,
    required this.selected,
    required this.onTap,
  });

  final CustomerChart chart;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = chart.afterImageUrl?.trim().isNotEmpty == true
        ? chart.afterImageUrl!
        : chart.beforeImageUrl;
    final title = chart.careName.trim().isNotEmpty
        ? chart.careName.trim()
        : chart.treatmentSummary.trim();

    return Material(
      color: selected ? SoriTokens.primarySoft : SoriTokens.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (thumb != null && thumb.startsWith('http'))
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    thumb,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ThumbFallback(),
                  ),
                )
              else
                const _ThumbFallback(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'B/A 케이스' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (chart.treatmentSummary.trim().isNotEmpty)
                      Text(
                        chart.treatmentSummary.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: SoriTokens.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: SoriTokens.surfaceOverlay,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.photo_library_outlined, color: SoriTokens.textTertiary),
    );
  }
}
