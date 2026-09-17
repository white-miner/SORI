import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// Pinned tab bar for [CustomScrollView] (single scroll tree, no NestedScrollView).
class SoriSliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  SoriSliverTabBarDelegate({
    required this.tabBar,
    this.backgroundColor = SoriTokens.background,
  });

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant SoriSliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
