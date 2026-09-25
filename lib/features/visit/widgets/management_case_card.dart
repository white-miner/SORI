import 'package:flutter/material.dart';

import '../../../models/customer_chart.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/sori_tokens.dart';
import '../../../widgets/before_after_slider.dart';
import '../../../widgets/glass/sori_glass_style.dart';
import '../home_visual_tokens.dart';

/// 완성된 B&A 게시물. 전후는 사진 위에서 바로 비교하고,
/// 케어명과 키워드 칩도 사진 위에 둔다.
///
/// [glass]가 true면 DESK 전용 두꺼운 글래스 프레임 룩으로 그린다
/// (시각만 다르고 데이터·슬라이더·탭 동작은 동일). 기본값 false는 기존 룩.
class ManagementCaseCard extends StatelessWidget {
  const ManagementCaseCard({
    super.key,
    required this.chart,
    required this.bookmarked,
    required this.onBookmark,
    required this.onExpand,
    this.onHideFromHome,
    this.glass = false,
  });

  final CustomerChart chart;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onExpand;
  final VoidCallback? onHideFromHome;

  /// DESK 전용 글래스 룩 (opt-in).
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final chips = _keywordChips(chart);
    if (glass) return _buildGlass(chips);

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

  Widget _buildGlass(List<String> chips) {
    return SoriGlassBlock(
      key: const Key('management-case-card-glass'),
      margin: const EdgeInsets.fromLTRB(
        HomeVisualTokens.sectionGutter,
        0,
        HomeVisualTokens.sectionGutter,
        HomeVisualTokens.caseCardGap,
      ),
      child: Stack(
        children: [
          BeforeAfterSlider(
            aspectRatio: 4 / 5,
            maxHeight: 720,
            borderRadius: BorderRadius.zero,
            showCornerTags: false,
            // 각 절반에 같은 페이드를 넣어 슬라이더 분할을 그대로 따라간다.
            before: SoriGlassFade(
              child: ChartImagePane(
                url: chart.beforeImageUrl,
                fallbackLabel: 'Before',
                tone: SoriTokens.primary,
              ),
            ),
            after: SoriGlassFade(
              child: ChartImagePane(
                url: chart.afterImageUrl,
                fallbackLabel: 'After',
                tone: SoriTokens.textSecondary,
              ),
            ),
          ),
          const Positioned(
            left: 10,
            top: 10,
            child: IgnorePointer(child: _GlassCornerTag(label: 'Before')),
          ),
          const Positioned(
            right: 10,
            top: 10,
            child: IgnorePointer(child: _GlassCornerTag(label: 'After')),
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
                      key: const Key('management-case-card-glass-text'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SORI CASE · ${chart.visitNumber}회차',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xE6FFFFFF),
                            shadows: SoriGlassStyle.textShadow,
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
                          ).copyWith(shadows: SoriGlassStyle.textShadow),
                        ),
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final chip in chips)
                                _KeywordChip(label: chip, glass: true),
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
                      glass: true,
                    ),
                    const SizedBox(height: 8),
                    _OverlayIconButton(
                      tooltip: '즐겨찾기',
                      icon: bookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      onTap: onBookmark,
                      glass: true,
                    ),
                    if (onHideFromHome != null) ...[
                      const SizedBox(height: 8),
                      _MoreOnPhoto(
                        onHideFromHome: onHideFromHome!,
                        glass: true,
                      ),
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
  const _KeywordChip({required this.label, this.glass = false});

  final String label;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: glass
          ? SoriGlassStyle.controlDecoration()
          : BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: glass ? SoriGlassStyle.glyphShadow : null,
        ),
      ),
    );
  }
}

/// DESK 글래스 카드의 Before/After 코너 라벨.
class _GlassCornerTag extends StatelessWidget {
  const _GlassCornerTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: SoriGlassStyle.controlDecoration(),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          shadows: SoriGlassStyle.glyphShadow,
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
    this.glass = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: glass ? Colors.transparent : Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 18,
            color: Colors.white,
            shadows: glass ? SoriGlassStyle.glyphShadow : null,
          ),
        ),
      ),
    );
    return Tooltip(
      message: tooltip,
      child: glass
          ? DecoratedBox(
              decoration: SoriGlassStyle.controlDecoration(
                shape: BoxShape.circle,
              ),
              child: button,
            )
          : button,
    );
  }
}

class _MoreOnPhoto extends StatelessWidget {
  const _MoreOnPhoto({required this.onHideFromHome, this.glass = false});

  final VoidCallback onHideFromHome;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final menu = Material(
      color: glass ? Colors.transparent : Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: PopupMenuButton<String>(
        tooltip: '더보기',
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_horiz_rounded,
          size: 18,
          color: Colors.white,
          shadows: glass ? SoriGlassStyle.glyphShadow : null,
        ),
        onSelected: (value) {
          if (value == 'hide_home') onHideFromHome();
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(value: 'hide_home', child: Text('홈에서 숨기기')),
        ],
      ),
    );
    if (!glass) return menu;
    // 글래스 룩에서는 옆 버튼과 같은 40dp 원으로 맞춘다.
    return DecoratedBox(
      decoration: SoriGlassStyle.controlDecoration(shape: BoxShape.circle),
      child: SizedBox(width: 40, height: 40, child: menu),
    );
  }
}
