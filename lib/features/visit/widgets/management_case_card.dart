import 'package:flutter/material.dart';

import '../../../models/customer_chart.dart';
import '../../../theme/sori_tokens.dart';
import '../../../widgets/before_after_slider.dart';
import '../home_visual_tokens.dart';

/// PRD v7.0 ④ — 관리 케이스 카드.
///
/// 과거 기록 열람이 아니라 대면 상담용 신뢰 구축 도구다. 회차·케어명·
/// 고객 키워드가 항상 함께 보여야 하고, 이미지는 좌우 드래그로 비교된다.
class ManagementCaseCard extends StatelessWidget {
  const ManagementCaseCard({
    super.key,
    required this.chart,
    required this.bookmarked,
    required this.onBookmark,
    required this.onExpand,
  });

  final CustomerChart chart;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final caption = chart.metadataSummaryLine.trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(
        HomeVisualTokens.sectionGutter,
        0,
        HomeVisualTokens.sectionGutter,
        HomeVisualTokens.caseCardGap,
      ),
      decoration: BoxDecoration(
        color: HomeVisualTokens.caseCardFill,
        borderRadius:
            BorderRadius.circular(HomeVisualTokens.caseCardRadius),
        boxShadow: const [HomeVisualTokens.caseCardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                Text(
                  '${chart.visitNumber} 회차',
                  style: const TextStyle(
                    fontSize: HomeVisualTokens.caseVisitSize,
                    fontWeight: FontWeight.w600,
                    color: HomeVisualTokens.dateTextColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    chart.serviceMenuLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: HomeVisualTokens.caseHeaderSize,
                      fontWeight: FontWeight.w700,
                      color: HomeVisualTokens.dateTextColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onBookmark,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    bookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 20,
                    color: HomeVisualTokens.dateTextColor,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              BeforeAfterSlider(
                aspectRatio: 4 / 3,
                borderRadius: BorderRadius.zero,
                before: ChartImagePane(
                  url: chart.beforeImageUrl,
                  fallbackLabel: 'Before',
                  tone: SoriTokens.primary,
                ),
                after: ChartImagePane(
                  url: chart.afterImageUrl,
                  fallbackLabel: 'After',
                  tone: SoriTokens.textSecondary,
                ),
              ),
              const Positioned(left: 10, top: 10, child: _Pill('Before')),
              const Positioned(right: 10, top: 10, child: _Pill('After')),
              Positioned(
                right: 10,
                bottom: 10,
                child: _ExpandButton(onTap: onExpand),
              ),
            ],
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Text(
                caption,
                style: const TextStyle(
                  fontSize: HomeVisualTokens.caseCaptionSize,
                  color: HomeVisualTokens.caseCaptionColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HomeVisualTokens.casePillFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: HomeVisualTokens.casePillTextSize,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  const _ExpandButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeVisualTokens.casePillFill,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            Icons.open_in_full_rounded,
            size: 15,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
