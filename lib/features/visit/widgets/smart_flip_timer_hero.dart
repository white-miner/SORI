import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/sori_store.dart';
import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/visit_operation_timer.dart';
import '../../../visit_kernel/models/visit_session.dart';
import '../../operation/visit_timer_store.dart';
import '../../operation/widgets/care_timer_preset_editor_page.dart';
import '../../operation/widgets/flip_clock_display.dart';
import '../../operation/widgets/volume_glass_theme.dart';

/// PO — main tab hero: wall-clock flip display ↔ care countdown.
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
    if (!_isCareMode(active)) {
      final now = DateTime.now();
      return '${now.year}.${now.month.toString().padLeft(2, '0')}.'
          '${now.day.toString().padLeft(2, '0')}';
    }
    if (active == null || snap == null) return '케어';
    return switch (active.status) {
      VisitTimerStatus.prep => '베드 준비',
      VisitTimerStatus.care => snap.currentStepLabel,
      VisitTimerStatus.careOvertime => '케어 종료 대기',
      _ => '케어',
    };
  }

  String? _subtitle(
    VisitOperationTimer? active,
    VisitTimerLiveSnapshot? snap,
  ) {
    if (!_isCareMode(active)) {
      return widget.activeSession == null
          ? '현재 시각'
          : _sessionPhaseLabel(active);
    }
    if (snap == null) return null;
    if (active?.status == VisitTimerStatus.careOvertime) {
      return '프리셋 완료 · 정성 시간 기록 중';
    }
    return '케어 ${snap.formatDuration(snap.careSeconds)} · '
        '전체 ${snap.formatDuration(snap.totalSeconds)}';
  }

  String _sessionPhaseLabel(VisitOperationTimer? active) {
    if (active == null) return '세션 대기';
    return switch (active.status) {
      VisitTimerStatus.consulting => '차트 작성 중 · 탭하여 세션 열기',
      VisitTimerStatus.postCare => '케어 완료 · 탭하여 종료',
      VisitTimerStatus.done => '방문 종료',
      _ => '진행 중 · 탭하여 세션 열기',
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.activeSession;
    final active = session != null &&
            timer.active?.visitSessionId == session.id
        ? timer.active
        : null;
    final snap = active == null ? null : VisitTimerLiveSnapshot.compute(active);
    final careMode = _isCareMode(active);

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
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          careMode ? 'CARE TIMER' : 'SMART FLIP CLOCK',
                          style: VolumeGlassTheme.labelTextStyle(compact: true),
                        ),
                      ),
                      IconButton(
                        tooltip: '프리셋 설정',
                        onPressed: _openPresetEditor,
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _PresetChipRow(
                    selected: timer.selectedPresetSlot,
                    presets: timer.presets,
                    onSelect: (i) {
                      timer.selectPresetSlot(i);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FlipClockDisplay(
                      totalSeconds: _displaySeconds(active, snap),
                      stepLabel: _stepLabel(active, snap),
                      subtitle: _subtitle(active, snap),
                    ),
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

class _PresetChipRow extends StatelessWidget {
  const _PresetChipRow({
    required this.selected,
    required this.presets,
    required this.onSelect,
  });

  final int selected;
  final List<CareProgramTemplate> presets;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(5, (i) {
          final p = i < presets.length ? presets[i] : null;
          final hasPreset = p != null && !p.isEmpty;
          final label = hasPreset ? p.name.trim() : '슬롯 ${i + 1}';
          final isSelected = i == selected;
          return Padding(
            padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
            child: FilterChip(
              label: Text(label, overflow: TextOverflow.ellipsis),
              selected: isSelected,
              onSelected: hasPreset ? (_) => onSelect(i) : null,
              labelStyle: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF3A3A3C),
              ),
              selectedColor: VolumeGlassTheme.vibrantCareGreen,
              backgroundColor: VolumeGlassTheme.cardFillColor(),
              showCheckmark: false,
            ),
          );
        }),
      ),
    );
  }
}
