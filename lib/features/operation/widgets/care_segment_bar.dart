import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/preset_slot_tint.dart';
import 'semantic_signal_theme.dart';

/// PRD v5.2 Phase B — preset step chips with ▶/⏸ and pulsating active step.
class CareSegmentBar extends StatelessWidget {
  const CareSegmentBar({
    super.key,
    required this.steps,
    required this.tint,
    required this.currentIndex,
    required this.isArmed,
    required this.isRunning,
    required this.isPaused,
    required this.onTogglePlayback,
    this.vertical = false,
    this.stepRemainingSeconds = 0,
  });

  final List<CareProgramStep> steps;
  final PresetSlotTint tint;
  final int currentIndex;
  final bool isArmed;
  final bool isRunning;
  final bool isPaused;
  final VoidCallback onTogglePlayback;
  final bool vertical;
  final int stepRemainingSeconds;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final chips = List.generate(steps.length, (i) {
      final step = steps[i];
      final isActive = isRunning && !isPaused && i == currentIndex;
      final isComplete = isRunning && i < currentIndex;
      final showPlay = i == 0 && (isArmed || isRunning);
      final displayTime = isActive && stepRemainingSeconds > 0
          ? _formatMmSs(stepRemainingSeconds)
          : _formatPlanned(step.minutes);

      return _SegmentChip(
        label: step.label,
        timeLabel: displayTime,
        color: tint.stepColor(i, steps.length),
        isActive: isActive,
        isComplete: isComplete,
        showPlayControl: showPlay,
        isPlaying: isRunning && !isPaused && i == 0,
        onTogglePlayback: onTogglePlayback,
      );
    });

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            chips[i],
            if (i < chips.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            chips[i],
            if (i < chips.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  static String _formatPlanned(int minutes) {
    return '${minutes.toString().padLeft(2, '0')}:00';
  }

  static String _formatMmSs(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _SegmentChip extends StatefulWidget {
  const _SegmentChip({
    required this.label,
    required this.timeLabel,
    required this.color,
    required this.isActive,
    required this.isComplete,
    required this.showPlayControl,
    required this.isPlaying,
    required this.onTogglePlayback,
  });

  final String label;
  final String timeLabel;
  final Color color;
  final bool isActive;
  final bool isComplete;
  final bool showPlayControl;
  final bool isPlaying;
  final VoidCallback onTogglePlayback;

  @override
  State<_SegmentChip> createState() => _SegmentChipState();
}

class _SegmentChipState extends State<_SegmentChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isActive) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _SegmentChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isActive && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseOpacity = widget.isComplete ? 0.45 : 1.0;

    Widget chip = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final scale = widget.isActive ? 1.0 + _pulse.value * 0.06 : 1.0;
        final glow = widget.isActive
            ? 0.15 + _pulse.value * 0.30
            : (widget.isComplete ? 0.05 : 0.12);
        return Transform.scale(
          scale: scale,
          child: Container(
            constraints: const BoxConstraints(minWidth: 88),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.22 * baseOpacity),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isActive
                    ? SemanticSignalTheme.red.withValues(alpha: 0.55)
                    : widget.color.withValues(alpha: 0.55 * baseOpacity),
                width: widget.isActive ? 1.8 : 1,
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: glow),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showPlayControl) ...[
                _PlayPauseButton(
                  isPlaying: widget.isPlaying,
                  color: widget.color,
                  onTap: widget.onTogglePlayback,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.timeLabel,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111).withValues(alpha: baseOpacity),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (widget.isComplete) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: widget.color.withValues(alpha: 0.85),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3A3A3C).withValues(alpha: baseOpacity),
            ),
          ),
        ],
      ),
    );

    return chip;
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.color,
    required this.onTap,
  });

  final bool isPlaying;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 18,
            color: const Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}

/// Overtime virtual segment chip (amber).
class CareOvertimeSegmentChip extends StatelessWidget {
  const CareOvertimeSegmentChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF9500).withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        '정성 시간',
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFF9500),
        ),
      ),
    );
  }
}
