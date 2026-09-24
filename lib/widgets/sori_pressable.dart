import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// Shared button/image response: hover or press scale 1.02 · release ~180ms.
/// map pan / sheet drag / list scroll에는 쓰지 않는다.
class SoriPressable extends StatefulWidget {
  const SoriPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;

  @override
  State<SoriPressable> createState() => _SoriPressableState();
}

class _SoriPressableState extends State<SoriPressable> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: (_pressed || _hovered) && widget.enabled ? 1.02 : 1.0,
      duration: Duration(
        milliseconds: _pressed
            ? SoriTokens.motionPressMs
            : SoriTokens.motionReleaseMs,
      ),
      curve: Curves.easeOut,
      child: widget.child,
    );

    return Semantics(
      button: widget.onTap != null,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        onEnter: widget.enabled && widget.onTap != null
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: widget.enabled && widget.onTap != null
            ? (_) => setState(() => _hovered = false)
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled && widget.onTap != null
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: widget.enabled && widget.onTap != null
              ? (_) {
                  setState(() => _pressed = false);
                  widget.onTap?.call();
                }
              : null,
          onTapCancel: () => setState(() => _pressed = false),
          child: child,
        ),
      ),
    );
  }
}
