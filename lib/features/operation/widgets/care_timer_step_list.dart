import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/preset_slot_tint.dart';

/// PO v5.2 — expandable step list under care timer (portrait).
class CareTimerStepList extends StatefulWidget {
  const CareTimerStepList({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.isRunning,
  });

  final List<CareProgramStep> steps;
  final int currentIndex;
  final bool isRunning;

  @override
  State<CareTimerStepList> createState() => _CareTimerStepListState();
}

class _CareTimerStepListState extends State<CareTimerStepList> {
  bool _expanded = true;

  Color _stepColor(int index) {
    return PresetSlotTint.palette[index % PresetSlotTint.palette.length].color;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Text(
                      '타임라인',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF8E8E93),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstCurve: Curves.easeInOutCubic,
              secondCurve: Curves.easeInOutCubic,
              sizeCurve: Curves.easeInOutCubic,
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 280),
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Column(
                  children: [
                    for (var i = 0; i < widget.steps.length; i++) ...[
                      _StepRow(
                        minutes: widget.steps[i].minutes,
                        label: widget.steps[i].label,
                        color: _stepColor(i),
                        isActive:
                            widget.isRunning && i == widget.currentIndex,
                        isDone: widget.isRunning && i < widget.currentIndex,
                      ),
                      if (i < widget.steps.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.minutes,
    required this.label,
    required this.color,
    required this.isActive,
    required this.isDone,
  });

  final int minutes;
  final String label;
  final Color color;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final time =
        '${minutes.toString().padLeft(2, '0')}:${isDone ? '00' : '00'}';

    return Row(
      children: [
        Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            time,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.12)
                  : const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(14),
              border: isActive
                  ? Border.all(color: color.withValues(alpha: 0.45))
                  : null,
            ),
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
