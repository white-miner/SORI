import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/sori_store.dart';
import '../../../visit_kernel/models/visit_operation_timer.dart';
import '../../../visit_kernel/models/visit_session.dart';
import '../../operation/visit_timer_store.dart';
import '../../operation/widgets/care_timer_action_strip.dart';
import '../../operation/widgets/care_timer_preset_editor_page.dart';
import '../../operation/widgets/flip_clock_display.dart';
import '../../operation/widgets/preset_expand_panel.dart';
import '../../operation/widgets/semantic_signal_theme.dart';
import '../../operation/widgets/volume_glass_theme.dart';

/// PRD v5.2 Phase A — Wall clock hero + bottom preset expand panel.
class SmartFlipTimerHero extends StatefulWidget {
  const SmartFlipTimerHero({
    super.key,
    required this.store,
    this.activeSession,
    this.onOpenSession,
    this.onConsultationStart,
    this.onOpenChart,
    this.onCareEnd,
    this.onVisitEnd,
    this.onPresetSelected,
  });

  final SoriStore store;
  final VisitSession? activeSession;
  final VoidCallback? onOpenSession;
  final VoidCallback? onConsultationStart;
  final VoidCallback? onOpenChart;
  final VoidCallback? onCareEnd;
  final VoidCallback? onVisitEnd;

  /// Filled preset row tapped — Phase B opens fullscreen care timer.
  final ValueChanged<int>? onPresetSelected;

  @override
  State<SmartFlipTimerHero> createState() => _SmartFlipTimerHeroState();
}

class _SmartFlipTimerHeroState extends State<SmartFlipTimerHero> {
  VisitTimerStore get timer => VisitTimerStore.instance;
  Timer? _wallClock;

  @override
  void initState() {
    super.initState();
    timer.addListener(_onTimer);
    _wallClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.removeListener(_onTimer);
    _wallClock?.cancel();
    super.dispose();
  }

  void _onTimer() {
    if (mounted) setState(() {});
  }

  Future<void> _openPresetEditor({int? slot}) async {
    if (slot != null) timer.selectPresetSlot(slot);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CareTimerPresetEditorPage(
          store: widget.store,
          initialSlot: slot ?? timer.selectedPresetSlot,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  bool _isTimerActive(VisitOperationTimer? active) {
    if (active == null) return false;
    return switch (active.status) {
      VisitTimerStatus.idle || VisitTimerStatus.done => false,
      _ => true,
    };
  }

  bool _isCareRunning(VisitOperationTimer? active) {
    if (active == null) return false;
    return switch (active.status) {
      VisitTimerStatus.care ||
      VisitTimerStatus.careOvertime =>
        true,
      _ => false,
    };
  }

  int _wallClockSeconds() {
    final now = DateTime.now();
    return now.hour * 3600 + now.minute * 60 + now.second;
  }

  /// Wall clock mode: session elapsed when active, else device time (HH:MM).
  int _displaySeconds(
    VisitOperationTimer? active,
    VisitTimerLiveSnapshot? snap,
  ) {
    if (active != null && _isTimerActive(active) && snap != null) {
      return snap.totalSeconds;
    }
    return _wallClockSeconds();
  }

  String _koreanDate(DateTime date) =>
      '${date.year}년 ${date.month}월 ${date.day}일';

  void _handlePresetSelected(int slot) {
    timer.selectPresetSlot(slot);
    widget.onPresetSelected?.call(slot);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.activeSession;
    final active = session != null &&
            timer.active?.visitSessionId == session.id
        ? timer.active
        : null;
    final snap = active == null ? null : VisitTimerLiveSnapshot.compute(active);
    final timerActive = _isTimerActive(active);
    final careRunning = _isCareRunning(active);

    final hasActions = session != null &&
        widget.onConsultationStart != null &&
        widget.onOpenChart != null &&
        widget.onCareEnd != null &&
        widget.onVisitEnd != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Material(
        color: VolumeGlassTheme.cardFillColor(),
        elevation: 0,
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
            boxShadow: VolumeGlassTheme.volumeShadow(alpha: 0.05),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (timerActive) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_filled_rounded,
                        size: 18,
                        color: SemanticSignalTheme.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        careRunning
                            ? '케어 타이머 진행 중'
                            : '세션 타이머 진행 중',
                        style: VolumeGlassTheme.labelTextStyle(compact: true)
                            .copyWith(
                          fontWeight: FontWeight.w700,
                          color: SemanticSignalTheme.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                GestureDetector(
                  onTap: widget.onOpenSession,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: FlipClockDisplay(
                      totalSeconds: _displaySeconds(active, snap),
                      hero: true,
                      showSeconds: false,
                      style: FlipClockStyle.darkGlass,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const _HeroDivider(),
                const SizedBox(height: 12),
                _HeroFooter(dateLabel: _koreanDate(DateTime.now())),
                const SizedBox(height: 14),
                PresetExpandPanel(
                  presets: timer.presets,
                  tintAt: timer.tintAt,
                  selectedSlot: timer.selectedPresetSlot,
                  onPresetSelected: _handlePresetSelected,
                  onConfigureSlot: (slot) => _openPresetEditor(slot: slot),
                  onOpenEditor: () => _openPresetEditor(),
                ),
                if (hasActions) ...[
                  const SizedBox(height: 14),
                  CareTimerActionStrip(
                    timer: active,
                    onConsultationStart: widget.onConsultationStart!,
                    onOpenChart: widget.onOpenChart!,
                    onCareEnd: widget.onCareEnd!,
                    onVisitEnd: widget.onVisitEnd!,
                    onOpenCareTimer: widget.onPresetSelected != null
                        ? () => widget.onPresetSelected!(
                              timer.selectedPresetSlot,
                            )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: const Color(0xFF3A3A3C).withValues(alpha: 0.08),
    );
  }
}

class _HeroFooter extends StatelessWidget {
  const _HeroFooter({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Text(
      dateLabel,
      textAlign: TextAlign.center,
      style: VolumeGlassTheme.labelTextStyle(compact: true).copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
