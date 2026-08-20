import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// Weverse-style floating pill bottom navigation (dark).
class FloatingPillNav extends StatelessWidget {
  const FloatingPillNav({
    super.key,
    required this.currentIndex,
    required this.isDirector,
    required this.reviewLabel,
    required this.onTap,
  });

  final int currentIndex;
  final bool isDirector;
  final String reviewLabel;
  final ValueChanged<int> onTap;

  /// #121214 @ 90%
  static const Color _barBg = Color(0xE6121214);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final items = isDirector
        ? const [
            (Icons.home_outlined, Icons.home_rounded, '홈', 0),
            (Icons.people_outline, Icons.people_rounded, '고객', 1),
            (Icons.rate_review_outlined, Icons.rate_review_rounded, '리뷰', 2),
            (Icons.photo_library_outlined, Icons.photo_library_rounded, '케이스', 3),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이', 4),
          ]
        : const [
            (Icons.home_outlined, Icons.home_rounded, '홈', 0),
            (Icons.spa_outlined, Icons.spa_rounded, '케어', 1),
            (Icons.rate_review_outlined, Icons.rate_review_rounded, '리뷰', 2),
            (Icons.photo_library_outlined, Icons.photo_library_rounded, '케이스', 3),
            (Icons.person_outline_rounded, Icons.person_rounded, '마이', 4),
          ];

    final labels = [
      items[0].$3,
      items[1].$3,
      reviewLabel.length > 4 ? '리뷰' : reviewLabel,
      items[3].$3,
      items[4].$3,
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: _barBg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: SoriTokens.outlinePurple,
                width: SoriTokens.outlineWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final selected = currentIndex == items[i].$4;
                return Expanded(
                  child: _PillNavItem(
                    icon: items[i].$1,
                    activeIcon: items[i].$2,
                    label: labels[i],
                    selected: selected,
                    onTap: () => onTap(items[i].$4),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  const _PillNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(
                      color: SoriTokens.outlinePurple,
                      width: 1.4,
                    )
                  : null,
              color: selected
                  ? SoriTokens.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
            child: Icon(
              selected ? activeIcon : icon,
              size: 22,
              color: selected ? SoriTokens.primary : SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? SoriTokens.primary : SoriTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
