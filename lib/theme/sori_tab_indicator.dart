import 'package:flutter/material.dart';

import 'sori_tokens.dart';

/// Active chip — deep charcoal fill, white label.
const BoxDecoration soriTabSelectedChip = BoxDecoration(
  color: Color(0xFF111111),
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

/// Inactive chip — light gray fill.
const BoxDecoration soriTabUnselectedChip = BoxDecoration(
  color: Color(0xFFF1F1F1),
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

/// Legacy alias — preferred selected indicator for Material [TabBar].
const BoxDecoration soriTabCapsuleIndicator = soriTabSelectedChip;

/// Shared TabBar theme — YouTube-style selected dark chip.
TabBarThemeData get soriTabBarTheme => const TabBarThemeData(
      overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      labelColor: Color(0xFFFFFFFF),
      unselectedLabelColor: Color(0xFF111111),
      indicator: soriTabSelectedChip,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      dividerHeight: 0,
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelPadding: EdgeInsets.symmetric(horizontal: 4),
    );

/// YouTube-style chip tabs synced to [TabController] (active = dark, idle = gray).
class SoriYoutubeTabBar extends StatelessWidget {
  const SoriYoutubeTabBar({
    super.key,
    required this.controller,
    required this.labels,
    this.badges,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
  });

  final TabController controller;
  final List<String> labels;
  /// Optional per-tab badge counts (0 / null = hidden).
  final List<int>? badges;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _SoriYoutubeChip(
                  label: labels[i],
                  badge: badges != null && i < badges!.length
                      ? badges![i]
                      : 0,
                  selected: controller.index == i,
                  onTap: () {
                    if (controller.index != i) {
                      controller.animateTo(i);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SoriYoutubeChip extends StatelessWidget {
  const _SoriYoutubeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        selected ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
    return Material(
      color: selected ? const Color(0xFF111111) : const Color(0xFFF1F1F1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: labelColor,
                  height: 1.2,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SoriTokens.systemRed,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: SoriTokens.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
