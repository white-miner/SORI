import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/preset_slot_tint.dart';

import '../../../widgets/press_bounce.dart';
import '../../visit/home_visual_tokens.dart';
import 'care_timer_step_list.dart';

/// 가로로 펼쳐진 스텝 칩 + 우측 레이어 아이콘.
/// 겹침 Stack이 아니라 Row/ListView로 모든 칩이 보이고, 레이어 탭은 아코디언이다.
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
    this.expandList = false,
    this.onAddTap,
    this.onLayersTap,
    this.onStepTap,
    this.isOvertime = false,
    this.overtimeSeconds = 0,
  });

  final List<CareProgramStep> steps;
  final PresetSlotTint tint;
  final int currentIndex;
  final bool isArmed;
  final bool isRunning;
  final bool isPaused;
  final int stepRemainingSeconds;
  final bool vertical;
  /// 호환용. 레이아웃은 항상 가로 칩 전개.
  final bool expandList;
  final VoidCallback? onAddTap;
  final VoidCallback? onLayersTap;
  final ValueChanged<int>? onStepTap;
  final bool isOvertime;
  final int overtimeSeconds;

  @override
  State<CareStackedSegmentBar> createState() => _CareStackedSegmentBarState();
}

class _CareStackedSegmentBarState extends State<CareStackedSegmentBar> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expandList;
  }

  @override
  void didUpdateWidget(covariant CareStackedSegmentBar oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Color _stepColor(int index) {
    final palette = PresetSlotTint.palette;
    return palette[index % palette.length].color;
  }

  String _timeFor(int index) {
    if (index >= widget.steps.length) return '00:00';
    final step = widget.steps[index];
    final isCurrent = index == widget.currentIndex;
    if (isCurrent &&
        widget.isRunning &&
        !widget.isPaused &&
        widget.stepRemainingSeconds > 0) {
      return _formatMmSs(widget.stepRemainingSeconds);
    }
    if (widget.isRunning && index < widget.currentIndex) {
      return '00:00';
    }
    return _formatPlanned(step.minutes);
  }

  void _onLayersPressed() {
    HapticFeedback.mediumImpact();
    setState(() => _expanded = !_expanded);
    widget.onLayersTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty && !widget.isOvertime) {
      return const SizedBox.shrink();
    }

    final chips = <_ChipSpec>[
      for (var i = 0; i < widget.steps.length; i++)
        _ChipSpec(
          keyName: 'chip-$i',
          timeLabel: _timeFor(i),
          color: _stepColor(i),
          isFront: i == widget.currentIndex &&
              (widget.isRunning || widget.isArmed),
          stepIndex: i,
        ),
      if (widget.isOvertime)
        _ChipSpec(
          keyName: 'chip-overtime',
          timeLabel: '(+)${_formatMmSs(widget.overtimeSeconds)}',
          color: PresetSlotTint.iosGreen,
          isFront: true,
        ),
    ];

    final rail = _ChipRail(
      chips: chips,
      onSettingsTap: widget.onAddTap,
      layersExpanded: _expanded,
      onLayersTap: _onLayersPressed,
      onStepTap: widget.onStepTap,
    );

    return Column(
      key: widget.expandList ? const Key('care-segment-list') : null,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        rail,
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded && widget.steps.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: CareTimerStepList(
                    key: const Key('care-segment-accordion'),
                    steps: widget.steps,
                    currentIndex: widget.currentIndex,
                    isRunning: widget.isRunning,
                    onStepTap: widget.onStepTap,
                  ),
                )
              : const SizedBox.shrink(),
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

class _ChipSpec {
  const _ChipSpec({
    required this.keyName,
    required this.timeLabel,
    required this.color,
    required this.isFront,
    this.stepIndex,
  });

  final String keyName;
  final String timeLabel;
  final Color color;
  final bool isFront;
  final int? stepIndex;
}

class _ChipRail extends StatelessWidget {
  const _ChipRail({
    required this.chips,
    required this.onSettingsTap,
    required this.layersExpanded,
    required this.onLayersTap,
    this.onStepTap,
  });

  final List<_ChipSpec> chips;
  final VoidCallback? onSettingsTap;
  final bool layersExpanded;
  final VoidCallback onLayersTap;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('care-segment-rail'),
      children: [
        Expanded(
          child: SizedBox(
            height: HomeVisualTokens.stackedFrontH + 6,
            child: ListView.separated(
              key: const Key('care-segment-h-list'),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final spec = chips[index];
                return Align(
                  alignment: Alignment.center,
                  child: PressBounce(
                    child: _SegmentChip(
                      key: ValueKey(spec.keyName),
                      timeLabel: spec.timeLabel,
                      color: spec.color,
                      isFront: spec.isFront,
                      onTap: spec.stepIndex == null
                          ? null
                          : () => onStepTap?.call(spec.stepIndex!),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (onSettingsTap != null) ...[
          const SizedBox(width: 8),
          PressBounce(
            child: _CircleIconButton(
              icon: Icons.tune_rounded,
              tooltip: '프리셋 설정',
              onTap: onSettingsTap!,
            ),
          ),
        ],
        const SizedBox(width: 4),
        _LayersButton(
          expanded: layersExpanded,
          onTap: onLayersTap,
        ),
      ],
    );
  }
}

class _SegmentChip extends StatefulWidget {
  const _SegmentChip({
    super.key,
    required this.timeLabel,
    required this.color,
    required this.isFront,
    this.onTap,
  });

  final String timeLabel;
  final Color color;
  final bool isFront;
  final VoidCallback? onTap;

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
    if (widget.isFront) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _SegmentChip oldWidget) {
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
    final w = widget.isFront
        ? HomeVisualTokens.stackedFrontW
        : HomeVisualTokens.stackedBackW;
    final h = widget.isFront
        ? HomeVisualTokens.stackedFrontH
        : HomeVisualTokens.stackedBackH;
    final fontSize = widget.isFront ? 17.0 : 13.0;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final scale = widget.isFront ? 1.0 + _pulse.value * 0.05 : 1.0;
        return Transform.scale(
          scale: scale,
          child: Material(
            color: widget.color,
            borderRadius: BorderRadius.circular(h / 2),
            elevation: 0,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(h / 2),
              child: Container(
                width: w,
                height: h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
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
            ),
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
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final size = HomeVisualTokens.stackedAddCircle;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 20, color: const Color(0xFF111111)),
          ),
        ),
      ),
    );
  }
}

class _LayersButton extends StatelessWidget {
  const _LayersButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressBounce(
      child: IconButton(
        key: const Key('care-segment-layers'),
        tooltip: expanded ? '스텝 접기' : '스텝 펼치기',
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(
          Icons.layers_rounded,
          size: 22,
          color: Colors.black.withValues(alpha: expanded ? 0.72 : 0.45),
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
