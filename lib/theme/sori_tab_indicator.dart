import 'package:flutter/material.dart';

import '../features/visit/sori_stage_folder_tabs.dart';
import 'sori_tokens.dart';

/// Deprecated chip fill — kept transparent so stray imports cannot paint dark pills.
const BoxDecoration soriTabSelectedChip = BoxDecoration(
  color: Colors.transparent,
);

/// Deprecated idle chip fill — transparent; home underline style is the standard.
const BoxDecoration soriTabUnselectedChip = BoxDecoration(
  color: Colors.transparent,
);

/// Legacy alias — no longer a dark capsule.
const BoxDecoration soriTabCapsuleIndicator = soriTabSelectedChip;

/// Material [TabBar] theme — home charcoal underline (matches [SoriStageFolderTabs]).
TabBarThemeData get soriTabBarTheme => const TabBarThemeData(
      overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      labelColor: SoriTokens.textCharcoal,
      unselectedLabelColor: Color(0xFF6E6E73),
      indicatorColor: SoriTokens.textCharcoal,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(width: 2.5, color: SoriTokens.textCharcoal),
        borderRadius: BorderRadius.all(Radius.circular(999)),
        insets: EdgeInsets.zero,
      ),
      // Label-width underline (Weverse), not full tab slot.
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      dividerHeight: 0,
      labelStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.1,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0.15,
      ),
      labelPadding: EdgeInsets.symmetric(horizontal: 12),
    );

/// Top tabs matching home [SoriStageFolderTabs] (charcoal underline, no dark pills).
///
/// Wraps the home component so typography and underline tokens cannot drift.
/// Optional [badges] are forwarded for red count pills (e.g. director hub).
/// White rail + mild top inset unify with the logo app-bar row.
class SoriYoutubeTabBar extends StatelessWidget {
  const SoriYoutubeTabBar({
    super.key,
    required this.controller,
    required this.labels,
    this.badges,
    this.allowScroll = false,
    this.padding = const EdgeInsets.only(top: SoriStageFolderTabs.topInset),
  });

  final TabController controller;
  final List<String> labels;

  /// Optional per-tab badge counts (0 / null = hidden).
  final List<int>? badges;

  /// Forwarded to [SoriStageFolderTabs.allowScroll] (e.g. My page 6 tabs).
  final bool allowScroll;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SoriTokens.canvas,
      child: Padding(
        padding: padding,
        child: SoriStageFolderTabs(
          controller: controller,
          labels: labels,
          badges: badges,
          allowScroll: allowScroll,
        ),
      ),
    );
  }
}
