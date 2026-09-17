import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/sori_store.dart';
import '../../../theme/sori_tokens.dart';
import '../../../visit_kernel/models/care_program_template.dart';
import '../../../visit_kernel/models/preset_slot_tint.dart';
import '../../../visit_kernel/models/visit_operation_timer.dart';
import '../../../visit_kernel/models/visit_session.dart';
import '../../visit/models/care_timer_entry_mode.dart';
import '../care_timer_tts_service.dart';
import '../visit_timer_store.dart';
import 'care_timer_preset_editor_page.dart';
import 'care_stacked_segment_bar.dart';
import 'care_timer_floating_bar.dart';
import 'care_timer_step_list.dart';
import 'flip_clock_display.dart';
import 'volume_glass_theme.dart';

enum CareAutoStartPhase { idle, waiting, tts, done, cancelled }

/// PRD v5.2/v5.3 — fullscreen care timer (portrait + landscape, stacked queue).
class CareTimerFullscreenPage extends StatefulWidget {
  const CareTimerFullscreenPage({
    super.key,
    required this.store,
    this.session,
    required this.presetSlot,
    this.entryMode = CareTimerEntryMode.standalone,
    this.onCareEnd,
    this.onVisitEnd,
    this.onPopHome,
  });

  static const flipHeroTag = 'sori_care_flip_hero';

  final SoriStore store;
  final VisitSession? session;
  final int presetSlot;
  final CareTimerEntryMode entryMode;
  final VoidCallback? onCareEnd;
  final VoidCallback? onVisitEnd;
  final VoidCallback? onPopHome;

  static Future<void> open(
    BuildContext context, {
    required SoriStore store,
    VisitSession? session,
    required int presetSlot,
    CareTimerEntryMode entryMode = CareTimerEntryMode.standalone,
    VoidCallback? onCareEnd,
    VoidCallback? onVisitEnd,
    VoidCallback? onPopHome,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (context, animation, secondaryAnimation) {
          return CareTimerFullscreenPage(
            store: store,
            session: session,
            presetSlot: presetSlot,
            entryMode: entryMode,
            onCareEnd: onCareEnd,
            onVisitEnd: onVisitEnd,
            onPopHome: onPopHome,
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
  CareAutoStartPhase _autoPhase = CareAutoStartPhase.idle;

  @override
  void initState() {
    super.initState();
    timer.addListener(_onTimer);
    if (widget.entryMode.autoStartPipeline) {
      _runAutoStartPipeline();
    }
  }

  @override
  void dispose() {
    if (_autoPhase == CareAutoStartPhase.waiting ||
        _autoPhase == CareAutoStartPhase.tts) {
      _autoPhase = CareAutoStartPhase.cancelled;
    }
    timer.removeListener(_onTimer);
    _restoreSystemUi();
    super.dispose();
  }

  Future<void> _runAutoStartPipeline() async {
    _autoPhase = CareAutoStartPhase.waiting;
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted || _autoPhase == CareAutoStartPhase.cancelled) return;
    _autoPhase = CareAutoStartPhase.tts;
    await CareTimerTtsService.announceCareStartIntro();
    if (!mounted || _autoPhase == CareAutoStartPhase.cancelled) return;
    await timer.startCare(presetSlot: widget.presetSlot);
    if (mounted) {
      _autoPhase = CareAutoStartPhase.done;
      setState(() {});
    }
  }

  Future<void> _cancelAndPopHome() async {
    _autoPhase = CareAutoStartPhase.cancelled;
    await CareTimerTtsService.primeFromUserGesture();
    if (timer.isCareRunning || timer.isCareArmed) {
      if (timer.active?.isStandalone ?? false) {
        await timer.finishStandaloneCare();
      } else if (timer.isCareRunning) {
        await timer.endCare();
      }
    }
    widget.onCareEnd?.call();
    widget.onPopHome?.call();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleCareStart() async {
    await CareTimerTtsService.primeFromUserGesture();
    if (timer.isCareArmed) {
      await timer.startCare(presetSlot: widget.presetSlot);
    } else {
      final preset = timer.presetAt(widget.presetSlot);
      if (preset.steps.isNotEmpty) {
        await timer.bindPreset(presetSlot: widget.presetSlot);
        await timer.startCare(presetSlot: widget.presetSlot);
      }
    }
    if (mounted) setState(() {});
  }

  void _onTimer() {
    if (mounted) setState(() {});
  }

  VisitOperationTimer? get _timer {
    final active = timer.active;
    if (active == null) return null;
    if (widget.session != null) {
      if (active.visitSessionId != widget.session!.id) return null;
    } else if (!active.isStandalone) {
      return null;
    }
    return active;
  }

  bool get _showCareEndButton {
    if (widget.entryMode.showCareEndImmediately) return true;
    final active = _timer;
    if (active == null) return false;
    return active.status == VisitTimerStatus.care ||
        active.status == VisitTimerStatus.careOvertime;
  }

  bool get _showCareStartButton {
    if (!widget.entryMode.showCareStartButton) return false;
    if (timer.isCareRunning) return false;
    return true;
  }

  Future<void> _openPresetEditor() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CareTimerPresetEditorPage(
          store: widget.store,
          initialSlot: widget.presetSlot,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickProgram() async {
    final presets = timer.presets.where((p) => !p.isEmpty).toList();
    if (presets.isEmpty) {
      await _openPresetEditor();
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in presets)
              ListTile(
                title: Text(p.name),
                onTap: () => Navigator.pop(ctx, p.slotIndex),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    timer.selectPresetSlot(picked);
    if (timer.active?.isStandalone ?? true) {
      await timer.bindPreset(presetSlot: picked);
    } else {
      await timer.bindPreset(presetSlot: picked);
    }
    setState(() {});
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
    if (_immersiveClock) {
      _enterImmersiveSystemUi();
    } else {
      _restoreSystemUi();
    }
  }

  void _hideFloatingBar() {
    setState(() => _floatingBarHidden = true);
  }

  void _showFloatingBar() {
    setState(() => _floatingBarHidden = false);
  }

  void _enterImmersiveSystemUi() {
    if (kIsWeb) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _restoreSystemUi() {
    if (kIsWeb) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final active = _timer;
    final snap = active == null ? null : timer.liveSnapshot;
    final preset = timer.presetAt(timer.selectedPresetSlot);
    final tint = timer.tintAt(timer.selectedPresetSlot);
    final programTitle = preset.name.trim().isEmpty
        ? '케어 프로그램 선택'
        : preset.name.trim();
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    // 웹/태블릿 가로: 세로 떠다니는 레일 대신 중앙 컬럼(max 640).
    // 진짜 몰입 가로만 좌·우 3단을 쓴다.
    final useImmersiveLandscape = isLandscape && _immersiveClock;
    final useCenteredStage = !useImmersiveLandscape;

    final isArmed = timer.isCareArmed;
    final isRunning = timer.isCareRunning;
    final isPaused = timer.carePaused;
    final currentIndex = active?.currentStepIndex ?? 0;
    final standbySteps = active?.templateSnapshot.isNotEmpty == true
        ? active!.templateSnapshot
        : preset.steps;
    final careSeconds = timer.isOvertime
        ? (snap?.overtimeElapsedSeconds ?? 0)
        : isRunning
            ? (snap?.currentStepRemainingSeconds ?? 0)
            : (currentIndex >= 0 && currentIndex < standbySteps.length
                ? standbySteps[currentIndex].seconds
                : (standbySteps.isNotEmpty ? standbySteps.first.seconds : 0));
    final stepRemaining = snap?.currentStepRemainingSeconds ?? 0;
    final isPlaying = isRunning && !isPaused;
    final remainingLabel = snap?.remainingLabel ?? '종료까지 남은 시간';
    final remainingText = snap == null
        ? '0분 00초'
        : snap.formatKoreanClock(snap.displaySeconds);

    final stage = useImmersiveLandscape
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
            controlsEnabled: isRunning,
            canSkip: timer.canSkipStep,
            remainingLabel: remainingLabel,
            remainingText: remainingText,
            onTogglePlayback: () => timer.toggleCarePlayback(),
            onToggleMute: _toggleTts,
            onToggleImmersive: _toggleImmersive,
            onHideFloatingBar: _hideFloatingBar,
            onShowFloatingBar: _showFloatingBar,
            onSkipNext: () => timer.skipToNextStep(),
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
            controlsEnabled: isRunning,
            canSkip: timer.canSkipStep,
            onTogglePlayback: () => timer.toggleCarePlayback(),
            onToggleMute: _toggleTts,
            onToggleImmersive: _toggleImmersive,
            onSkipNext: () => timer.skipToNextStep(),
            onStop: () => timer.pauseCare(),
            stepLabel: snap?.currentStepLabel,
          );

    return Scaffold(
      backgroundColor: SoriTokens.background,
      body: SafeArea(
        top: !_immersiveClock,
        bottom: !_immersiveClock,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_immersiveClock)
                  _TopBar(
                    title: programTitle,
                    onClose: () => Navigator.of(context).maybePop(),
                    onPickProgram: _pickProgram,
                    onOpenSettings: _openPresetEditor,
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      _immersiveClock ? 0 : 8,
                      16,
                      _immersiveClock ? 0 : 12,
                    ),
                    child: useCenteredStage
                        ? Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: stage,
                            ),
                          )
                        : stage,
                  ),
                ),
                if (!_immersiveClock)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _BottomActions(
                        entryMode: widget.entryMode,
                        timer: active,
                        snap: snap,
                        showCareEnd: _showCareEndButton,
                        showCareStart: _showCareStartButton,
                        onCareStart: _handleCareStart,
                        onCareEnd: _cancelAndPopHome,
                        onVisitEnd: widget.onVisitEnd,
                      ),
                    ),
                  ),
              ],
            ),
            if (_immersiveClock && _showCareEndButton && !useImmersiveLandscape)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Align(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _CareEndButton(onPressed: _cancelAndPopHome),
                  ),
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
    required this.onPickProgram,
    required this.onOpenSettings,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback onPickProgram;
  final VoidCallback onOpenSettings;

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
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
          GestureDetector(
            onTap: onPickProgram,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more_rounded, size: 20),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: '설정',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
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
    required this.controlsEnabled,
    required this.canSkip,
    required this.onTogglePlayback,
    required this.onToggleMute,
    required this.onToggleImmersive,
    required this.onSkipNext,
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
  final bool controlsEnabled;
  final bool canSkip;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleImmersive;
  final VoidCallback onSkipNext;
  final VoidCallback onStop;
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!immersive && steps.isNotEmpty) ...[
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
              isOvertime: isOvertime,
              onStepTap: (i) => VisitTimerStore.instance.jumpToStep(i),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
                          ? '케어 시작을 눌러 첫 스텝을 여세요'
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
                        remainingLabel:
                            isOvertime ? '추가 시간' : '현재 구간',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CareTimerFloatingBar(
                  isPlaying: isPlaying,
                  isMuted: isMuted,
                  isImmersive: immersive,
                  enabled: controlsEnabled,
                  canSkip: canSkip,
                  onStop: onStop,
                  onTogglePlay: onTogglePlayback,
                  onToggleMute: onToggleMute,
                  onToggleImmersive: onToggleImmersive,
                  onSkipNext: onSkipNext,
                ),
              ],
            ),
          ),
        ),
        if (!immersive && steps.isNotEmpty) ...[
          const SizedBox(height: 10),
          CareTimerStepList(
            steps: steps,
            currentIndex: currentIndex,
            isRunning: isRunning,
            onStepTap: (i) {
              unawaited(CareTimerTtsService.primeFromUserGesture());
              unawaited(VisitTimerStore.instance.jumpToStep(i));
            },
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
    required this.controlsEnabled,
    required this.canSkip,
    required this.remainingLabel,
    required this.remainingText,
    required this.onTogglePlayback,
    required this.onToggleMute,
    required this.onToggleImmersive,
    required this.onHideFloatingBar,
    required this.onShowFloatingBar,
    required this.onSkipNext,
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
  final bool controlsEnabled;
  final bool canSkip;
  final String remainingLabel;
  final String remainingText;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleImmersive;
  final VoidCallback onHideFloatingBar;
  final VoidCallback onShowFloatingBar;
  final VoidCallback onSkipNext;
  final VoidCallback onStop;
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    final controls = CareTimerFloatingBar(
      isPlaying: isPlaying,
      isMuted: isMuted,
      isImmersive: immersive,
      enabled: controlsEnabled,
      canSkip: canSkip,
      onStop: onStop,
      onTogglePlay: onTogglePlayback,
      onToggleMute: onToggleMute,
      onToggleImmersive: onToggleImmersive,
      onSkipNext: onSkipNext,
    );

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  if (stepLabel != null &&
                      stepLabel!.isNotEmpty &&
                      !immersive)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        isArmed
                            ? '케어 시작을 눌러 첫 스텝을 여세요'
                            : '현재: $stepLabel',
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
                          remainingLabel: remainingLabel,
                        ),
                      ),
                    ),
                  ),
                  if (!floatingBarHidden) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onVerticalDragEnd: (details) {
                        final v = details.primaryVelocity ?? 0;
                        if (v > 240) onHideFloatingBar();
                      },
                      child: controls,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LandscapeRemainingPill(
                        label: remainingLabel,
                        text: remainingText,
                        overtime: isOvertime,
                      ),
                      const SizedBox(height: 12),
                      CareStackedSegmentBar(
                        steps: steps,
                        tint: tint,
                        currentIndex: currentIndex,
                        isArmed: isArmed,
                        isRunning: isRunning,
                        isPaused: isPaused,
                        stepRemainingSeconds: stepRemaining,
                        isOvertime: isOvertime,
                        expandList: true,
                        onStepTap: (i) =>
                            VisitTimerStore.instance.jumpToStep(i),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (floatingBarHidden)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 48,
            child: GestureDetector(
              key: const Key('care-swipe-rail'),
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v < -240) onShowFloatingBar();
              },
              child: const Center(
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MainFlipClock extends StatelessWidget {
  const _MainFlipClock({
    required this.careSeconds,
    this.large = false,
    this.remainingLabel,
  });

  final int careSeconds;
  final bool large;
  final String? remainingLabel;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: FlipClockDisplay(
        totalSeconds: careSeconds,
        hero: true,
        showSeconds: true,
        showCornerSeconds: false,
        heroTag: CareTimerFullscreenPage.flipHeroTag,
        style: FlipClockStyle.darkGlass,
        stepLabel: remainingLabel ?? '현재 구간',
        compact: !large,
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.entryMode,
    required this.timer,
    required this.snap,
    required this.showCareEnd,
    required this.showCareStart,
    required this.onCareStart,
    required this.onCareEnd,
    this.onVisitEnd,
  });

  final CareTimerEntryMode entryMode;
  final VisitOperationTimer? timer;
  final VisitTimerLiveSnapshot? snap;
  final bool showCareEnd;
  final bool showCareStart;
  final VoidCallback onCareStart;
  final VoidCallback onCareEnd;
  final VoidCallback? onVisitEnd;

  @override
  Widget build(BuildContext context) {
    final status = timer?.status;
    final remaining = snap;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showCareStart)
                Expanded(
                  child: FilledButton(
                    onPressed: onCareStart,
                    style: VolumeGlassTheme.carePrimaryButtonStyle(),
                    child: Text(
                      '케어 시작',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              if (showCareStart && showCareEnd) const SizedBox(width: 8),
              if (showCareEnd)
                Expanded(
                  child: _CareEndButton(onPressed: onCareEnd),
                ),
            ],
          ),
          if (remaining != null &&
              (status == VisitTimerStatus.care ||
                  status == VisitTimerStatus.careOvertime ||
                  status == VisitTimerStatus.prep)) ...[
            const SizedBox(height: 10),
            _RemainingBanner(
              label: remaining.remainingLabel,
              value: remaining.formatKoreanClock(remaining.displaySeconds),
              overtime: remaining.isOvertime,
            ),
          ],
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
    final accent =
        overtime ? const Color(0xFFFF9500) : const Color(0xFFFF3B30);
    return Container(
      key: const Key('care-remaining-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              key: const Key('care-remaining-label'),
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A3A3C),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeRemainingPill extends StatelessWidget {
  const _LandscapeRemainingPill({
    required this.label,
    required this.text,
    required this.overtime,
  });

  final String label;
  final String text;
  final bool overtime;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: overtime
              ? const Color(0xFFFF9500)
              : const Color(0xFFFF9F0A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
