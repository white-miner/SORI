import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';
import 'sori_glass_overlay.dart';
import 'sori_glass_tokens.dart';

/// One action in the GNB glass pill.
class SoriGlassAppBarItem {
  const SoriGlassAppBarItem({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badgeCount;
}

/// Pill glass container grouping GNB icons — visually separated from the canvas.
class SoriGlassAppBarCluster extends StatelessWidget {
  const SoriGlassAppBarCluster({
    super.key,
    required this.items,
  });

  final List<SoriGlassAppBarItem> items;

  @override
  Widget build(BuildContext context) {
    return SoriGlassOverlay(
      borderRadius: BorderRadius.circular(999),
      tier: SoriGlassTier.l3Overlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              _ClusterIconButton(
                icon: item.icon,
                tooltip: item.tooltip,
                onPressed: item.onPressed,
                badgeCount: item.badgeCount,
              ),
          ],
        ),
      ),
    );
  }
}

class _ClusterIconButton extends StatefulWidget {
  const _ClusterIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  State<_ClusterIconButton> createState() => _ClusterIconButtonState();
}

class _ClusterIconButtonState extends State<_ClusterIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final highlight = _pressed || _hovered;
    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          customBorder: const CircleBorder(),
          hoverColor: SoriTokens.accentLink.withValues(alpha: 0.10),
          splashColor: SoriTokens.accentLink.withValues(alpha: 0.16),
          highlightColor: Colors.black.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlight
                  ? SoriTokens.accentLink.withValues(alpha: 0.10)
                  : Colors.transparent,
              boxShadow: highlight
                  ? [
                      BoxShadow(
                        color: SoriTokens.accentLink.withValues(alpha: 0.22),
                        blurRadius: 10,
                        spreadRadius: -1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              size: 22,
              color: Colors.black87,
              weight: 700,
            ),
          ),
        ),
      ),
    );

    if (widget.badgeCount > 0) {
      button = Badge(
        backgroundColor: SoriTokens.systemRed,
        offset: const Offset(2, 2),
        label: Text(
          widget.badgeCount > 9 ? '9+' : '${widget.badgeCount}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        child: button,
      );
    }

    return Tooltip(message: widget.tooltip, child: button);
  }
}
