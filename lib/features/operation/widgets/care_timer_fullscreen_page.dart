import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/sori_store.dart';
import '../../../theme/sori_tokens.dart';
import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/preset_slot_tint.dart';
import '../../../visit_kernel/models/visit_operation_timer.dart';
import '../../../visit_kernel/models/visit_session.dart';
import '../care_timer_tts_service.dart';
import '../visit_timer_store.dart';
import 'care_segment_bar.dart';
import 'flip_clock_display.dart';
import 'volume_glass_theme.dart';

/// PRD v5.2 Phase B — fullscreen care timer with segment bar + Hero flip.
class CareTimerFullscreenPage extends StatefulWidget {
  const CareTimerFullscreenPage({
    super.key,
    required this.store,
    required this.session,
    required this.presetSlot,
    this.onCareEnd,
    this.onVisitEnd,
  });

  static const flipHeroTag = 'sori_care_flip_hero';

  final SoriStore store;
  final VisitSession session;
  final int presetSlot;
  final VoidCallback? onCareEnd;
  final VoidCallback? onVisitEnd;

  static Future<void> open(
    BuildContext context, {
    required SoriStore store,
    required VisitSession session,
    required int presetSlot,
    VoidCallback? onCareEnd,
    VoidCallback? onVisitEnd,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (context, animation, secondaryAnimation) {
          return CareTimerFullscreenPage(
            store: store,
            session: session,
            presetSlot: presetSlot,
            onCareEnd: onCareEnd,
            onVisitEnd: onVisitEnd,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<CareTimerFullscreenPage> createState() =>
      _CareTimerFullscreenPageState();
}

class _CareTimerFullscreenPageState extends State<CareTimerFullscreenPage> {
  VisitTimerStore get timer => VisitTimerStore.instance;
  bool _ttsMuted = CareTimerTtsService.isMuted;

  @override
  void initState() {
    super.initState();
    timer.addListener(_onTimer);
  }

  @override
  void dispose() {
    timer.removeListener(_onTimer);
    super.dispose();
  }

  void _onTimer() {
    if (mounted) setState(() {});
  }

  VisitOperationTimer? get _timer {
    final active = timer.active;
    if (active == null || active.visitSessionId != widget.session.id) {
      return null;
    }
    return active;
  }

  void _toggleTts() {
    setState(() {
      _ttsMuted = !_ttsMuted;
      CareTimerTtsService.setMuted(_ttsMuted);
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _timer;
    final snap = active == null ? null : timer.liveSnapshot;
    final preset = timer.presetAt(widget.presetSlot);
    final tint = timer.tintAt(widget.presetSlot);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final careSeconds = snap?.careSeconds ?? 0;
    final isArmed = timer.isCareArmed;
    final isRunning = timer.isCareRunning;
    final isPaused = timer.carePaused;
    final currentIndex = active?.currentStepIndex ?? 0;
    final stepRemaining = snap?.currentStepRemainingSeconds ?? 0;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(
              title: preset.name.trim().isEmpty ? '케어 타이머' : preset.name.trim(),
              ttsMuted: _ttsMuted,
              onClose: () => Navigator.of(context).pop(),
              onToggleTts: _toggleTts,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: isLandscape
                    ? _LandscapeBody(
                        steps: preset.steps,
                        tint: tint,
                        careSeconds: careSeconds,
                        isArmed: isArmed,
                        isRunning: isRunning,
                        isPaused: isPaused,
                        currentIndex: currentIndex,
                        stepRemaining: stepRemaining,
                        isOvertime: timer.isOvertime,
                        onTogglePlayback: () => timer.toggleCarePlayback(),
                        stepLabel: snap?.currentStepLabel,
                      )
                    : _PortraitBody(
                        steps: preset.steps,
                        tint: tint,
                        careSeconds: careSeconds,
                        isArmed: isArmed,
                        isRunning: isRunning,
                        isPaused: isPaused,
                        currentIndex: currentIndex,
                        stepRemaining: stepRemaining,
                        isOvertime: timer.isOvertime,
                        onTogglePlayback: () => timer.toggleCarePlayback(),
                        stepLabel: snap?.currentStepLabel,
                      ),
              ),
            ),
            if (active != null)
              _FullscreenControls(
                timer: active,
                onCareEnd: widget.onCareEnd,
                onVisitEnd: widget.onVisitEnd,
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.ttsMuted,
    required this.onClose,
    required this.onToggleTts,
  });

  final String title;
  final bool ttsMuted;
  final VoidCallback onClose;
  final VoidCallback onToggleTts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '나가기',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: ttsMuted ? '음성 안내 켜기' : '음성 안내 끄기',
            onPressed: onToggleTts,
            icon: Icon(
              ttsMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitBody extends StatelessWidget {
  const _PortraitBody({
    required this.steps,
    required this.tint,
    required this.careSeconds,
    required this.isArmed,
    required this.isRunning,
    required this.isPaused,
    required this.currentIndex,
    required this.stepRemaining,
    required this.isOvertime,
    required this.onTogglePlayback,
    this.stepLabel,
  });

  final List<CareProgramStep> steps;
  final PresetSlotTint tint;
  final int careSeconds;
  final bool isArmed;
  final bool isRunning;
  final bool isPaused;
  final int currentIndex;
  final int stepRemaining;
  final bool isOvertime;
  final VoidCallback onTogglePlayback;
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareSegmentBar(
          steps: steps,
          tint: tint,
          currentIndex: currentIndex,
          isArmed: isArmed,
          isRunning: isRunning,
          isPaused: isPaused,
          onTogglePlayback: onTogglePlayback,
          stepRemainingSeconds: stepRemaining,
        ),
        if (isOvertime) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: CareOvertimeSegmentChip(),
          ),
        ],
        const Spacer(),
        if (stepLabel != null && stepLabel!.isNotEmpty)
          Text(
            isArmed
                ? '▶ 를 눌러 케어를 시작하세요'
                : '현재: $stepLabel',
            textAlign: TextAlign.center,
            style: VolumeGlassTheme.labelTextStyle(compact: true).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 12),
        Center(child: _MainFlipClock(careSeconds: careSeconds)),
        const Spacer(flex: 2),
      ],
    );
  }
}

class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({
    required this.steps,
    required this.tint,
    required this.careSeconds,
    required this.isArmed,
    required this.isRunning,
    required this.isPaused,
    required this.currentIndex,
    required this.stepRemaining,
    required this.isOvertime,
    required this.onTogglePlayback,
    this.stepLabel,
  });

  final List<CareProgramStep> steps;
  final PresetSlotTint tint;
  final int careSeconds;
  final bool isArmed;
  final bool isRunning;
  final bool isPaused;
  final int currentIndex;
  final int stepRemaining;
  final bool isOvertime;
  final VoidCallback onTogglePlayback;
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 160,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CareSegmentBar(
                  steps: steps,
                  tint: tint,
                  currentIndex: currentIndex,
                  isArmed: isArmed,
                  isRunning: isRunning,
                  isPaused: isPaused,
                  onTogglePlayback: onTogglePlayback,
                  stepRemainingSeconds: stepRemaining,
                  vertical: true,
                ),
                if (isOvertime) ...[
                  const SizedBox(height: 8),
                  const CareOvertimeSegmentChip(),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (stepLabel != null && stepLabel!.isNotEmpty)
                Text(
                  isArmed
                      ? '▶ 를 눌러 케어를 시작하세요'
                      : '현재: $stepLabel',
                  style: VolumeGlassTheme.labelTextStyle(compact: true)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 16),
              _MainFlipClock(careSeconds: careSeconds),
            ],
          ),
        ),
      ],
    );
  }
}

class _MainFlipClock extends StatelessWidget {
  const _MainFlipClock({required this.careSeconds});

  final int careSeconds;

  @override
  Widget build(BuildContext context) {
    return FlipClockDisplay(
      totalSeconds: careSeconds,
      hero: true,
      showSeconds: false,
      showCornerSeconds: true,
      heroTag: CareTimerFullscreenPage.flipHeroTag,
      style: FlipClockStyle.darkGlass,
      stepLabel: '총 케어 소요',
    );
  }
}

class _FullscreenControls extends StatelessWidget {
  const _FullscreenControls({
    required this.timer,
    this.onCareEnd,
    this.onVisitEnd,
  });

  final VisitOperationTimer timer;
  final VoidCallback? onCareEnd;
  final VoidCallback? onVisitEnd;

  @override
  Widget build(BuildContext context) {
    final status = timer.status;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status == VisitTimerStatus.careOvertime)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '정성 시간 기록 중',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFF9500),
                ),
              ),
            ),
          if (status == VisitTimerStatus.care ||
              status == VisitTimerStatus.careOvertime)
            FilledButton(
              onPressed: timer.canEndCare ? onCareEnd : null,
              style: VolumeGlassTheme.carePrimaryButtonStyle(
                enabled: timer.canEndCare,
              ),
              child: Text(
                '케어 종료',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
            ),
          if (status == VisitTimerStatus.postCare)
            FilledButton(
              onPressed: onVisitEnd,
              style: VolumeGlassTheme.carePrimaryButtonStyle(),
              child: Text(
                '방문 종료',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}
