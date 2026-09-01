import 'package:flutter/material.dart';

/// PO v5.2 — circular control cluster for care timer fullscreen.
class CareTimerFloatingBar extends StatelessWidget {
  const CareTimerFloatingBar({
    super.key,
    required this.isPlaying,
    required this.isMuted,
    required this.isImmersive,
    required this.onStop,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onToggleImmersive,
    this.vertical = false,
    this.onCollapse,
    this.showCollapse = false,
  });

  final bool isPlaying;
  final bool isMuted;
  final bool isImmersive;
  final VoidCallback onStop;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleImmersive;
  final bool vertical;
  final VoidCallback? onCollapse;
  final bool showCollapse;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      _ControlDot(
        icon: Icons.stop_rounded,
        onTap: onStop,
        tooltip: '일시정지',
      ),
      if (showCollapse && onCollapse != null)
        _ControlDot(
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: onCollapse!,
          tooltip: '바 숨기기',
        ),
      _ControlDot(
        icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        onTap: onTogglePlay,
        tooltip: isPlaying ? '일시정지' : '재생',
      ),
      _ControlDot(
        icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        onTap: onToggleMute,
        tooltip: isMuted ? '음성 켜기' : '음성 끄기',
      ),
      _ControlDot(
        icon: isImmersive
            ? Icons.fullscreen_exit_rounded
            : Icons.open_in_full_rounded,
        onTap: onToggleImmersive,
        tooltip: isImmersive ? 'UI 표시' : '몰입 모드',
      ),
    ];

    if (vertical) {
      return Material(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                buttons[i],
                if (i < buttons.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          buttons[i],
          if (i < buttons.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }
}

class _ControlDot extends StatelessWidget {
  const _ControlDot({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF111111),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
