import 'package:flutter/material.dart';

import '../../../widgets/press_bounce.dart';

/// 케어 타이머 컨트롤 — 재생/일시정지 토글 + 다음 + 음소거 + 확대.
class CareTimerFloatingBar extends StatelessWidget {
  const CareTimerFloatingBar({
    super.key,
    required this.isPlaying,
    required this.isMuted,
    required this.isImmersive,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onToggleImmersive,
    this.onSkipNext,
    this.vertical = false,
    this.onCollapse,
    this.showCollapse = false,
    this.enabled = true,
    this.canSkip = false,
    @Deprecated('정지 버튼은 제거됨. 재생/일시정지 토글을 사용한다.')
    this.onStop,
  });

  final bool isPlaying;
  final bool isMuted;
  final bool isImmersive;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleImmersive;
  final VoidCallback? onSkipNext;
  final bool vertical;
  final VoidCallback? onCollapse;
  final bool showCollapse;
  final bool enabled;
  final bool canSkip;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      _ControlDot(
        icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        onTap: onTogglePlay,
        tooltip: isPlaying ? '일시정지' : '재생',
      ),
      _ControlDot(
        key: const Key('care-skip-next'),
        icon: Icons.skip_next_rounded,
        onTap: enabled && canSkip ? onSkipNext : null,
        tooltip: '다음 스텝',
      ),
      if (showCollapse && onCollapse != null)
        _ControlDot(
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: onCollapse!,
          tooltip: '바 숨기기',
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
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PressBounce(
      enabled: onTap != null,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color:
              onTap == null ? const Color(0xFF9A9A9E) : const Color(0xFF111111),
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
      ),
    );
  }
}
