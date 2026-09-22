import 'package:flutter/material.dart';

import '../../../models/customer_chart.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/sori_tokens.dart';
import '../../../widgets/before_after_slider.dart';
import '../home_visual_tokens.dart';

/// 완성된 B&A 게시물. 전후는 사진 위에서 바로 비교하고,
/// 케어명과 키워드 칩도 사진 위에 둔다.
class ManagementCaseCard extends StatelessWidget {
  const ManagementCaseCard({
    super.key,
    required this.chart,
    required this.bookmarked,
    required this.onBookmark,
    required this.onExpand,
    this.onHideFromHome,
  });

  final CustomerChart chart;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onExpand;
  final VoidCallback? onHideFromHome;

  @override
  Widget build(BuildContext context) {
    final chips = _keywordChips(chart);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        HomeVisualTokens.sectionGutter,
        0,
        HomeVisualTokens.sectionGutter,
        HomeVisualTokens.caseCardGap,
      ),
      decoration: BoxDecoration(
        color: HomeVisualTokens.caseCardFill,
        borderRadius: BorderRadius.circular(HomeVisualTokens.caseCardRadius),
        boxShadow: const [HomeVisualTokens.caseCardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          BeforeAfterSlider(
            aspectRatio: 4 / 5,
            maxHeight: 720,
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
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SORI CASE · ${chart.visitNumber}회차',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFFD1D1D6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          chart.serviceMenuLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.display(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.05,
                          ),
                        ),
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final chip in chips)
                                _KeywordChip(label: chip),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OverlayIconButton(
                      tooltip: '크게 보기',
                      icon: Icons.open_in_full_rounded,
                      onTap: onExpand,
                    ),
                    const SizedBox(height: 8),
                    _OverlayIconButton(
                      tooltip: '즐겨찾기',
                      icon: bookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      onTap: onBookmark,
                    ),
                    if (onHideFromHome != null) ...[
                      const SizedBox(height: 8),
                      _MoreOnPhoto(onHideFromHome: onHideFromHome!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _keywordChips(CustomerChart chart) {
  final chips = <String>[
    if (chart.age != null) '만 ${chart.age}세',
    if (chart.gender.isNotEmpty) chart.gender,
    if (chart.skinType.isNotEmpty) chart.skinType,
  ];
  for (final raw in chart.concerns.split('/')) {
    final t = raw.trim();
    if (t.isEmpty || chips.contains(t)) continue;
    chips.add(t);
  }
  return chips;
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _MoreOnPhoto extends StatelessWidget {
  const _MoreOnPhoto({required this.onHideFromHome});

  final VoidCallback onHideFromHome;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: PopupMenuButton<String>(
        tooltip: '더보기',
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_horiz_rounded,
          size: 18,
          color: Colors.white,
        ),
        onSelected: (value) {
          if (value == 'hide_home') onHideFromHome();
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'hide_home',
            child: Text('홈에서 숨기기'),
          ),
        ],
      ),
    );
  }
}
