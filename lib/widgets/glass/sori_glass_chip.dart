import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/sori_tokens.dart';
import 'sori_glass_tokens.dart';

/// L2 pseudo-glass icon chip — 44px max touch, semantic active tint.
class SoriGlassChip extends StatefulWidget {
  const SoriGlassChip({
    super.key,
    required this.icon,
    required this.semantic,
    required this.onTap,
    this.onLongPress,
    this.active = false,
    this.loading = false,
    this.size = SoriGlassTokens.chipMd,
    this.iconSize,
    this.tooltip,
    this.semanticLabel,
  });

  final IconData icon;
  final SoriGlassSemantic semantic;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool active;
  final bool loading;
  final double size;
  final double? iconSize;
  final String? tooltip;
  final String? semanticLabel;

  @override
  State<SoriGlassChip> createState() => _SoriGlassChipState();
}

class _SoriGlassChipState extends State<SoriGlassChip> {
  bool _pressed = false;

  void _handleTap() {
    if (widget.loading || widget.onTap == null) return;
    HapticFeedback.lightImpact();
    widget.onTap!();
  }

  void _handleLongPress() {
    if (widget.loading) return;
    HapticFeedback.mediumImpact();
    (widget.onLongPress ?? widget.onTap)?.call();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.iconSize ?? (widget.size >= 40 ? 20 : 18);
    final radius = widget.size / 2;
    final color = SoriGlassTokens.iconColor(widget.semantic, active: widget.active);

    Widget chip = AnimatedScale(
      scale: _pressed ? 0.94 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: widget.size,
        height: widget.size,
        decoration: SoriGlassTokens.pseudoChipDecoration(
          radius: radius,
          semantic: widget.semantic,
          active: widget.active,
          pressed: _pressed,
        ),
        child: Center(
          child: widget.loading
              ? SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(widget.icon, size: iconSize, color: color),
        ),
      ),
    );

    chip = Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.loading ? null : _handleTap,
          onLongPress: widget.loading ? null : _handleLongPress,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          customBorder: const CircleBorder(),
          child: chip,
        ),
      ),
    );

    if (widget.tooltip != null) {
      chip = Tooltip(message: widget.tooltip!, child: chip);
    }
    return chip;
  }
}

/// Icon + count capsule chip for like/comment groups.
class SoriGlassMetricChip extends StatelessWidget {
  const SoriGlassMetricChip({
    super.key,
    required this.icon,
    required this.semantic,
    required this.count,
    required this.onTap,
    this.onLongPress,
    this.active = false,
    this.compact = false,
  });

  final IconData icon;
  final SoriGlassSemantic semantic;
  final int count;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chipSize = compact ? SoriGlassTokens.chipSm : SoriGlassTokens.chipMd;
    final countStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: compact ? 11.5 : 12.5,
      color: SoriTokens.textPrimary,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SoriGlassChip(
          icon: icon,
          semantic: semantic,
          active: active,
          onTap: onTap,
          onLongPress: onLongPress,
          size: chipSize,
          semanticLabel: '$count',
        ),
        const SizedBox(width: 4),
        Text('$count', style: countStyle),
      ],
    );
  }
}
