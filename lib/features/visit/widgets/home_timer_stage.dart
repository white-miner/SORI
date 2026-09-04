import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../operation/care_timer_tts_service.dart';
import '../../operation/visit_timer_store.dart';
import '../../operation/widgets/care_stacked_segment_bar.dart';
import '../../operation/widgets/care_timer_floating_bar.dart';
import '../../operation/widgets/flip_clock_display.dart';
import '../../operation/widgets/volume_glass_theme.dart';
import '../home_visual_tokens.dart';

/// Timer 탭 Standby / Live — 풀스크린과 동일 엔진, 탭 본문에 직접 임베딩.
class HomeTimerStage extends StatefulWidget {
  const HomeTimerStage({
    super.key,
    required this.onExpandFullscreen,
    required this.onCareStart,
    required this.onCareEnd,
  });

  final VoidCallback onExpandFullscreen;
  final VoidCallback onCareStart;
  final VoidCallback onCareEnd;

  @override
  State<HomeTimerStage> createState() => _HomeTimerStageState();
}

class _HomeTimerStageState extends State<HomeTimerStage> {
  VisitTimerStore get _timer => VisitTimerStore.instance;
  Timer? _wallTick;
  bool _muted = CareTimerTtsService.isMuted;

  @override
  void initState() {
    super.initState();
    _timer.addListener(_onStore);
    _syncWallTick();
  }

  @override
  void dispose() {
    _timer.removeListener(_onStore);
    _wallTick?.cancel();
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    _syncWallTick();
    setState(() {});
  }

  void _syncWallTick() {
    final live = _timer.isCareRunning || _timer.isCareArmed;
    if (live) {
      _wallTick?.cancel();
      _wallTick = null;
      return;
    }
    _wallTick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  int _wallClockSeconds() {
    final now = DateTime.now();
    return now.hour * 3600 + now.minute * 60 + now.second;
  }

  int _standbyPlanSeconds() {
    final slot = _timer.homeSelectedPresetSlot ?? _timer.selectedPresetSlot;
    final preset = _timer.presetAt(slot);
    if (preset.isEmpty) return _wallClockSeconds();
    var total = 0;
    for (final s in preset.steps) {
      total += s.seconds;
    }
    return total;
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
    final live = isArmed || isRunning;

    final careSeconds = live
        ? (snap?.displaySeconds ?? 0)
        : (preset.isEmpty ? _wallClockSeconds() : _standbyPlanSeconds());

    final stepRemaining = snap?.currentStepRemainingSeconds ?? 0;
    final currentIndex = active?.currentStepIndex ?? 0;
    final stepLabel = live
        ? (isArmed
            ? '케어 시작을 눌러 첫 스텝을 여세요'
            : (snap?.currentStepLabel.isNotEmpty == true
                ? '현재: ${snap!.currentStepLabel}'
                : null))
        : (preset.isEmpty ? '대기 · 실시간' : preset.name);

    final remainingLabel =
        isOvertime ? '추가 시간' : (snap?.remainingLabel ?? '종료까지 남은 시간');
    final remainingValue = snap == null
        ? null
        : snap.formatKoreanClock(snap.displaySeconds);

    return Padding(
      key: const Key('home-timer-stage'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (steps.isNotEmpty) ...[
            _StageCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: CareStackedSegmentBar(
                  steps: steps,
                  tint: tint,
                  currentIndex: currentIndex,
                  isArmed: isArmed,
                  isRunning: isRunning,
                  isPaused: isPaused,
                  stepRemainingSeconds: stepRemaining,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _StageCard(
            child: Column(
              children: [
                if (stepLabel != null && stepLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      stepLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: FlipClockDisplay(
                    totalSeconds: careSeconds,
                    hero: true,
                    showSeconds: false,
                    showCornerSeconds: true,
                    stepLabel: live ? remainingLabel : null,
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
                    onStop: () => unawaited(_timer.pauseCare()),
                    onTogglePlay: () => unawaited(_timer.toggleCarePlayback()),
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
          Row(
            children: [
              if (!isRunning)
                Expanded(
                  child: _CareStartButton(onTap: widget.onCareStart),
                ),
              if (!isRunning && (isArmed || isOvertime || active != null))
                const SizedBox(width: 8),
              if (isRunning || isArmed)
                Expanded(
                  child: _CareEndButton(onTap: widget.onCareEnd),
                ),
            ],
          ),
          if (live && remainingValue != null) ...[
            const SizedBox(height: 10),
            _RemainingBanner(
              label: remainingLabel,
              value: remainingValue,
              overtime: isOvertime,
            ),
          ],
          if (isOvertime) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: CareOvertimeStackChip(),
            ),
          ],
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

class _CareEndButton extends StatelessWidget {
  const _CareEndButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1C1C1E),
          side: const BorderSide(color: Color(0xFFD1D1D6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          '케어 종료',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RemainingBanner extends StatelessWidget {
  const _RemainingBanner({
    required this.label,
    required this.value,
    required this.overtime,
  });

  final String label;
  final String value;
  final bool overtime;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-timer-remaining-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: overtime
            ? const Color(0xFFFFF4E5)
            : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: overtime
                  ? const Color(0xFFFF9500)
                  : const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }
}
