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

  String _footerLabel(
    VisitOperationTimer? active,
    VisitTimerLiveSnapshot? snap,
  ) {
    if (!_isCareMode(active)) {
      return _koreanDate(DateTime.now());
    }
    if (snap == null) return _koreanDate(DateTime.now());
    if (active?.status == VisitTimerStatus.careOvertime) {
      return '프리셋 완료 · 정성 시간 기록 중';
    }
    return '케어 ${snap.formatDuration(snap.careSeconds)} · '
        '전체 ${snap.formatDuration(snap.totalSeconds)}';
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
                  _PresetSlotRow(
                    selected: timer.selectedPresetSlot,
                    presets: timer.presets,
                    onSelect: (i) {
                      timer.selectPresetSlot(i);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 14),
                  const _HeroDivider(),
                  SizedBox(height: careMode ? 14 : 22),
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
                      showSeconds: careMode,
                    ),
                  ),
                  SizedBox(height: careMode ? 14 : 22),
                  const _HeroDivider(),
                  const SizedBox(height: 12),
                  _HeroFooter(
                    label: _footerLabel(active, snap),
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
    required this.label,
    required this.onSettings,
  });

  final String label;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: VolumeGlassTheme.labelTextStyle(compact: true).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text(
              '세팅',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3A3A3C),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetSlotRow extends StatelessWidget {
  const _PresetSlotRow({
    required this.selected,
    required this.presets,
    required this.onSelect,
  });

  final int selected;
  final List<CareProgramTemplate> presets;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final p = i < presets.length ? presets[i] : null;
        final hasPreset = p != null && !p.isEmpty;
        final label = hasPreset ? p.name.trim() : '슬롯 ${i + 1}';
        final isSelected = i == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 4 ? 5 : 0),
            child: Material(
              color: isSelected
                  ? VolumeGlassTheme.vibrantCareGreen
                  : VolumeGlassTheme.cardFillColor(),
              borderRadius: BorderRadius.circular(12),
              elevation: 0,
              child: InkWell(
                onTap: hasPreset ? () => onSelect(i) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? VolumeGlassTheme.vibrantCareGreen
                          : const Color(0xFF3A3A3C).withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF3A3A3C),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
