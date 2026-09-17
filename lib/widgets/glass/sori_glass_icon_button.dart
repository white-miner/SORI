import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import 'sori_glass_chip.dart';
import 'sori_glass_tokens.dart';

/// L2 pseudo-glass ghost icon — post header, app bar clusters.
class SoriGlassIconButton extends StatelessWidget {
  const SoriGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badgeCount = 0,
    this.size = SoriGlassTokens.chipMd,
    this.iconSize = 20,
    this.semantic = SoriGlassSemantic.neutral,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int badgeCount;
  final double size;
  final double iconSize;
  final SoriGlassSemantic semantic;
  final bool active;

  @override
  Widget build(BuildContext context) {
    Widget chip = SoriGlassChip(
      icon: icon,
      semantic: semantic,
      active: active,
      size: size,
      iconSize: iconSize,
      onTap: onPressed,
      tooltip: tooltip,
    );

    if (badgeCount > 0) {
      chip = Badge(
        backgroundColor: SoriTokens.systemRed,
        offset: const Offset(6, -4),
        label: Text(
          badgeCount > 9 ? '9+' : '$badgeCount',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        child: chip,
      );
    }

    return chip;
  }
}
