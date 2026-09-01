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
import 'care_stacked_segment_bar.dart';
import 'care_timer_floating_bar.dart';
import 'care_timer_step_list.dart';
import 'flip_clock_display.dart';
import 'volume_glass_theme.dart';

/// PRD v5.2 — fullscreen care timer (portrait + landscape, stacked queue).
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
  bool _immersiveClock = false;
  bool _floatingBarHidden = false;

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

  void _toggleImmersive() {
    setState(() {
      _immersiveClock = !_immersiveClock;
      if (!_immersiveClock) _floatingBarHidden = false;
    });
  }

  void _hideFloatingBar() {
    setState(() {
      _floatingBarHidden = true;
      _immersiveClock = true;
    });
  }

  bool get _showCareEnd {
    final active = _timer;
    if (active == null) return false;
    return active.status == VisitTimerStatus.care ||
        active.status == VisitTimerStatus.careOvertime;
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
    final isPlaying = isRunning && !isPaused;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      body: SafeArea(
        bottom: !_immersiveClock,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_immersiveClock)
                  _TopBar(
                    title: '케어 타이머',
                    onClose: () => Navigator.of(context).pop(),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      _immersiveClock ? 0 : 8,
                      16,
                      _immersiveClock ? 0 : 12,
                    ),
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
                            isPlaying: isPlaying,
                            isMuted: _ttsMuted,
                            immersive: _immersiveClock,
                            floatingBarHidden: _floatingBarHidden,
                            onTogglePlayback: () => timer.toggleCarePlayback(),
                            onToggleMute: _toggleTts,
                            onToggleImmersive: _toggleImmersive,
                            onHideFloatingBar: _hideFloatingBar,
                            onStop: () => timer.pauseCare(),
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
                            isPlaying: isPlaying,
                            isMuted: _ttsMuted,
                            immersive: _immersiveClock,
                            onTogglePlayback: () => timer.toggleCarePlayback(),
                            onToggleMute: _toggleTts,
                            onToggleImmersive: _toggleImmersive,
                            onStop: () => timer.pauseCare(),
                            stepLabel: snap?.currentStepLabel,
                          ),
                  ),
                ),
                if (!_immersiveClock && active != null)
                  _BottomActions(
                    timer: active,
                    onCareEnd: widget.onCareEnd,
                    onVisitEnd: widget.onVisitEnd,
                  ),
              ],
            ),
            if (_immersiveClock && _showCareEnd)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _CareEndButton(
                  onPressed: () async {
                    await VisitTimerStore.instance.endCare();
                    widget.onCareEnd?.call();
                  },
                ),
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
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: '나가기',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: VolumeGlassTheme.cardDecoration(radius: 22),
      child: child,
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
    required this.isPlaying,
    required this.isMuted,
    required this.immersive,
    required this.onTogglePlayback,
    required this.onToggleMute,
    required this.onToggleImmersive,
    required this.onStop,
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
  final bool isPlaying;
  final bool isMuted;
  final bool immersive;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleImmersive;
  final VoidCallback onStop;
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!immersive)
          _GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        if (!immersive) const SizedBox(height: 12),
        Expanded(
          child: _GlassCard(
            child: Column(
              children: [
                if (stepLabel != null &&
                    stepLabel!.isNotEmpty &&
                    !immersive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      isArmed
                          ? '▶ 를 눌러 케어를 시작하세요'
                          : '현재: $stepLabel',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: AnimatedScale(
                      scale: immersive ? 1.12 : 1.0,
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      child: _MainFlipClock(
                        careSeconds: careSeconds,
                        large: immersive,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CareTimerFloatingBar(
                  isPlaying: isPlaying,
                  isMuted: isMuted,
                  isImmersive: immersive,
                  onStop: onStop,
                  onTogglePlay: onTogglePlayback,
                  onToggleMute: onToggleMute,
                  onToggleImmersive: onToggleImmersive,
                ),
              ],
            ),
          ),
        ),
        if (!immersive) ...[
          const SizedBox(height: 12),
          CareTimerStepList(
            steps: steps,
            currentIndex: currentIndex,
            isRunning: isRunning,
          ),
        ],
        if (isOvertime && !immersive) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: CareOvertimeStackChip(),
          ),
        ],
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
    required this.isPlaying,
    required this.isMuted,
    required this.immersive,
    required this.floatingBarHidden,
    required this.onTogglePlayback,
    required this.onToggleMute,
    required this.onToggleImmersive,
    required this.onHideFloatingBar,
    required this.onStop,
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
  final bool isPlaying;
  final bool isMuted;
  final bool immersive;
  final bool floatingBarHidden;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleImmersive;
  final VoidCallback onHideFloatingBar;
  final VoidCallback onStop;
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!floatingBarHidden && !immersive)
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.delta.dy > 6) onHideFloatingBar();
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: CareTimerFloatingBar(
                vertical: true,
                isPlaying: isPlaying,
                isMuted: isMuted,
                isImmersive: immersive,
                showCollapse: true,
                onStop: onStop,
                onTogglePlay: onTogglePlayback,
                onToggleMute: onToggleMute,
                onToggleImmersive: onToggleImmersive,
                onCollapse: onHideFloatingBar,
              ),
            ),
          ),
        if (!floatingBarHidden && !immersive) const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (stepLabel != null &&
                  stepLabel!.isNotEmpty &&
                  !immersive)
                Text(
                  isArmed
                      ? '▶ 를 눌러 케어를 시작하세요'
                      : '현재: $stepLabel',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              if (!immersive) const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: AnimatedScale(
                    scale: immersive ? 1.22 : 1.0,
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
                    child: _MainFlipClock(
                      careSeconds: careSeconds,
                      large: immersive,
                    ),
                  ),
                ),
              ),
              if (immersive)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CareTimerFloatingBar(
                    isPlaying: isPlaying,
                    isMuted: isMuted,
                    isImmersive: immersive,
                    onStop: onStop,
                    onTogglePlay: onTogglePlayback,
                    onToggleMute: onToggleMute,
                    onToggleImmersive: onToggleImmersive,
                  ),
                ),
            ],
          ),
        ),
        if (!immersive) ...[
          const SizedBox(width: 12),
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CareStackedSegmentBar(
                  steps: steps,
                  tint: tint,
                  currentIndex: currentIndex,
                  isArmed: isArmed,
                  isRunning: isRunning,
                  isPaused: isPaused,
                  stepRemainingSeconds: stepRemaining,
                  vertical: true,
                ),
                if (isOvertime) ...[
                  const SizedBox(height: 8),
                  const CareOvertimeStackChip(),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MainFlipClock extends StatelessWidget {
  const _MainFlipClock({required this.careSeconds, this.large = false});

  final int careSeconds;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: FlipClockDisplay(
        totalSeconds: careSeconds,
        hero: true,
        showSeconds: false,
        showCornerSeconds: true,
        heroTag: CareTimerFullscreenPage.flipHeroTag,
        style: FlipClockStyle.darkGlass,
        stepLabel: '총 케어 소요',
        compact: !large,
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
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
            _CareEndButton(
              onPressed: () async {
                await VisitTimerStore.instance.endCare();
                onCareEnd?.call();
              },
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

class _CareEndButton extends StatelessWidget {
  const _CareEndButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: PresetSlotTint.iosOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 0,
      ),
      child: Text(
        '케어 종료',
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
