import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/sori_tokens.dart';

/// Content filter chip — selected charcoal fill, unselected thin gray border.
///
/// Icons are optional and only rendered when [icon] is provided (or [showIcon]).
class SoriContentChip extends StatelessWidget {
  const SoriContentChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.showIcon = false,
    this.count,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool showIcon;
  final String? count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final useIcon = showIcon && icon != null;
    final hPad = dense ? 10.0 : 12.0;
    final vPad = dense ? 6.0 : 7.0;

    return Material(
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
        customBorder: const StadiumBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
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
                  size: 14,
                  color: selected
                      ? SoriTokens.onPrimary
                      : SoriTokens.textSecondary,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
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
