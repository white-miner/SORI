import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/sori_store.dart';
import '../../../visit_kernel/models/visit_operation_timer.dart';
import '../../../visit_kernel/models/visit_session.dart';
import '../../operation/visit_timer_store.dart';
import '../../operation/widgets/care_timer_preset_editor_page.dart';
import '../../operation/widgets/flip_clock_display.dart';
import '../../operation/widgets/preset_slot_row.dart';
import '../../operation/widgets/semantic_signal_theme.dart';
import '../../operation/widgets/volume_glass_theme.dart';

/// PO — main tab hero: slot row → flip clock → date/footer.
class SmartFlipTimerHero extends StatefulWidget {
  const SmartFlipTimerHero({
    super.key,
    required this.store,
    this.activeSession,
    this.onOpenSession,
  });

  final SoriStore store;
  final VisitSession? activeSession;
  final VoidCallback? onOpenSession;

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

  Future<void> _openPresetEditor() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CareTimerPresetEditorPage(
          store: widget.store,
          initialSlot: timer.selectedPresetSlot,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  bool _isCareMode(VisitOperationTimer? active) {
    if (active == null) return false;
    return switch (active.status) {
      VisitTimerStatus.prep ||
      VisitTimerStatus.care ||
      VisitTimerStatus.careOvertime =>
        true,
      _ => false,
    };
  }

  bool _isTimerActive(VisitOperationTimer? active) {
    if (active == null) return false;
    return switch (active.status) {
      VisitTimerStatus.idle || VisitTimerStatus.done => false,
      _ => true,
    };
  }

  int _wallClockSeconds() {
    final now = DateTime.now();
    return now.hour * 3600 + now.minute * 60 + now.second;
  }

  int _displaySeconds(
    VisitOperationTimer? active,
    VisitTimerLiveSnapshot? snap,
  ) {
    if (!_isCareMode(active) || snap == null) {
      return _wallClockSeconds();
    }
    if (active!.status == VisitTimerStatus.care) {
      return snap.currentStepRemainingSeconds > 0
          ? snap.currentStepRemainingSeconds
          : snap.careSeconds;
    }
    if (active.status == VisitTimerStatus.careOvertime) {
      return snap.careSeconds;
    }
    return snap.totalSeconds;
  }

  String? _stepLabel(
    VisitOperationTimer? active,
    VisitTimerLiveSnapshot? snap,
  ) {
    if (!_isCareMode(active)) return null;
    if (active == null || snap == null) return '케어';
    return switch (active.status) {
      VisitTimerStatus.prep => '베드 준비',
      VisitTimerStatus.care => snap.currentStepLabel,
      VisitTimerStatus.careOvertime => '케어 종료 대기',
      _ => '케어',
    };
  }

  String _koreanDate(DateTime date) =>
      '${date.year}년 ${date.month}월 ${date.day}일';

  @override
  Widget build(BuildContext context) {
    final session = widget.activeSession;
    final active = session != null &&
            timer.active?.visitSessionId == session.id
        ? timer.active
        : null;
    final snap = active == null ? null : VisitTimerLiveSnapshot.compute(active);
    final careMode = _isCareMode(active);
    final timerActive = _isTimerActive(active);
    final stepLabel = _stepLabel(active, snap);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Material(
        color: VolumeGlassTheme.cardFillColor(),
        elevation: 0,
        borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
        child: InkWell(
          onTap: widget.onOpenSession,
          borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VolumeGlassTheme.cardRadius),
              boxShadow: VolumeGlassTheme.volumeShadow(alpha: 0.05),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PresetSlotRow(
                    selected: timer.selectedPresetSlot,
                    presets: timer.presets,
                    tintAt: timer.tintAt,
                    onSelect: (i) {
                      timer.selectPresetSlot(i);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 14),
                  const _HeroDivider(),
                  SizedBox(height: careMode ? 14 : 22),
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
                          careMode ? '케어 타이머 진행 중' : '세션 타이머 진행 중',
                          style: VolumeGlassTheme.labelTextStyle(compact: true)
                              .copyWith(
                            fontWeight: FontWeight.w700,
                            color: SemanticSignalTheme.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (careMode && stepLabel != null) ...[
                    Text(
                      stepLabel,
                      textAlign: TextAlign.center,
                      style: VolumeGlassTheme.labelTextStyle(compact: true)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Center(
                    child: FlipClockDisplay(
                      totalSeconds: _displaySeconds(active, snap),
                      hero: true,
                      showSeconds: false,
                      style: FlipClockStyle.darkGlass,
                    ),
                  ),
                  SizedBox(height: careMode ? 14 : 22),
                  const _HeroDivider(),
                  const SizedBox(height: 12),
                  _HeroFooter(
                    dateLabel: _koreanDate(DateTime.now()),
                    onSettings: _openPresetEditor,
                  ),
                ],
              ),
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
  const _HeroFooter({
    required this.dateLabel,
    required this.onSettings,
  });

  final String dateLabel;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          dateLabel,
          textAlign: TextAlign.center,
          style: VolumeGlassTheme.labelTextStyle(compact: true).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: '프리셋 설정',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined, size: 22),
            visualDensity: VisualDensity.compact,
            color: const Color(0xFF3A3A3C),
          ),
        ),
      ],
    );
  }
}
