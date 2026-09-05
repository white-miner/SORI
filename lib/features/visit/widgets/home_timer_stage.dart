import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/preset_slot_tint.dart';
import '../../operation/care_timer_tts_service.dart';
import '../../operation/visit_timer_store.dart';
import '../../operation/widgets/care_stacked_segment_bar.dart';
import '../../operation/widgets/care_timer_floating_bar.dart';
import '../../operation/widgets/care_timer_step_list.dart';
import '../../operation/widgets/flip_clock_display.dart';
import '../../operation/widgets/volume_glass_theme.dart';
import '../../../widgets/press_bounce.dart';
import '../home_visual_tokens.dart';

/// Timer 탭 Standby / Live — PO image_21 / image_22 위젯 트리.
class HomeTimerStage extends StatefulWidget {
  const HomeTimerStage({
    super.key,
    required this.onExpandFullscreen,
    required this.onCareStart,
    required this.onCareEnd,
    required this.onOpenPresetEditor,
  });

  final VoidCallback onExpandFullscreen;
  final VoidCallback onCareStart;
  final VoidCallback onCareEnd;
  final ValueChanged<int> onOpenPresetEditor;

  @override
  State<HomeTimerStage> createState() => _HomeTimerStageState();
}

class _HomeTimerStageState extends State<HomeTimerStage> {
  VisitTimerStore get _timer => VisitTimerStore.instance;
  bool _muted = CareTimerTtsService.isMuted;

  @override
  void initState() {
    super.initState();
    _timer.addListener(_onStore);
  }

  @override
  void dispose() {
    _timer.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  /// 중앙 플립시계 = 현재 구간 타임. 총시간·벽시계는 넣지 않는다.
  int _stepClockSeconds({
    required bool isRunning,
    required bool isOvertime,
    required int currentIndex,
    required List<CareProgramStep> steps,
  }) {
    final snap = _timer.liveSnapshot;
    if (isOvertime) return snap?.overtimeElapsedSeconds ?? 0;
    if (isRunning) return snap?.currentStepRemainingSeconds ?? 0;
    if (currentIndex >= 0 && currentIndex < steps.length) {
      return steps[currentIndex].seconds;
    }
    if (steps.isNotEmpty) return steps.first.seconds;
    return 0;
  }

  Future<void> _swapProgram(int slot) async {
    _timer.selectPresetSlot(slot);
    await _timer.selectHomePresetSlot(slot);
    if (_timer.isCareArmed || _timer.isCareRunning) {
      await _timer.bindPreset(presetSlot: slot);
      if (_timer.isCareRunning) {
        await _timer.startCare(presetSlot: slot);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final active = _timer.active;
    final snap = _timer.liveSnapshot;
    final slot = _timer.homeSelectedPresetSlot ?? _timer.selectedPresetSlot;
    final preset = _timer.presetAt(slot);
    final tint = _timer.tintAt(slot);
    final steps = active?.templateSnapshot.isNotEmpty == true
        ? active!.templateSnapshot
        : preset.steps;

    final isArmed = _timer.isCareArmed;
    final isRunning = _timer.isCareRunning;
    final isPaused = _timer.carePaused;
    final isOvertime = _timer.isOvertime;

    final stepRemaining = snap?.currentStepRemainingSeconds ?? 0;
    final careSeconds = _stepClockSeconds(
      isRunning: isRunning,
      isOvertime: isOvertime,
      currentIndex: active?.currentStepIndex ?? 0,
      steps: steps,
    );
    final currentIndex = active?.currentStepIndex ?? 0;
    final courseTitle = preset.name.trim().isEmpty
        ? (isRunning ? '케어 프로그램' : '대기')
        : preset.name.trim();

    final stepHeadline = isRunning && snap?.currentStepLabel.isNotEmpty == true
        ? '현재: ${snap!.currentStepLabel}'
        : courseTitle;

    return Padding(
      key: const Key('home-timer-stage'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HomeTimerTitleBar(
            title: courseTitle,
            showBack: isRunning,
            onBack: widget.onCareEnd,
            onSwap: (picked) => unawaited(_swapProgram(picked)),
            onOpenEditor: () => widget.onOpenPresetEditor(slot),
          ),
          const SizedBox(height: 10),
          if (steps.isNotEmpty) ...[
            _StageCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: CareStackedSegmentBar(
                steps: steps,
                tint: tint,
                currentIndex: currentIndex,
                isArmed: isArmed,
                isRunning: isRunning,
                isPaused: isPaused,
                stepRemainingSeconds: stepRemaining,
                isOvertime: isOvertime,
                overtimeSeconds: snap?.overtimeElapsedSeconds ?? 0,
                onAddTap: () => widget.onOpenPresetEditor(slot),
                onStepTap: (i) => unawaited(_timer.jumpToStep(i)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _StageCard(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    stepHeadline,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: FlipClockDisplay(
                    key: const Key('home-timer-step-clock'),
                    totalSeconds: careSeconds,
                    hero: true,
                    showSeconds: true,
                    showCornerSeconds: false,
                    style: FlipClockStyle.darkGlass,
                    stepLabel: isOvertime
                        ? '추가 시간'
                        : (isRunning ? '현재 구간' : null),
                  ),
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: CareTimerFloatingBar(
                    isPlaying: isRunning && !isPaused,
                    isMuted: _muted,
                    isImmersive: false,
                    enabled: isRunning,
                    canSkip: _timer.canSkipStep,
                    onTogglePlay: () {
                      if (!isRunning) {
                        widget.onCareStart();
                      } else {
                        unawaited(_timer.toggleCarePlayback());
                      }
                    },
                    onToggleMute: () {
                      setState(() {
                        _muted = !_muted;
                        CareTimerTtsService.setMuted(_muted);
                      });
                    },
                    onToggleImmersive: widget.onExpandFullscreen,
                    onSkipNext: () => unawaited(_timer.skipToNextStep()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!isRunning)
            PressBounce(child: _CareStartButton(onTap: widget.onCareStart))
          else
            PressBounce(child: _CareEndButton(onTap: widget.onCareEnd)),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            CareTimerStepList(
              key: const Key('home-timer-step-list'),
              steps: steps,
              currentIndex: currentIndex,
              isRunning: isRunning,
              onStepTap: (i) => unawaited(_timer.jumpToStep(i)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 타이틀 바 — 뒤로(<) + 케어명 아코디언 퀵 스왑.
class _HomeTimerTitleBar extends StatefulWidget {
  const _HomeTimerTitleBar({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onSwap,
    required this.onOpenEditor,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final ValueChanged<int> onSwap;
  final VoidCallback onOpenEditor;

  @override
  State<_HomeTimerTitleBar> createState() => _HomeTimerTitleBarState();
}

class _HomeTimerTitleBarState extends State<_HomeTimerTitleBar> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final presets = VisitTimerStore.instance.presets
        .where((p) => !p.isEmpty)
        .toList();

    return Material(
      key: const Key('home-timer-title-bar'),
      color: HomeVisualTokens.heroCardFill,
      borderRadius: BorderRadius.circular(HomeVisualTokens.heroCardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PressBounce(
                      child: IconButton(
                        tooltip: '스탠바이로',
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.chevron_left_rounded, size: 28),
                      ),
                    ),
                  ),
                PressBounce(
                  child: InkWell(
                    onTap: () {
                      if (presets.isEmpty) {
                        widget.onOpenEditor();
                        return;
                      }
                      setState(() => _open = !_open);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1C1C1E),
                              ),
                            ),
                          ),
                          Icon(
                            _open
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 22,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: [
                        for (final p in presets)
                          PressBounce(
                            child: ListTile(
                              dense: true,
                              title: Text(
                                p.name.trim().isEmpty
                                    ? '슬롯 ${p.slotIndex + 1}'
                                    : p.name,
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onTap: () {
                                setState(() => _open = false);
                                widget.onSwap(p.slotIndex);
                              },
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeVisualTokens.heroCardFill,
      borderRadius: BorderRadius.circular(HomeVisualTokens.heroCardRadius),
      elevation: 0,
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: child,
      ),
    );
  }
}

class _CareStartButton extends StatelessWidget {
  const _CareStartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1F34C759),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: VolumeGlassTheme.vibrantCareGreen,
            foregroundColor: VolumeGlassTheme.onVibrantCare,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            '케어 시작',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// 3) 케어 종료 — iOS System Red.
class _CareEndButton extends StatelessWidget {
  const _CareEndButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('home-timer-care-end'),
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: PresetSlotTint.iosRed,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          '케어 종료',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
