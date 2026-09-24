import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import '../../utils/our_area_category.dart';

/// Shared shop controls and marker language for Region and Market screens.
abstract final class RegionMapShopChrome {
  RegionMapShopChrome._();

  static Color categoryColor(String key) {
    switch (OurAreaCategory.mapRaw(key)) {
      case OurAreaCategory.skin:
        return const Color(0xFFE77C78);
      case OurAreaCategory.hair:
        return const Color(0xFF4F86C6);
      case OurAreaCategory.nail:
        return const Color(0xFFE58BA8);
      case OurAreaCategory.barber:
        return const Color(0xFF55A7A0);
      case OurAreaCategory.tattoo:
        return const Color(0xFF64748B);
      case OurAreaCategory.makeup:
        return const Color(0xFFD7A45B);
      case OurAreaCategory.permanent:
        return const Color(0xFF9B7EBD);
      case OurAreaCategory.all:
        return SoriTokens.primary;
      default:
        return neutral;
    }
  }

  static IconData categoryIcon(String key) {
    switch (OurAreaCategory.mapRaw(key)) {
      case OurAreaCategory.skin:
        return Icons.face_retouching_natural;
      case OurAreaCategory.hair:
        return Icons.content_cut_rounded;
      case OurAreaCategory.nail:
        return Icons.back_hand_outlined;
      case OurAreaCategory.barber:
        return Icons.content_cut;
      case OurAreaCategory.tattoo:
        return Icons.brush_outlined;
      case OurAreaCategory.permanent:
        return Icons.spa_outlined;
      case OurAreaCategory.makeup:
        return Icons.brush;
      case OurAreaCategory.all:
        return Icons.grid_view_rounded;
      default:
        return Icons.storefront_outlined;
    }
  }

  static const Color neutral = Color(0xFF94A3B8);
  static const Color selectedBorder = Color(0xFF22232A);
  static const Color selectedRing = Color(0xFF22232A);
}

class RegionMapShopMarker extends StatelessWidget {
  const RegionMapShopMarker({
    super.key,
    this.categoryKey = OurAreaCategory.other,
    this.selected = false,
    this.size = 22,
  });

  final String categoryKey;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.08 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Container(
        width: size + 8,
        height: size + 8,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? RegionMapShopChrome.selectedRing : Colors.white,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? .18 : .10),
              blurRadius: selected ? 8 : 4,
              spreadRadius: selected ? 1 : 0,
            ),
          ],
        ),
        child: Icon(
          Icons.storefront_outlined,
          size: size,
          color: RegionMapShopChrome.categoryColor(categoryKey),
        ),
      ),
    );
  }
}

class RegionMapCenterMarker extends StatelessWidget {
  const RegionMapCenterMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: RegionMapShopChrome.selectedRing, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: const Icon(Icons.my_location_rounded, color: SoriTokens.primary, size: 22),
    );
  }
}

class RegionMapCategoryChip extends StatelessWidget {
  const RegionMapCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.categoryKey = OurAreaCategory.other,
    this.showIcon = false,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String categoryKey;
  final bool showIcon;
  final String? count;

  @override
  Widget build(BuildContext context) {
    // Tag category chips only (showIcon) so radius chips do not collide on keys.
    final tag = showIcon ? categoryKey : null;
    return Material(
      key: tag == null ? null : Key('region-category-surface-$tag'),
      color: selected ? SoriTokens.chipSelectedFill : SoriTokens.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? SoriTokens.chipSelectedFill
              : SoriTokens.chipUnselectedBorder,
          width: 1,
        ),
      ),
      child: InkWell(
        key: tag == null ? null : Key('region-shop-category-$tag'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(
                  RegionMapShopChrome.categoryIcon(categoryKey),
                  key: Key('region-category-icon-$categoryKey'),
                  size: 14,
                  color: selected
                      ? SoriTokens.onPrimary
                      : RegionMapShopChrome.categoryColor(categoryKey),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                key: tag == null ? null : Key('region-category-label-$tag'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? SoriTokens.onPrimary : SoriTokens.textPrimary,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  count!,
                  key: tag == null ? null : Key('region-category-count-$tag'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? SoriTokens.onPrimary.withValues(alpha: 0.85)
                        : SoriTokens.textSecondary,
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
