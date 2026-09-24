import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/sori_tokens.dart';

/// Content filter chip — selected charcoal fill, unselected thin gray border.
///
/// Optional [iconColor] keeps category-tint icons (region/market) while matching
/// stadium / border / fill with the shared Weverse content-chip language.
class SoriContentChip extends StatelessWidget {
  const SoriContentChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.showIcon = false,
    this.iconColor,
    this.count,
    this.dense = false,
    this.haptic = true,
    this.surfaceKey,
    this.inkKey,
    this.iconKey,
    this.labelKey,
    this.countKey,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool showIcon;
  /// Unselected leading-icon color (e.g. category tint). Selected uses onPrimary.
  final Color? iconColor;
  final String? count;
  final bool dense;
  final bool haptic;
  final Key? surfaceKey;
  final Key? inkKey;
  final Key? iconKey;
  final Key? labelKey;
  final Key? countKey;

  @override
  Widget build(BuildContext context) {
    final useIcon = showIcon && icon != null;
    final hPad = dense ? 10.0 : 12.0;
    final vPad = dense ? 6.0 : 7.0;
    final idleIcon =
        iconColor ?? SoriTokens.textSecondary;

    return Material(
      key: surfaceKey,
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
        key: inkKey,
        customBorder: const StadiumBorder(),
        onTap: () {
          if (haptic) HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (useIcon) ...[
                Icon(
                  icon,
                  key: iconKey,
                  size: 14,
                  color: selected ? SoriTokens.onPrimary : idleIcon,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                key: labelKey,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: dense ? 12 : 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? SoriTokens.onPrimary
                      : SoriTokens.textPrimary,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  count!,
                  key: countKey,
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
