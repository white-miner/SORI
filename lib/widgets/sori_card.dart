import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

class SoriCard extends StatelessWidget {
  const SoriCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: SoriTokens.card(),
      child: child,
    );
    if (onTap == null && onLongPress == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(SoriTokens.radiusLg),
        child: content,
      ),
    );
  }
}
