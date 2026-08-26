import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/chart_photo_compressor.dart';
import '../services/chart_photo_storage.dart';
import '../services/guide_camera_session.dart';
import '../services/guide_camera_zoom_memory.dart';
import '../services/guide_face_align.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_haptic.dart';
import '../utils/sori_nav.dart';
import '../widgets/media_permission_dialogs.dart';

enum GuideCameraKind { before, after }

enum GuideCaptureMode { selfFront, directorRear }

enum _ShutterTimerDelay { off, s3, s5, s10 }

extension _ShutterTimerDelayX on _ShutterTimerDelay {
  int get seconds => switch (this) {
        _ShutterTimerDelay.off => 0,
        _ShutterTimerDelay.s3 => 3,
        _ShutterTimerDelay.s5 => 5,
        _ShutterTimerDelay.s10 => 10,
      };

  String get badge => switch (this) {
        _ShutterTimerDelay.off => '',
        _ShutterTimerDelay.s3 => '3',
        _ShutterTimerDelay.s5 => '5',
        _ShutterTimerDelay.s10 => '10',
      };

  _ShutterTimerDelay get next => switch (this) {
        _ShutterTimerDelay.off => _ShutterTimerDelay.s3,
        _ShutterTimerDelay.s3 => _ShutterTimerDelay.s5,
        _ShutterTimerDelay.s5 => _ShutterTimerDelay.s10,
        _ShutterTimerDelay.s10 => _ShutterTimerDelay.off,
      };
}

const _kLevelToleranceDeg = 1.0;

enum GuidePreset {
  face,
  decollete,
  abdomen,
  lowerBody,
  fullBody;

  String get label => switch (this) {
        GuidePreset.face => '페이스',
        GuidePreset.decollete => '데콜테',
        GuidePreset.abdomen => '복부',
        GuidePreset.lowerBody => '하체',
        GuidePreset.fullBody => '전신',
      };

  bool get isSelfPreset =>
      this == GuidePreset.face || this == GuidePreset.decollete;

  /// MediaPipe 원형 정렬을 쓰는 프리셋 (페이스만).
  bool get usesFaceAlign => this == GuidePreset.face;

  String get iconAsset => switch (this) {
        GuidePreset.face => 'assets/icons/ic_face.svg',
        GuidePreset.decollete => 'assets/icons/ic_decollete.svg',
        GuidePreset.abdomen => 'assets/icons/ic_abdomen.svg',
        GuidePreset.lowerBody => 'assets/icons/ic_legs.svg',
        GuidePreset.fullBody => 'assets/icons/ic_body.svg',
      };
}

class GuideCameraResult {
  const GuideCameraResult({
    required this.url,
    required this.previewBytes,
    required this.kind,
  });

  final String url;
  final Uint8List previewBytes;
  final GuideCameraKind kind;
}

/// 스마트 가이드 카메라 V2 — 줌 메모리 + MediaPipe 3D 정렬.
class SmartGuideCameraPage extends StatefulWidget {
  const SmartGuideCameraPage({
    super.key,
    required this.shopId,
    required this.customerId,
    required this.kind,
    this.ghostBeforeUrl,
  });

  final String shopId;
  final String customerId;
  final GuideCameraKind kind;
  final String? ghostBeforeUrl;

  static Future<GuideCameraResult?> open(
    BuildContext context, {
    required String shopId,
    required String customerId,
    required GuideCameraKind kind,
    String? ghostBeforeUrl,
  }) {
    return pushRootPage<GuideCameraResult>(
      context,
      SmartGuideCameraPage(
        shopId: shopId,
        customerId: customerId,
        kind: kind,
        ghostBeforeUrl: ghostBeforeUrl,
      ),
      fullscreenDialog: true,
    );
  }

  @override
  State<SmartGuideCameraPage> createState() => _SmartGuideCameraPageState();
}

class _SmartGuideCameraPageState extends State<SmartGuideCameraPage> {
  late final GuideCameraSession _session;
  late final GuideFaceAlign _faceAlign;
  GuideCaptureMode _mode = GuideCaptureMode.selfFront;
  GuidePreset _preset = GuidePreset.face;
  bool _ghostOn = true;
  bool _starting = true;
  bool _mlLoading = false;
  bool _busy = false;
  String? _error;
  String? _viewType;
  int? _countdown;
  GuideDeviceAttitude? _attitude;
  bool _wasLevel = false;
  bool _motionReady = false;
  bool _motionDenied = false;
  bool _motionBusy = false;
  GuideFacePose _facePose = GuideFacePose.none;
  double _zoom = GuideCameraZoomMemory.defaultZoom;
  _ShutterTimerDelay _timerDelay = _ShutterTimerDelay.off;
  StreamSubscription<GuideDeviceAttitude?>? _attitudeSub;
  StreamSubscription<GuideFacePose>? _poseSub;
  Timer? _timer;
  Timer? _zoomSaveTimer;

  bool get _isAfter => widget.kind == GuideCameraKind.after;
  bool get _canGhost {
    final u = widget.ghostBeforeUrl?.trim() ?? '';
    return _isAfter && u.isNotEmpty;
  }

  bool get _faceAlignActive => _preset.usesFaceAlign;

  /// 카메라/ML 준비 전에는 하단 조작 비활성.
  bool get _controlsLocked =>
      _starting || _mlLoading || _busy || _viewType == null || _countdown != null;

  List<GuidePreset> get _presets => GuidePreset.values;

  @override
  void initState() {
    super.initState();
    _session = createGuideCameraSession();
    _faceAlign = createGuideFaceAlign();
    if (_isAfter && !_canGhost) {
      _ghostOn = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _zoomSaveTimer?.cancel();
    _attitudeSub?.cancel();
    _poseSub?.cancel();
    _faceAlign.dispose();
    unawaited(_session.stop());
    super.dispose();
  }

  Future<void> _boot() async {
    if (!kIsWeb) {
      setState(() {
        _starting = false;
        _error = '스마트 가이드 카메라는 태블릿 웹/PWA에서만 사용할 수 있어요.';
      });
      return;
    }

    _zoom = await GuideCameraZoomMemory.load(widget.shopId);
    if (!mounted) return;

    // Permissions API granted → 안내 모달 즉시 스킵
    final ok = await ensureCameraPermissionGuide(context);
    if (!mounted) return;
    if (!ok) {
      Navigator.pop(context);
      return;
    }

    await _startCamera();
  }

  Future<void> _startCamera() async {
    final needMl = _preset.usesFaceAlign;
    setState(() {
      _starting = true;
      _mlLoading = needMl;
      _error = null;
      _viewType = null;
      _facePose = GuideFacePose.none;
    });
    await _faceAlign.stop();

    // 카메라 스트림과 CDN 모델 로드를 병렬로 — 오버레이로 대기 UX 제공
    final prepareMl = needMl
        ? _faceAlign.prepare().catchError((Object e, StackTrace st) {
            debugPrint('face align prepare failed: $e\n$st');
          })
        : Future<void>.value();

    try {
      final front = _mode == GuideCaptureMode.selfFront;
      await _session.start(front: front, zoom: _zoom);
      // 시스템 허용 성공 시 앱 사전 안내 영속 스킵
      unawaited(MediaPermissionSession.setAlwaysAllowPersisted(true));
      await _attitudeSub?.cancel();
      _attitudeSub = _session.attitude.listen(_onAttitude);

      // Android/Chrome: start()에서 이미 리스너 연결. iOS는 사용자 탭 필요.
      final motionReady = _session.orientationListening;
      if (!mounted) return;
      setState(() {
        _viewType = _session.viewType;
        _starting = false;
        _motionReady = motionReady;
        _motionDenied = false;
      });

      await _poseSub?.cancel();
      _poseSub = _faceAlign.poses.listen((p) {
        if (!mounted) return;
        setState(() => _facePose = p);
      });

      if (needMl) {
        await prepareMl;
        if (!mounted) return;
        final video = _session.mlVideoHandle;
        if (video != null) {
          try {
            await _faceAlign.start(video);
          } catch (e) {
            debugPrint('face align start failed: $e');
          }
        }
        if (!mounted) return;
        setState(() => _mlLoading = false);
      }
    } catch (e) {
      debugPrint('guide camera start failed: $e');
      if (!mounted) return;
      if (isMediaPermissionDeniedError(e)) {
        MediaPermissionSession.guideAccepted = false;
        await showMediaPermissionDeniedDialog(context);
      }
      setState(() {
        _starting = false;
        _mlLoading = false;
        _error = '카메라를 열 수 없어요. 브라우저 카메라 권한을 확인해 주세요.\n$e';
      });
    }
  }

  void _onAttitude(GuideDeviceAttitude? next) {
    if (!mounted) return;
    final prev = _attitude;
    if (prev != null &&
        next != null &&
        (prev.roll - next.roll).abs() < 0.12) {
      return;
    }
    final leveled = next != null && next.roll.abs() <= _kLevelToleranceDeg;
    if (leveled && !_wasLevel) {
      HapticFeedback.lightImpact();
      soriLightHaptic();
    }
    _wasLevel = leveled;
    setState(() {
      _attitude = next;
      if (next != null) _motionReady = true;
    });
  }

  /// iOS Safari: DeviceOrientationEvent.requestPermission 은 탭 제스처 필수.
  Future<void> _enableMotionSensors() async {
    if (_motionBusy || _session.orientationListening) {
      if (_session.orientationListening && mounted) {
        setState(() {
          _motionReady = true;
          _motionDenied = false;
        });
      }
      return;
    }
    setState(() => _motionBusy = true);
    try {
      final ok = await _session.enableOrientationListening();
      if (!mounted) return;
      setState(() {
        _motionReady = ok;
        _motionDenied = !ok;
        _motionBusy = false;
      });
      if (ok) {
        HapticFeedback.selectionClick();
      }
    } catch (e) {
      debugPrint('[Gyro] enable failed: $e');
      if (!mounted) return;
      setState(() {
        _motionDenied = true;
        _motionBusy = false;
      });
    }
  }

  Future<void> _switchMode(GuideCaptureMode mode) async {
    if (_mode == mode || _controlsLocked) return;
    setState(() {
      _mode = mode;
      if (!_presets.contains(_preset)) {
        _preset = _presets.first;
      }
    });
    await _startCamera();
  }

  Future<void> _selectPreset(GuidePreset p) async {
    if (_preset == p || _controlsLocked) return;
    setState(() {
      _preset = p;
      _facePose = GuideFacePose.none;
    });
    if (!_session.isRunning) return;
    if (p.usesFaceAlign) {
      setState(() => _mlLoading = true);
      try {
        await _faceAlign.prepare();
        final video = _session.mlVideoHandle;
        if (video != null) await _faceAlign.start(video);
      } catch (e) {
        debugPrint('preset face align failed: $e');
      } finally {
        if (mounted) setState(() => _mlLoading = false);
      }
    } else {
      await _faceAlign.stop();
      if (mounted) setState(() => _mlLoading = false);
    }
  }

  void _onZoomChanged(double v) {
    if (_controlsLocked && !_busy) return;
    if (_mlLoading || _starting) return;
    final clamped = v.clamp(
      GuideCameraZoomMemory.minZoom,
      GuideCameraZoomMemory.maxZoom,
    );
    setState(() => _zoom = clamped);
    unawaited(_session.setZoom(clamped));
    _zoomSaveTimer?.cancel();
    _zoomSaveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(GuideCameraZoomMemory.save(widget.shopId, clamped));
    });
  }

  void _cycleTimerDelay() {
    if (_controlsLocked) return;
    setState(() => _timerDelay = _timerDelay.next);
  }

  void _onShutterPressed() {
    if (_controlsLocked) return;
    final sec = _timerDelay.seconds;
    if (sec <= 0) {
      unawaited(_captureAndUpload());
    } else {
      _startTimerCapture(sec);
    }
  }

  void _startTimerCapture(int seconds) {
    if (_busy || _countdown != null) return;
    var n = seconds;
    setState(() => _countdown = n);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      n--;
      if (!mounted) {
        t.cancel();
        return;
      }
      if (n <= 0) {
        t.cancel();
        setState(() => _countdown = null);
        unawaited(_captureAndUpload());
      } else {
        setState(() => _countdown = n);
      }
    });
  }

  Future<void> _captureAndUpload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final jpeg = await _session.captureJpeg();
      if (!mounted) return;
      if (jpeg == null || jpeg.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('캡처에 실패했어요. 다시 시도해 주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final webp = await ChartPhotoCompressor.toWebp(jpeg);
      if (!mounted) return;
      if (webp == null || webp.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WebP 압축에 실패했어요.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final url = await ChartPhotoStorage.uploadWebp(
        bytes: webp,
        shopId: widget.shopId,
        customerId: widget.customerId,
        kind: widget.kind == GuideCameraKind.before ? 'before' : 'after',
      );
      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('업로드에 실패했어요. 네트워크·Storage를 확인해 주세요.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      await GuideCameraZoomMemory.save(widget.shopId, _zoom);
      if (!mounted) return;

      Navigator.pop(
        context,
        GuideCameraResult(
          url: url,
          previewBytes: webp,
          kind: widget.kind,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('촬영 실패: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closePage() async {
    _timer?.cancel();
    _zoomSaveTimer?.cancel();
    await _poseSub?.cancel();
    await _attitudeSub?.cancel();
    await _faceAlign.stop();
    await _session.stop();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final kindLabel =
        widget.kind == GuideCameraKind.before ? 'Before' : 'After';
    final orientation = MediaQuery.orientationOf(context);
    final portrait = orientation == Orientation.portrait;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // 시스템 백/제스처로 이탈 시에도 트랙 즉시 해제
        if (didPop) {
          unawaited(_faceAlign.stop());
          unawaited(_session.stop());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // viewPadding 기준 — 모바일 웹 노치/툴바 오프셋으로 터치 좌표가 밀리지 않게
        body: SafeArea(
          minimum: EdgeInsets.zero,
          child: portrait
              ? _buildPortrait(kindLabel)
              : _buildLandscape(kindLabel),
        ),
      ),
    );
  }

  Future<void> _toggleCameraFacing() async {
    if (_controlsLocked) return;
    final next = _mode == GuideCaptureMode.selfFront
        ? GuideCaptureMode.directorRear
        : GuideCaptureMode.selfFront;
    await _switchMode(next);
  }

  Widget _buildPortrait(String kindLabel) {
    return Column(
      children: [
        _TopBar(
          kindLabel: kindLabel,
          onClose: () => unawaited(_closePage()),
          showGhostToggle: _canGhost,
          ghostOn: _ghostOn,
          onGhostToggle: _controlsLocked
              ? null
              : () => setState(() => _ghostOn = !_ghostOn),
        ),
        Expanded(child: _buildViewfinder()),
        _CameraDock(
          locked: _controlsLocked,
          presets: _presets,
          selectedPreset: _preset,
          onPresetSelected: (p) => unawaited(_selectPreset(p)),
          zoom: _zoom,
          onZoomChanged: _onZoomChanged,
          timerDelay: _timerDelay,
          onTimerCycle: _cycleTimerDelay,
          onShutter: _onShutterPressed,
          onFlip: () => unawaited(_toggleCameraFacing()),
          faceHint: _faceAlignActive
              ? (_mlLoading
                  ? 'AI 준비 중'
                  : (!_facePose.detected
                      ? '얼굴을 원 안에'
                      : (!_facePose.inCircle
                          ? '원 안에 맞춰 주세요'
                          : (_facePose.isAligned
                              ? '정렬됨'
                              : '정면으로 맞춰 주세요'))))
              : null,
          faceAligned: _facePose.isAligned && !_mlLoading,
        ),
      ],
    );
  }

  Widget _buildLandscape(String kindLabel) {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildViewfinder()),
        Expanded(
          flex: 2,
          child: ColoredBox(
            color: Colors.black,
            child: Column(
              children: [
                _TopBar(
                  kindLabel: kindLabel,
                  onClose: () => unawaited(_closePage()),
                  showGhostToggle: _canGhost,
                  ghostOn: _ghostOn,
                  onGhostToggle: _controlsLocked
                      ? null
                      : () => setState(() => _ghostOn = !_ghostOn),
                ),
                Expanded(
                  child: _CameraDock(
                    locked: _controlsLocked,
                    presets: _presets,
                    selectedPreset: _preset,
                    onPresetSelected: (p) => unawaited(_selectPreset(p)),
                    zoom: _zoom,
                    onZoomChanged: _onZoomChanged,
                    timerDelay: _timerDelay,
                    onTimerCycle: _cycleTimerDelay,
                    onShutter: _onShutterPressed,
                    onFlip: () => unawaited(_toggleCameraFacing()),
                    faceHint: _faceAlignActive
                        ? (_mlLoading
                            ? 'AI 준비 중'
                            : (!_facePose.detected
                                ? '얼굴을 원 안에'
                                : (!_facePose.inCircle
                                    ? '원 안에 맞춰 주세요'
                                    : (_facePose.isAligned
                                        ? '정렬됨'
                                        : '정면으로'))))
                        : null,
                    faceAligned: _facePose.isAligned && !_mlLoading,
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewfinder() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: kGuideCameraAspectRatio,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (_viewType != null)
                  IgnorePointer(
                    child: HtmlElementView(viewType: _viewType!),
                  )
                else if (_starting)
                  const IgnorePointer(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: SoriTokens.primary,
                      ),
                    ),
                  )
                else if (_error != null)
                  IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                // —— 시각 가이드·오버레이: 전부 터치 통과 ——
                if (_canGhost &&
                    _ghostOn &&
                    (widget.ghostBeforeUrl?.isNotEmpty ?? false))
                  IgnorePointer(
                    child: Opacity(
                      opacity: 0.25,
                      child: Image.network(
                        widget.ghostBeforeUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                IgnorePointer(
                  ignoring: true,
                  child: CustomPaint(
                    painter: const _GridOverlayPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
                if (_preset == GuidePreset.face)
                  IgnorePointer(
                    ignoring: true,
                    child: CustomPaint(
                      painter: _CircularFaceAlignPainter(
                        pose: _facePose,
                        mirrored: _mode == GuideCaptureMode.selfFront,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  )
                else if (_preset == GuidePreset.decollete)
                  IgnorePointer(
                    ignoring: true,
                    child: CustomPaint(
                      painter: _DecolleteGuidePainter(
                        attitude: _attitude,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  )
                else
                  IgnorePointer(
                    ignoring: true,
                    child: CustomPaint(
                      painter: _BodyGuidePainter(preset: _preset),
                      child: const SizedBox.expand(),
                    ),
                  ),
                IgnorePointer(
                  ignoring: _motionReady && _attitude != null,
                  child: _DynamicGyroLeveler(
                    attitude: _attitude,
                    motionReady: _motionReady,
                    motionDenied: _motionDenied,
                    motionBusy: _motionBusy,
                    needsPermissionPrompt:
                        _session.requiresOrientationPermissionPrompt &&
                            !_motionReady,
                    onEnableMotion: () => unawaited(_enableMotionSensors()),
                  ),
                ),
                if (_countdown != null)
                  IgnorePointer(
                    ignoring: true,
                    child: Center(
                      child: Text(
                        '$_countdown',
                        style: TextStyle(
                          fontSize: 96,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.92),
                          shadows: const [
                            Shadow(blurRadius: 18, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_busy)
                  const Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(
                        color: Color(0x59000000),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (_mlLoading)
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.62),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: SoriTokens.primary,
                                  ),
                                ),
                                SizedBox(height: 18),
                                Text(
                                  'AI 안면 인식 모듈을 준비 중입니다...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 하단 순수 블랙 컨트롤 패널 — 뷰파인더와 완전 분리.
class _CameraDock extends StatelessWidget {
  const _CameraDock({
    required this.locked,
    required this.presets,
    required this.selectedPreset,
    required this.onPresetSelected,
    required this.zoom,
    required this.onZoomChanged,
    required this.timerDelay,
    required this.onTimerCycle,
    required this.onShutter,
    required this.onFlip,
    this.faceHint,
    this.faceAligned = false,
    this.compact = false,
  });

  final bool locked;
  final List<GuidePreset> presets;
  final GuidePreset selectedPreset;
  final ValueChanged<GuidePreset> onPresetSelected;
  final double zoom;
  final ValueChanged<double> onZoomChanged;
  final _ShutterTimerDelay timerDelay;
  final VoidCallback onTimerCycle;
  final VoidCallback onShutter;
  final VoidCallback onFlip;
  final String? faceHint;
  final bool faceAligned;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AbsorbPointer(
      absorbing: locked,
      child: Opacity(
        opacity: locked ? 0.42 : 1,
        child: ColoredBox(
          color: Colors.black,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, compact ? 10 : 12, 16, bottom + 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (faceHint != null) ...[
                  Text(
                    faceHint!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: faceAligned
                          ? SoriTokens.primary.withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  height: 40,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < presets.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          _PresetIconButton(
                            preset: presets[i],
                            selected: selectedPreset == presets[i],
                            onTap: locked
                                ? null
                                : () => onPresetSelected(presets[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: compact ? 4 : 6),
                _MonochromeZoomSlider(
                  value: zoom,
                  onChanged: locked ? (_) {} : onZoomChanged,
                ),
                SizedBox(height: compact ? 8 : 10),
                SizedBox(
                  height: 76,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 18),
                            child: _TimerToggleButton(
                              delay: timerDelay,
                              onTap: onTimerCycle,
                            ),
                          ),
                        ),
                      ),
                      _ShutterButton(onPressed: onShutter),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: _FlipCameraButton(onTap: onFlip),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '촬영',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1C1C1E),
            border: Border.all(
              color: SoriTokens.primary.withValues(alpha: 0.92),
              width: 3.5,
            ),
            boxShadow: [
              BoxShadow(
                color: SoriTokens.primary.withValues(alpha: 0.22),
                blurRadius: 14,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF5F5F5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerToggleButton extends StatelessWidget {
  const _TimerToggleButton({
    required this.delay,
    required this.onTap,
  });

  final _ShutterTimerDelay delay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = delay != _ShutterTimerDelay.off;
    return Semantics(
      button: true,
      label: active ? '타이머 ${delay.badge}초' : '타이머 꺼짐',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 24,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
              ),
              if (active) ...[
                const SizedBox(height: 2),
                Text(
                  delay.badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FlipCameraButton extends StatelessWidget {
  const _FlipCameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '카메라 전환',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(
            Icons.cameraswitch_rounded,
            size: 24,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}

class _PresetIconButton extends StatelessWidget {
  const _PresetIconButton({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final GuidePreset preset;
  final bool selected;
  final VoidCallback? onTap;

  static const _inactive = Color(0xFF71717A);
  static const _emerald = Color(0xFF00D289);

  @override
  Widget build(BuildContext context) {
    final fg = selected ? _emerald : _inactive;
    return Semantics(
      button: true,
      label: preset.label,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SvgPicture.asset(
              preset.iconAsset,
              width: 26,
              height: 26,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonochromeZoomSlider extends StatelessWidget {
  const _MonochromeZoomSlider({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
                Icon(
          Icons.remove_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white.withValues(alpha: 0.75),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.06),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(
                GuideCameraZoomMemory.minZoom,
                GuideCameraZoomMemory.maxZoom,
              ),
              min: GuideCameraZoomMemory.minZoom,
              max: GuideCameraZoomMemory.maxZoom,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${value.toStringAsFixed(1)}×',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _GridOverlayPainter extends CustomPainter {
  const _GridOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..strokeWidth = 0.75;

    for (var i = 1; i <= 2; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridOverlayPainter oldDelegate) => false;
}

/// 1축(Roll) 가로 막대 수평계 — iPhone 카메라 스타일.
/// Pitch는 UI에서 완전 제외. Roll(gamma)만으로 막대를 회전한다.
class _DynamicGyroLeveler extends StatelessWidget {
  const _DynamicGyroLeveler({
    required this.attitude,
    required this.motionReady,
    required this.motionDenied,
    required this.motionBusy,
    required this.needsPermissionPrompt,
    required this.onEnableMotion,
  });

  final GuideDeviceAttitude? attitude;
  final bool motionReady;
  final bool motionDenied;
  final bool motionBusy;
  final bool needsPermissionPrompt;
  final VoidCallback onEnableMotion;

  static const _emerald = Color(0xFF00D289);
  static const _glass = Color(0x66FFFFFF);

  bool get _leveled {
    final a = attitude;
    if (a == null) return false;
    return a.roll.abs() <= _kLevelToleranceDeg;
  }

  @override
  Widget build(BuildContext context) {
    final showPrompt = needsPermissionPrompt || motionDenied;
    final live = motionReady && attitude != null;
    final leveled = live && _leveled;
    final color = leveled ? _emerald : _glass;
    // Roll(도)만 사용 — Pitch는 수평계 UI에서 제외
    final rollDeg = attitude?.roll ?? 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 고정 가이드: 중앙을 가로지르는 양옆 분리 얇은 선
        CustomPaint(
          painter: _FixedHorizonGuidesPainter(color: color, glow: leveled),
          child: const SizedBox.expand(),
        ),
        // 회전하는 단일 가로 막대 (Roll만)
        if (live)
          Center(
            child: AnimatedRotation(
              turns: rollDeg / 360.0,
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              child: CustomPaint(
                size: const Size(180, 24),
                painter: _RollBarPainter(color: color, glow: leveled),
              ),
            ),
          ),
        // iOS 모션 권한 탭 게이트
        if (showPrompt)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: motionBusy ? null : onEnableMotion,
                  borderRadius: BorderRadius.circular(22),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (motionBusy)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            )
                          else
                            Icon(
                              Icons.screen_rotation_alt_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          const SizedBox(width: 10),
                          Text(
                            motionDenied
                                ? '모션 권한 거부됨 · 다시 탭'
                                : '탭하여 수평계(자이로) 활성화',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 화면 정중앙 — 좌/우로 분리된 고정 가로 가이드선.
class _FixedHorizonGuidesPainter extends CustomPainter {
  _FixedHorizonGuidesPainter({required this.color, required this.glow});

  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = glow ? 2.0 : 1.4
      ..strokeCap = StrokeCap.round;

    if (glow) {
      final glowPaint = Paint()
        ..color = const Color(0xFF00D289).withValues(alpha: 0.35)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawLine(Offset(cx - 92, cy), Offset(cx - 28, cy), glowPaint);
      canvas.drawLine(Offset(cx + 28, cy), Offset(cx + 92, cy), glowPaint);
    }

    // 양옆 분리 (중앙 갭 — 회전 막대가 겹치는 자리)
    canvas.drawLine(Offset(cx - 88, cy), Offset(cx - 30, cy), paint);
    canvas.drawLine(Offset(cx + 30, cy), Offset(cx + 88, cy), paint);
  }

  @override
  bool shouldRepaint(covariant _FixedHorizonGuidesPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.glow != glow;
  }
}

/// Roll에 따라 Transform.rotate 되는 단일 가로 막대.
class _RollBarPainter extends CustomPainter {
  _RollBarPainter({required this.color, required this.glow});

  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = glow ? 2.6 : 2.0
      ..strokeCap = StrokeCap.round;

    if (glow) {
      canvas.drawLine(
        Offset(8, cy),
        Offset(size.width - 8, cy),
        Paint()
          ..color = const Color(0xFF00D289).withValues(alpha: 0.4)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.drawLine(Offset(8, cy), Offset(size.width - 8, cy), paint);
    // 중앙 틱
    canvas.drawCircle(
      Offset(size.width / 2, cy),
      glow ? 3.2 : 2.4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RollBarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.glow != glow;
  }
}

class _DecolleteGuidePainter extends CustomPainter {
  _DecolleteGuidePainter({required this.attitude});

  final GuideDeviceAttitude? attitude;

  static const _emeraldGlow = Color(0xFF00D289);

  bool get _leveled {
    final a = attitude;
    if (a == null) return false;
    return a.roll.abs() <= _kLevelToleranceDeg;
  }

  Color get _guideColor {
    if (_leveled) return _emeraldGlow.withValues(alpha: 0.92);
    return Colors.white.withValues(alpha: 0.42);
  }

  void _strokePath(Canvas canvas, Path path, Color color, {double width = 2.0}) {
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final color = _guideColor;

    if (_leveled) {
      // 에메랄드 글로우 — 수평 맞춤 시
      final glowY = h * 0.34;
      canvas.drawLine(
        Offset(w * 0.08, glowY),
        Offset(w * 0.92, glowY),
        Paint()
          ..color = _emeraldGlow.withValues(alpha: 0.28)
          ..strokeWidth = 14
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // 어깨 라인 — 완만한 곡선 (반응형)
    final shoulderY = h * 0.38;
    final shoulderPath = Path()
      ..moveTo(w * 0.06, shoulderY + h * 0.04)
      ..quadraticBezierTo(
        cx,
        shoulderY - h * 0.02,
        w * 0.94,
        shoulderY + h * 0.04,
      );
    _strokePath(canvas, shoulderPath, color, width: _leveled ? 2.4 : 1.8);

    // 쇄골 V 라인 (좌·우)
    final neckY = h * 0.22;
    final collarY = h * 0.34;
    final leftCollar = Path()
      ..moveTo(cx, neckY)
      ..quadraticBezierTo(w * 0.28, collarY, w * 0.12, shoulderY);
    final rightCollar = Path()
      ..moveTo(cx, neckY)
      ..quadraticBezierTo(w * 0.72, collarY, w * 0.88, shoulderY);
    _strokePath(canvas, leftCollar, color, width: _leveled ? 2.2 : 1.6);
    _strokePath(canvas, rightCollar, color, width: _leveled ? 2.2 : 1.6);

    // 쇄골 수평 가이드 — 자이로 수평계와 동일 ±1.5° 기준
    final horizY = collarY;
    final horizPath = Path()
      ..moveTo(w * 0.14, horizY)
      ..lineTo(w * 0.86, horizY);
    _strokePath(canvas, horizPath, color, width: _leveled ? 2.6 : 1.8);

    // 데콜테 하단 곡선
    final decolletePath = Path()
      ..moveTo(w * 0.18, shoulderY + h * 0.06)
      ..quadraticBezierTo(
        cx,
        shoulderY + h * 0.18,
        w * 0.82,
        shoulderY + h * 0.06,
      );
    _strokePath(canvas, decolletePath, color.withValues(alpha: 0.75), width: 1.6);
  }

  @override
  bool shouldRepaint(covariant _DecolleteGuidePainter oldDelegate) {
    final a = attitude;
    final b = oldDelegate.attitude;
    if (identical(a, b)) return false;
    if (a == null || b == null) return a != b;
    return a.roll != b.roll || a.pitch != b.pitch;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.kindLabel,
    required this.onClose,
    this.showGhostToggle = false,
    this.ghostOn = false,
    this.onGhostToggle,
  });

  final String kindLabel;
  final VoidCallback onClose;
  final bool showGhostToggle;
  final bool ghostOn;
  final VoidCallback? onGhostToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
            Expanded(
              child: Text(
                kindLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            if (showGhostToggle)
              IconButton(
                onPressed: onGhostToggle,
                icon: Icon(
                  ghostOn ? Icons.layers_rounded : Icons.layers_outlined,
                  color: ghostOn
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                ),
                tooltip: ghostOn ? '잔상 끄기' : '잔상 켜기',
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

/// 원형 뷰파인더 — 정밀 가이드는 원 내부에만 배치.
class _CircularFaceAlignPainter extends CustomPainter {
  _CircularFaceAlignPainter({
    required this.pose,
    required this.mirrored,
  });

  final GuideFacePose pose;
  final bool mirrored;

  Color _borderColor(bool aligned) {
    if (!pose.detected) {
      return Colors.white.withValues(alpha: 0.55);
    }
    return aligned
        ? SoriTokens.primaryLight.withValues(alpha: 0.92)
        : const Color(0xFFFBBF24).withValues(alpha: 0.95);
  }

  /// 원 내부 보조선 — 정렬 시 글래스 에메랄드.
  Color _innerGuideColor(bool aligned) {
    if (aligned) {
      return SoriTokens.primary.withValues(alpha: 0.42);
    }
    if (pose.detected) {
      return const Color(0xFFFBBF24).withValues(alpha: 0.34);
    }
    return Colors.white.withValues(alpha: 0.34);
  }

  /// 원형 상단 ~37% 지점 — 눈높이 수평 점선 (원 현 폭에 맞춤).
  void _drawEyeLevelGuideline(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    const fromTop = 0.37; // 원 직경 기준 상단 35~40%
    final eyeY = center.dy - radius + (2 * radius * fromTop);
    final dy = eyeY - center.dy;
    final halfChord = math.sqrt(math.max(0, radius * radius - dy * dy));
    // 테두리와 살짝 간격
    final halfW = halfChord * 0.88;
    if (halfW < 8) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const dash = 5.0;
    const gap = 4.0;
    var x = center.dx - halfW;
    final endX = center.dx + halfW;
    while (x < endX) {
      final x2 = math.min(x + dash, endX);
      canvas.drawLine(Offset(x, eyeY), Offset(x2, eyeY), paint);
      x += dash + gap;
    }
  }

  /// 원 하단 안쪽 — 턱끝 안착용 연한 호.
  void _drawChinArcGuide(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    // 턱선: 원 중심보다 아래, 테두리에서 안쪽으로 inset
    final chinR = radius * 0.72;
    final chinCy = center.dy + radius * 0.18;
    final rect = Rect.fromCircle(center: Offset(center.dx, chinCy), radius: chinR);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    // 하단 호만 (약 110°)
    canvas.drawArc(rect, math.pi * 0.22, math.pi * 0.56, false, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.46;
    final radius = math.min(size.width, size.height) * 0.36;
    final center = Offset(cx, cy);
    final aligned = pose.isAligned;
    final borderColor = _borderColor(aligned);
    final innerColor = _innerGuideColor(aligned);

    // 원 밖 딤
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(
      dim,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );

    // 소프트 글로우 (테두리만 — 가이드 요소 아님)
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = borderColor.withValues(alpha: aligned ? 0.28 : 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? 18 : 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? 4.5 : 3.2,
    );

    // —— 원 내부 정밀 가이드만 ——
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius - 1.5)),
    );

    _drawEyeLevelGuideline(canvas, center, radius, innerColor);
    _drawChinArcGuide(canvas, center, radius, innerColor);

    // 미정렬 시 원 안쪽 방향 힌트 (외곽 화살표 제거)
    if (pose.detected && !aligned) {
      final yaw = mirrored ? -pose.yaw : pose.yaw;
      final pitch = pose.pitch;
      final roll = pose.roll;
      const tol = GuideFacePose.alignToleranceDeg;
      final hint = const Color(0xFFFBBF24).withValues(alpha: 0.40);
      final hintPaint = Paint()
        ..color = hint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;

      void drawInnerChevron(Offset tip, double angleRad) {
        canvas.save();
        canvas.translate(tip.dx, tip.dy);
        canvas.rotate(angleRad);
        final path = Path()
          ..moveTo(0, -7)
          ..lineTo(5.5, 5)
          ..moveTo(0, -7)
          ..lineTo(-5.5, 5);
        canvas.drawPath(path, hintPaint);
        canvas.restore();
      }

      final inset = radius * 0.78;
      if (yaw.abs() > tol) {
        final dir = yaw > 0 ? 1.0 : -1.0;
        drawInnerChevron(
          Offset(cx + dir * inset, cy),
          dir > 0 ? math.pi / 2 : -math.pi / 2,
        );
      }
      if (pitch.abs() > tol) {
        final dir = pitch > 0 ? 1.0 : -1.0;
        drawInnerChevron(
          Offset(cx, cy + dir * inset),
          dir > 0 ? math.pi : 0,
        );
      }
      if (roll.abs() > tol) {
        final sweep = (roll.clamp(-35, 35) / 35) * (math.pi * 0.4);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius * 0.82),
          -math.pi / 2,
          sweep,
          false,
          hintPaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CircularFaceAlignPainter oldDelegate) {
    return oldDelegate.pose.detected != pose.detected ||
        oldDelegate.pose.inCircle != pose.inCircle ||
        oldDelegate.pose.isAligned != pose.isAligned ||
        oldDelegate.pose.pitch != pose.pitch ||
        oldDelegate.pose.yaw != pose.yaw ||
        oldDelegate.pose.roll != pose.roll ||
        oldDelegate.mirrored != mirrored;
  }
}

class _BodyGuidePainter extends CustomPainter {
  _BodyGuidePainter({required this.preset});

  final GuidePreset preset;

  void _stroke(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    switch (preset) {
      case GuidePreset.face:
      case GuidePreset.decollete:
        return;
      case GuidePreset.abdomen:
        _stroke(
          canvas,
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset(cx, cy),
                  width: size.width * 0.58,
                  height: size.height * 0.48,
                ),
                const Radius.circular(18),
              ),
            ),
        );
      case GuidePreset.lowerBody:
        _stroke(
          canvas,
          Path()
            ..moveTo(cx, size.height * 0.12)
            ..lineTo(cx, size.height * 0.9),
        );
      case GuidePreset.fullBody:
        _stroke(
          canvas,
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset(cx, cy),
                  width: size.width * 0.4,
                  height: size.height * 0.78,
                ),
                const Radius.circular(22),
              ),
            ),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _BodyGuidePainter oldDelegate) {
    return oldDelegate.preset != preset;
  }
}

