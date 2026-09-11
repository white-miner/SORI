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

/// AppBar action cluster — **blur 없음** (PillNav가 화면당 glass 1개).
/// 반투명 fill + border만으로 floating tool 인상 유지.
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
      tier: SoriGlassTier.l2Control,
      enableBlur: false,
      fill: Colors.white.withValues(alpha: 0.92),
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
          hoverColor: SoriTokens.brand.withValues(alpha: 0.08),
          splashColor: SoriTokens.brand.withValues(alpha: 0.12),
          highlightColor: SoriTokens.brand.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: Duration(milliseconds: SoriTokens.motionReleaseMs),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlight
                  ? SoriTokens.brand.withValues(alpha: 0.10)
                  : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              size: 22,
              color: highlight ? SoriTokens.brand : SoriTokens.textPrimary,
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
