import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/preset_slot_tint.dart';

/// PO v5.2 — stacked segment queue (front chip = active step).
class CareStackedSegmentBar extends StatefulWidget {
  const CareStackedSegmentBar({
    super.key,
    required this.steps,
    required this.tint,
    required this.currentIndex,
    required this.isArmed,
    required this.isRunning,
    required this.isPaused,
    required this.stepRemainingSeconds,
    this.vertical = false,
    this.onAddTap,
  });

  final List<CareProgramStep> steps;
  final PresetSlotTint tint;
  final int currentIndex;
  final bool isArmed;
  final bool isRunning;
  final bool isPaused;
  final int stepRemainingSeconds;
  final bool vertical;
  final VoidCallback? onAddTap;

  @override
  State<CareStackedSegmentBar> createState() => _CareStackedSegmentBarState();
}

class _CareStackedSegmentBarState extends State<CareStackedSegmentBar> {
  int? _lastIndex;

  @override
  void didUpdateWidget(covariant CareStackedSegmentBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _lastIndex = oldWidget.currentIndex;
    }
  }

  Color _stepColor(int index) {
    final palette = PresetSlotTint.palette;
    return palette[index % palette.length].color;
  }

  String _timeFor(int index) {
    if (index >= widget.steps.length) return '00:00';
    final step = widget.steps[index];
    final isFront = index == widget.currentIndex;
    if (isFront &&
        widget.isRunning &&
        !widget.isPaused &&
        widget.stepRemainingSeconds > 0) {
      return _formatMmSs(widget.stepRemainingSeconds);
    }
    if (index < widget.currentIndex && widget.isRunning) {
      return '00:00';
    }
    return _formatPlanned(step.minutes);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final start = widget.isArmed
        ? 0
        : widget.currentIndex.clamp(0, widget.steps.length - 1);
    final queue = <int>[
      for (var i = start; i < widget.steps.length; i++) i,
    ].take(4).toList();

    final stack = SizedBox(
      width: widget.vertical ? 92 : null,
      height: widget.vertical ? 200 : 54,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: widget.vertical
            ? Alignment.topCenter
            : Alignment.centerLeft,
        children: [
          for (var depth = queue.length - 1; depth >= 0; depth--)
            AnimatedPositioned(
              key: ValueKey('pos-${queue[depth]}'),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              left: widget.vertical ? 0 : depth * 16.0,
              top: widget.vertical ? depth * 20.0 : 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: widget.vertical
                        ? const Offset(0, 0.35)
                        : const Offset(-0.25, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: _StackedChip(
                  key: ValueKey('chip-${queue[depth]}'),
                  timeLabel: _timeFor(queue[depth]),
                  color: _stepColor(queue[depth]),
                  isFront: depth == 0,
                  compact: depth > 0,
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          stack,
          if (widget.onAddTap != null) ...[
            const SizedBox(height: 8),
            _CircleIconButton(
              icon: Icons.add_rounded,
              onTap: widget.onAddTap!,
            ),
          ],
          const SizedBox(height: 8),
          Icon(
            Icons.layers_rounded,
            size: 22,
            color: Colors.black.withValues(alpha: 0.35),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: stack),
        if (widget.onAddTap != null) ...[
          const SizedBox(width: 8),
          _CircleIconButton(icon: Icons.add_rounded, onTap: widget.onAddTap!),
        ],
        const SizedBox(width: 8),
        Icon(
          Icons.layers_rounded,
          size: 22,
          color: Colors.black.withValues(alpha: 0.35),
        ),
      ],
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

class _StackedChip extends StatefulWidget {
  const _StackedChip({
    super.key,
    required this.timeLabel,
    required this.color,
    required this.isFront,
    required this.compact,
  });

  final String timeLabel;
  final Color color;
  final bool isFront;
  final bool compact;

  @override
  State<_StackedChip> createState() => _StackedChipState();
}

class _StackedChipState extends State<_StackedChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isFront) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StackedChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFront && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isFront) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.stop();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.compact ? 72.0 : 96.0;
    final h = widget.compact ? 34.0 : 44.0;
    final fontSize = widget.compact ? 13.0 : 17.0;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final scale = widget.isFront ? 1.0 + _pulse.value * 0.05 : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: w,
            height: h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(h / 2),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(
                    alpha: widget.isFront ? 0.45 : 0.22,
                  ),
                  blurRadius: widget.isFront ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Text(
        widget.timeLabel,
        style: GoogleFonts.nunito(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: const Color(0xFF111111)),
        ),
      ),
    );
  }
}

/// Overtime chip for stacked queue tail.
class CareOvertimeStackChip extends StatelessWidget {
  const CareOvertimeStackChip({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 72 : 96,
      height: compact ? 34 : 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        '정성',
        style: GoogleFonts.nunito(
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
