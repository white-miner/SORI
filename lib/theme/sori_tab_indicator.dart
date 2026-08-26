import 'package:flutter/material.dart';

import 'sori_tokens.dart';

/// YouTube-style light gray capsule behind the selected tab label.
class SoriCapsuleTabIndicator extends Decoration {
  const SoriCapsuleTabIndicator({
    this.color = SoriTokens.tabCapsuleBg,
    this.radius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  });

  final Color color;
  final double radius;
  final EdgeInsets padding;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _SoriCapsuleTabIndicatorPainter(
      color: color,
      radius: radius,
      padding: padding,
      onChanged: onChanged,
    );
  }
}

class _SoriCapsuleTabIndicatorPainter extends BoxPainter {
  _SoriCapsuleTabIndicatorPainter({
    required this.color,
    required this.radius,
    required this.padding,
    VoidCallback? onChanged,
  }) : super(onChanged);

  final Color color;
  final double radius;
  final EdgeInsets padding;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    final size = configuration.size!;
    final rect = offset & size;
    final inset = Rect.fromLTWH(
      rect.left + padding.left,
      rect.top + padding.top,
      rect.width - padding.horizontal,
      rect.height - padding.vertical,
    );
    final rrect = RRect.fromRectAndRadius(inset, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = color);
  }
}

/// Shared TabBar defaults — capsule indicator + readable charcoal labels.
TabBarThemeData get soriTabBarTheme => TabBarThemeData(
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      labelColor: SoriTokens.textCharcoal,
      unselectedLabelColor: SoriTokens.tabUnselected,
      indicator: const SoriCapsuleTabIndicator(),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
    );
