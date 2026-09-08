import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/chart_photo_compressor.dart';
import '../services/chart_photo_storage.dart';
import '../services/guide_body_align.dart';
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

const _kLevelEnterDeg = 2.0;
const _kLevelExitDeg = 2.5;
const _kRollDeadzoneDeg = 0.4;
const _kRollEmaAlpha = 0.15;

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

  /// MediaPipe 정렬 — 페이스. 데콜테는 어깨 확인용으로 얼굴도 당분간 병행한다.
  bool get usesFaceAlign =>
      this == GuidePreset.face || this == GuidePreset.decollete;

  /// MediaPipe 포즈 정렬 — 데콜테/복부/하체/전신. 이 프리셋을 고를 때만 모델을 받는다.
  GuideBodyTarget? get bodyTarget => switch (this) {
        GuidePreset.face => null,
        GuidePreset.decollete => GuideBodyTarget.decollete,
        GuidePreset.abdomen => GuideBodyTarget.abdomen,
        GuidePreset.lowerBody => GuideBodyTarget.lowerBody,
        GuidePreset.fullBody => GuideBodyTarget.fullBody,
      };

  bool get usesBodyAlign => bodyTarget != null;

  /// 시안 viewBox(0..160) 기준 강조 구간. 데콜테는 얼굴을 빼 목~어깨만.
  (double, double) get highlightZoneY => switch (this) {
        GuidePreset.face => (2, 40),
        GuidePreset.decollete => (30, 72),
        GuidePreset.abdomen => (44, 100),
        GuidePreset.lowerBody => (99, 158),
        GuidePreset.fullBody => (2, 158),
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
  late final GuideBodyAlign _bodyAlign;
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
  double _rollSmoothed = 0;
  bool _wasLevel = false;
  bool _motionReady = false;
  bool _motionDenied = false;
  bool _motionBusy = false;
  GuideFacePose _facePose = GuideFacePose.none;
  Size _viewfinderSize = GuideFacePose.referenceFrame;
  double _zoom = GuideCameraZoomMemory.defaultZoom;
  _ShutterTimerDelay _timerDelay = _ShutterTimerDelay.off;
  bool _autoShootEnabled = false;
  StreamSubscription<GuideDeviceAttitude?>? _attitudeSub;
  StreamSubscription<GuideFacePose>? _poseSub;
  StreamSubscription<GuideBodyPose>? _bodyPoseSub;
  GuideBodyPose _bodyPose = GuideBodyPose.none;
  final _bodyProbe = _BodyAlignProbe();
  bool _bodyLoading = false;
  Timer? _timer;
  Timer? _autoShootHoldTimer;
  Timer? _zoomSaveTimer;

  bool get _isAfter => widget.kind == GuideCameraKind.after;
  bool get _canGhost {
    final u = widget.ghostBeforeUrl?.trim() ?? '';
    return _isAfter && u.isNotEmpty;
  }

  bool get _faceAlignActive => _preset.usesFaceAlign;
  bool get _bodyAlignActive => _preset.usesBodyAlign;

  /// 카메라/ML 준비 전에는 하단 조작 비활성.
  bool get _controlsLocked =>
      _starting || _mlLoading || _busy || _viewType == null || _countdown != null;

  List<GuidePreset> get _presets => GuidePreset.values;

  @override
  void initState() {
    super.initState();
    _session = createGuideCameraSession();
    _faceAlign = createGuideFaceAlign();
    // 객체만 만든다. 모델 다운로드는 몸 프리셋을 고를 때 prepare()에서 시작한다.
    _bodyAlign = createGuideBodyAlign();
    if (_isAfter && !_canGhost) {
      _ghostOn = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoShootHoldTimer?.cancel();
    _zoomSaveTimer?.cancel();
    _attitudeSub?.cancel();
    _poseSub?.cancel();
    _bodyPoseSub?.cancel();
    _faceAlign.dispose();
    _bodyAlign.dispose();
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
      _bodyPose = GuideBodyPose.none;
      _bodyProbe.reset();
    });
    await _faceAlign.stop();
    await _bodyAlign.stop();

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
      _poseSub = _faceAlign.poses.listen(_onFacePose);
      await _bodyPoseSub?.cancel();
      _bodyPoseSub = _bodyAlign.poses.listen(_onBodyPose);
      if (_bodyAlignActive) unawaited(_startBodyAlign());

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

  /// 몸 프리셋을 고른 순간에만 모델을 받는다 — 얼굴만 찍는 동안은 부르지 않는다.
  Future<void> _startBodyAlign() async {
    if (!mounted) return;
    setState(() => _bodyLoading = true);
    try {
      await _bodyAlign.prepare();
      final video = _session.mlVideoHandle;
      if (video != null) await _bodyAlign.start(video);
    } catch (e) {
      debugPrint('body align start failed: $e');
    } finally {
      if (mounted) setState(() => _bodyLoading = false);
    }
  }

  Future<void> _stopBodyAlign() async {
    await _bodyAlign.stop();
    if (!mounted) return;
    setState(() {
      _bodyLoading = false;
      _bodyPose = GuideBodyPose.none;
      _bodyProbe.reset();
    });
  }

  void _onBodyPose(GuideBodyPose next) {
    if (!mounted) return;
    final target = _preset.bodyTarget;
    if (target == null) return;
    _bodyProbe.add(next, target, _viewfinderSize, mirrored: _faceMirrored);
    if (_preset == GuidePreset.decollete) {
      final wasAligned = _faceAligned;
      setState(() => _bodyPose = next);
      final aligned = next.computeDecolleteAligned(
        _viewfinderSize,
        mirrored: _faceMirrored,
      );
      if (aligned && !wasAligned) {
        HapticFeedback.mediumImpact();
        soriLightHaptic();
        _scheduleAutoShootIfEnabled();
      } else if (!aligned) {
        _cancelAutoShootSchedule();
      }
      return;
    }
    setState(() => _bodyPose = next);
  }

  /// 프로토타입 단계 안내 — 아직 정렬 판정은 하지 않는다.
  String? get _bodyHintText {
    if (!_bodyAlignActive) return null;
    if (_bodyLoading) return '포즈 AI 준비 중';
    final target = _preset.bodyTarget!;
    if (!_bodyPose.detected) return '몸 전체가 화면에 들어오게 서 주세요';
    if (!_bodyPose.hasPointsFor(target)) {
      return switch (target) {
        GuideBodyTarget.decollete => '어깨가 화면에 다 보이게',
        GuideBodyTarget.abdomen => '어깨·골반이 화면에 다 보이게',
        GuideBodyTarget.lowerBody => '골반·발목이 화면에 다 보이게',
        GuideBodyTarget.fullBody => '어깨·발목이 화면에 다 보이게',
      };
    }
    return '인식 ${_bodyProbe.detectRatePercent}% · 흔들림 '
        '${_bodyProbe.jitterPx.toStringAsFixed(1)}px';
  }

  bool get _faceMirrored => _mode == GuideCaptureMode.selfFront;

  bool get _faceAligned {
    if (_preset == GuidePreset.decollete) {
      return _bodyPose.computeDecolleteAligned(
        _viewfinderSize,
        mirrored: _faceMirrored,
      );
    }
    return _facePose.computeAligned(
      _viewfinderSize,
      mirrored: _faceMirrored,
    );
  }

  void _onFacePose(GuideFacePose next) {
    if (!mounted) return;
    if (_preset == GuidePreset.decollete) {
      setState(() => _facePose = next);
      return;
    }
    final wasAligned = _faceAligned;
    setState(() => _facePose = next);
    final aligned =
        next.computeAligned(_viewfinderSize, mirrored: _faceMirrored);

    if (aligned && !wasAligned) {
      HapticFeedback.mediumImpact();
      soriLightHaptic();
      _scheduleAutoShootIfEnabled();
    } else if (!aligned) {
      _cancelAutoShootSchedule();
    }
  }

  void _toggleAutoShoot() {
    if (_controlsLocked) return;
    setState(() => _autoShootEnabled = !_autoShootEnabled);
    if (_autoShootEnabled && _faceAligned) {
      _scheduleAutoShootIfEnabled();
    } else {
      _cancelAutoShootSchedule();
    }
    HapticFeedback.selectionClick();
  }

  void _scheduleAutoShootIfEnabled() {
    _cancelAutoShootSchedule();
    if (!_autoShootEnabled ||
        !_faceAlignActive ||
        _mlLoading ||
        (_preset == GuidePreset.decollete && _bodyLoading) ||
        _busy ||
        _countdown != null) {
      return;
    }
    _autoShootHoldTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted ||
          !_autoShootEnabled ||
          !_faceAligned ||
          _busy ||
          _countdown != null) {
        return;
      }
      _startTimerCapture(3);
    });
  }

  void _cancelAutoShootSchedule() {
    _autoShootHoldTimer?.cancel();
    _autoShootHoldTimer = null;
  }

  String? get _dockHint {
    if (_preset == GuidePreset.decollete) return _faceHintText;
    if (_bodyAlignActive) return _bodyHintText;
    return _faceHintText;
  }

  String? get _faceHintText {
    if (_preset == GuidePreset.decollete) {
      if (_bodyLoading) return '포즈 AI 준비 중';
      if (!_bodyPose.detected) return '어깨가 보이게 서 주세요';
      if (!_bodyPose.hasPointsFor(GuideBodyTarget.decollete)) {
        return '양쪽 어깨가 화면에 다 보이게';
      }
      if (!_bodyPose.isDecolletePositionAligned(
        _viewfinderSize,
        mirrored: _faceMirrored,
      )) {
        return '촬영 거리(크기)를 맞춰 주세요';
      }
      if (!_bodyPose.isDecolleteScaleAligned(_viewfinderSize)) {
        final dir = _bodyPose.decolleteScaleDirection(_viewfinderSize);
        if (dir > 0) return '조금 더 가까이 오세요';
        if (dir < 0) return '조금 더 멀리 움직이세요';
        return '촬영 거리(크기)를 맞춰 주세요';
      }
      return _autoShootEnabled ? '거리·중심 정렬됨 · 자동 촬영 대기' : '거리·중심 정렬됨';
    }
    if (!_faceAlignActive) return null;
    if (_mlLoading) return 'AI 준비 중';
    if (!_facePose.detected) return '얼굴을 찾는 중';
    if (!_facePose.isPositionAligned(_viewfinderSize, mirrored: _faceMirrored)) {
      return '얼굴을 중앙에 두세요';
    }
    final scaleDir = _facePose.scaleDirection(_viewfinderSize);
    if (scaleDir > 0) return '조금 더 가까이 오세요';
    if (scaleDir < 0) return '조금 더 멀리 움직이세요';
    if (!_facePose.computeAligned(_viewfinderSize, mirrored: _faceMirrored)) {
      return '거의 맞았어요';
    }
    return _autoShootEnabled ? '정렬됨 · 자동 촬영 대기' : '정렬됨';
  }

  Color get _decolleteGuideColor {
    if (_faceAligned) return SoriTokens.cameraYellow;
    return Colors.white.withValues(alpha: 0.4);
  }

  Color get _faceProximityColor {
    if (!_facePose.detected) return SoriTokens.alignCold;
    if (_facePose.computeAligned(_viewfinderSize, mirrored: _faceMirrored)) {
      return SoriTokens.cameraYellow;
    }
    final d = _facePose.alignmentDistance(
      _viewfinderSize,
      mirrored: _faceMirrored,
    );
    if (d <= 1.35) return SoriTokens.alignWarm;
    return SoriTokens.alignCold;
  }

  void _onAttitude(GuideDeviceAttitude? next) {
    if (!mounted) return;
    if (next == null) {
      setState(() => _attitude = null);
      return;
    }

    // EMA low-pass (α≈0.15) — 손떨림 노이즈 억제
    var roll = _kRollEmaAlpha * next.roll + (1 - _kRollEmaAlpha) * _rollSmoothed;
    // Deadzone snap
    if (roll.abs() < _kRollDeadzoneDeg) roll = 0;

    // 미세 변화 스킵 (스무딩 이후 기준)
    if ((roll - _rollSmoothed).abs() < 0.05 && _attitude != null) {
      final stillLeveled = _wasLevel
          ? roll.abs() <= _kLevelExitDeg
          : roll.abs() <= _kLevelEnterDeg;
      if (stillLeveled == _wasLevel) return;
    }

    // 히스테리시스: 진입 ±2.0° / 이탈 ±2.5°
    final leveled = _wasLevel
        ? roll.abs() <= _kLevelExitDeg
        : roll.abs() <= _kLevelEnterDeg;
    if (leveled) roll = 0; // ±2.0° 이내 진입 시 0° 스냅
    if (leveled && !_wasLevel) {
      HapticFeedback.lightImpact();
      soriLightHaptic();
    }
    _wasLevel = leveled;
    _rollSmoothed = roll;
    setState(() {
      _attitude = GuideDeviceAttitude(roll: roll, pitch: next.pitch);
      _motionReady = true;
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
      _bodyPose = GuideBodyPose.none;
      _bodyProbe.reset();
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
    if (p.usesBodyAlign) {
      await _startBodyAlign();
    } else {
      await _stopBodyAlign();
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
    _cancelAutoShootSchedule();
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
            backgroundColor: SoriTokens.systemRed,
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
            backgroundColor: SoriTokens.systemRed,
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
          backgroundColor: SoriTokens.systemRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closePage() async {
    _timer?.cancel();
    _cancelAutoShootSchedule();
    _zoomSaveTimer?.cancel();
    await _poseSub?.cancel();
    await _bodyPoseSub?.cancel();
    await _attitudeSub?.cancel();
    await _faceAlign.stop();
    await _bodyAlign.stop();
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
          unawaited(_bodyAlign.stop());
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
          autoShootEnabled: _autoShootEnabled,
          onAutoShootToggle: _toggleAutoShoot,
          onShutter: _onShutterPressed,
          onFlip: () => unawaited(_toggleCameraFacing()),
          faceHint: _dockHint,
          faceAligned: _faceAligned && !_mlLoading && !_bodyLoading,
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
                    autoShootEnabled: _autoShootEnabled,
                    onAutoShootToggle: _toggleAutoShoot,
                    onShutter: _onShutterPressed,
                    onFlip: () => unawaited(_toggleCameraFacing()),
                    faceHint: _dockHint,
                    faceAligned: _faceAligned && !_mlLoading && !_bodyLoading,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              if (_viewfinderSize != size) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _viewfinderSize = size);
                });
              }
              return ClipRect(child: _buildViewfinderStack(size));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildViewfinderStack(Size viewfinderSize) {
    return Stack(
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
                // 프리셋 가이드 — 페이스/데콜테는 항상 선명하게 표시
                if (_preset == GuidePreset.face)
                  IgnorePointer(
                    ignoring: true,
                    child: _FaceAlignGuideLayer(
                      pose: _facePose,
                      mirrored: _mode == GuideCaptureMode.selfFront,
                      proximityColor: _faceProximityColor,
                    ),
                  )
                else if (_preset == GuidePreset.decollete)
                  IgnorePointer(
                    ignoring: true,
                    child: _DecolleteAlignGuideLayer(
                      pose: _bodyPose,
                      mirrored: _mode == GuideCaptureMode.selfFront,
                      guideColor: _decolleteGuideColor,
                      aligned: _faceAligned,
                    ),
                  )
                else ...[
                  IgnorePointer(
                    ignoring: true,
                    child: CustomPaint(
                      painter: _BodyGuidePainter(preset: _preset),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  // 1단계 프로토타입 — 인식 좌표를 점으로 찍어 흔들림을 눈으로 본다.
                  if (_preset.bodyTarget case final target?)
                    IgnorePointer(
                      ignoring: true,
                      child: CustomPaint(
                        key: const Key('body-landmark-probe'),
                        painter: _BodyLandmarkProbePainter(
                          pose: _bodyPose,
                          target: target,
                          mirrored: _faceMirrored,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  if (_bodyAlignActive)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: IgnorePointer(
                        ignoring: true,
                        child: _BodyProbeReadout(
                          loading: _bodyLoading,
                          pose: _bodyPose,
                          probe: _bodyProbe,
                        ),
                      ),
                    ),
                ],
                // Roll bar — face/body only; decollete uses distance+center lock.
                if (_preset != GuidePreset.decollete)
                  IgnorePointer(
                    ignoring: _motionReady && _attitude != null,
                    child: _DynamicGyroLeveler(
                      attitude: _attitude,
                      leveled: _wasLevel,
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
    required this.autoShootEnabled,
    required this.onAutoShootToggle,
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
  final bool autoShootEnabled;
  final VoidCallback onAutoShootToggle;
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: faceAligned
                          ? SoriTokens.cameraYellow
                          : Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  height: 52,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < presets.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
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
                            padding: const EdgeInsets.only(right: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _TimerToggleButton(
                                  delay: timerDelay,
                                  onTap: onTimerCycle,
                                ),
                                const SizedBox(width: 8),
                                _AutoShootToggleButton(
                                  enabled: autoShootEnabled,
                                  onTap: onAutoShootToggle,
                                ),
                              ],
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

class _AutoShootToggleButton extends StatelessWidget {
  const _AutoShootToggleButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: enabled ? '자동 촬영 켜짐' : '자동 촬영 꺼짐',
      selected: enabled,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? SoriTokens.cameraYellow.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: enabled
                  ? SoriTokens.cameraYellow
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Icon(
            Icons.auto_fix_high_rounded,
            size: 22,
            color: enabled
                ? SoriTokens.cameraYellow
                : Colors.white.withValues(alpha: 0.55),
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: preset.label,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GuidePresetZoneIcon(preset: preset, selected: selected),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 16 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: selected ? SoriTokens.cameraYellow : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 같은 사람 실루엣 + 촬영 부위만 강조. 시안 viewBox 80×160.
class GuidePresetZoneIcon extends StatelessWidget {
  const GuidePresetZoneIcon({
    super.key,
    required this.preset,
    required this.selected,
  });

  final GuidePreset preset;
  final bool selected;

  static const double width = 18;
  static const double height = 32;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(width, height),
      painter: _PresetZonePainter(preset: preset, selected: selected),
    );
  }
}

class _PresetZonePainter extends CustomPainter {
  _PresetZonePainter({required this.preset, required this.selected});

  final GuidePreset preset;
  final bool selected;

  static const _viewW = 80.0;
  static const _viewH = 160.0;

  static Path silhouette() {
    final p = Path();
    p.addOval(Rect.fromCircle(center: const Offset(40, 22), radius: 16));
    p.addRect(const Rect.fromLTRB(34, 36, 46, 46));
    p
      ..moveTo(20, 46)
      ..quadraticBezierTo(18, 44, 20, 44)
      ..lineTo(60, 44)
      ..quadraticBezierTo(62, 44, 60, 46)
      ..lineTo(58, 60)
      ..quadraticBezierTo(60, 78, 56, 96)
      ..lineTo(52, 100)
      ..lineTo(28, 100)
      ..lineTo(24, 96)
      ..quadraticBezierTo(20, 78, 22, 60)
      ..close();
    p
      ..moveTo(25, 100)
      ..lineTo(37, 100)
      ..lineTo(36, 156)
      ..quadraticBezierTo(36, 160, 32, 160)
      ..lineTo(28, 160)
      ..quadraticBezierTo(25, 160, 25, 156)
      ..close();
    p
      ..moveTo(43, 100)
      ..lineTo(55, 100)
      ..lineTo(56, 156)
      ..quadraticBezierTo(56, 160, 52, 160)
      ..lineTo(48, 160)
      ..quadraticBezierTo(45, 160, 44, 156)
      ..close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / _viewW, size.height / _viewH);
    final dx = (size.width - _viewW * scale) / 2;
    final dy = (size.height - _viewH * scale) / 2;
    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    final body = silhouette();
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: selected ? 0.38 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(body, stroke);

    final (y0, y1) = preset.highlightZoneY;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, y0, _viewW, y1 - y0));
    final accent = selected
        ? SoriTokens.cameraYellow
        : SoriTokens.cameraYellow.withValues(alpha: 0.42);
    canvas.drawPath(
      body,
      Paint()
        ..color = accent.withValues(alpha: selected ? 0.92 : 0.55)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PresetZonePainter oldDelegate) {
    return oldDelegate.preset != preset || oldDelegate.selected != selected;
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

/// 1축(Roll) 가로 막대 수평계 — iPhone 카메라 스타일 + EMA 스무딩.
class _DynamicGyroLeveler extends StatelessWidget {
  const _DynamicGyroLeveler({
    required this.attitude,
    required this.leveled,
    required this.motionReady,
    required this.motionDenied,
    required this.motionBusy,
    required this.needsPermissionPrompt,
    required this.onEnableMotion,
  });

  final GuideDeviceAttitude? attitude;
  final bool leveled;
  final bool motionReady;
  final bool motionDenied;
  final bool motionBusy;
  final bool needsPermissionPrompt;
  final VoidCallback onEnableMotion;

  static const _cameraYellow = SoriTokens.cameraYellow;
  static const _glass = Color(0x66FFFFFF);

  @override
  Widget build(BuildContext context) {
    final showPrompt = needsPermissionPrompt || motionDenied;
    final live = motionReady && attitude != null;
    final color = leveled ? SoriTokens.cameraYellow : _glass;
    final rollDeg = attitude?.roll ?? 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _FixedHorizonGuidesPainter(color: color),
          child: const SizedBox.expand(),
        ),
        if (live)
          Center(
            child: AnimatedRotation(
              turns: rollDeg / 360.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: CustomPaint(
                size: const Size(200, 24),
                painter: _RollBarPainter(color: color),
              ),
            ),
          ),
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
  _FixedHorizonGuidesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx - 88, cy), Offset(cx - 30, cy), paint);
    canvas.drawLine(Offset(cx + 30, cy), Offset(cx + 88, cy), paint);
  }

  @override
  bool shouldRepaint(covariant _FixedHorizonGuidesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Roll에 따라 Transform.rotate 되는 단일 가로 막대.
class _RollBarPainter extends CustomPainter {
  _RollBarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(8, cy), Offset(size.width - 8, cy), paint);
    canvas.drawCircle(
      Offset(size.width / 2, cy),
      3.0,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RollBarPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DecolleteAlignGuideLayer extends StatelessWidget {
  const _DecolleteAlignGuideLayer({
    required this.pose,
    required this.mirrored,
    required this.guideColor,
    required this.aligned,
  });

  final GuideBodyPose pose;
  final bool mirrored;
  final Color guideColor;
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final target = pose.decolleteTargetCenterPx(size);
        final targetR = pose.decolleteTargetRadiusPx(size);
        final snap = pose.isDecolleteInSnapZone(size, mirrored: mirrored);
        final liveC = pose.centerPx(
              GuideBodyTarget.decollete,
              size,
              mirrored: mirrored,
            ) ??
            target;
        final dynR = pose.decolleteDynamicRadiusPx(size);

        final displayC = (snap || aligned) ? target : liveC;
        final displayR = (snap || aligned) ? targetR : dynR;
        final animateSnap = snap || aligned;

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _DecolleteGuidePainter(
                aligned: aligned,
                guideColor: guideColor,
                showStaticRing: true,
                staticCenter: target,
                staticRadius: targetR,
              ),
              child: const SizedBox.expand(),
            ),
            if (pose.detected && displayR > 0)
              AnimatedPositioned(
                duration: Duration(milliseconds: animateSnap ? 260 : 70),
                curve: animateSnap ? Curves.easeOutBack : Curves.linear,
                left: displayC.dx - displayR,
                top: displayC.dy - displayR,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: animateSnap ? 260 : 70),
                  curve: animateSnap ? Curves.easeOutBack : Curves.linear,
                  width: displayR * 2,
                  height: displayR * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    border: Border.all(
                      color: guideColor,
                      width: aligned ? 2.8 : 2.0,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DecolleteGuidePainter extends CustomPainter {
  _DecolleteGuidePainter({
    required this.aligned,
    required this.guideColor,
    this.showStaticRing = false,
    this.staticCenter,
    this.staticRadius = 0,
  });

  final bool aligned;
  final Color guideColor;
  final bool showStaticRing;
  final Offset? staticCenter;
  final double staticRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // 상반신 비율 — 안전 영역과 어깨 수평선의 기준이다.
    final headTop = h * 0.08;
    final shoulderY = h * 0.42;
    final shoulderLeft = w * 0.10;
    final shoulderRight = w * 0.90;
    final torsoBottom = h * 0.64;

    // Soft vignette only (dim outside frame) — not a filled silhouette.
    final safe = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(shoulderLeft, headTop, shoulderRight, torsoBottom),
          const Radius.circular(20),
        ),
      );
    canvas.drawPath(
      safe,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    final strokeColor =
        aligned ? guideColor : Colors.white.withValues(alpha: 0.4);

    // 머리·목·어깨 손그림은 그리지 않는다. 어깨 수평선만 남겨 수평을 잡는다.
    canvas.drawLine(
      Offset(shoulderLeft, shoulderY),
      Offset(shoulderRight, shoulderY),
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? 2.6 : 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Static target ring (dashed) — scale reference, stroke only
    if (showStaticRing && staticCenter != null && staticRadius > 0) {
      final ringPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? 2.4 : 1.5
        ..strokeCap = StrokeCap.round;
      const segments = 48;
      const dashRatio = 0.55;
      for (var i = 0; i < segments; i++) {
        final start = (i / segments) * 2 * math.pi;
        final sweep = (2 * math.pi / segments) * dashRatio;
        canvas.drawArc(
          Rect.fromCircle(center: staticCenter!, radius: staticRadius),
          start,
          sweep,
          false,
          ringPaint,
        );
      }
    }

    // Faint center axis
    canvas.drawLine(
      Offset(cx, headTop),
      Offset(cx, torsoBottom),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _DecolleteGuidePainter oldDelegate) {
    return oldDelegate.aligned != aligned ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.showStaticRing != showStaticRing ||
        oldDelegate.staticCenter != staticCenter ||
        oldDelegate.staticRadius != staticRadius;
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

/// Face viewfinder — fixed guides + ghost silhouette + magnet-snap track circle.
class _FaceAlignGuideLayer extends StatelessWidget {
  const _FaceAlignGuideLayer({
    required this.pose,
    required this.mirrored,
    required this.proximityColor,
  });

  final GuideFacePose pose;
  final bool mirrored;
  final Color proximityColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final target = pose.targetCenterPx(size);
        final innerR = pose.innerTargetRadiusPx(size);
        final snap = pose.isInSnapZone(size, mirrored: mirrored);
        final aligned = pose.computeAligned(size, mirrored: mirrored);
        final faceC = pose.faceCenterPx(size, mirrored: mirrored);
        final faceR = pose.faceRadiusPx(size);

        // Magnet snap: when in soft zone, stick to dashed target circle.
        final displayC = (snap || aligned) ? target : faceC;
        final displayR = (snap || aligned) ? innerR : faceR;
        final animateSnap = snap || aligned;

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _CircularFaceAlignPainter(
                pose: pose,
                mirrored: mirrored,
                guideColor: proximityColor,
                drawTrack: false,
              ),
              child: const SizedBox.expand(),
            ),
            if (pose.detected && displayR > 0)
              AnimatedPositioned(
                duration: Duration(milliseconds: animateSnap ? 240 : 70),
                curve: animateSnap ? Curves.easeOutBack : Curves.linear,
                left: displayC.dx - displayR,
                top: displayC.dy - displayR,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: animateSnap ? 240 : 70),
                  curve: animateSnap ? Curves.easeOutBack : Curves.linear,
                  width: displayR * 2,
                  height: displayR * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    border: Border.all(
                      color: proximityColor,
                      width: aligned ? 2.8 : 2.0,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// B/A 임상 — 이중 정적 가이드 + ghost silhouette (+ optional track).
class _CircularFaceAlignPainter extends CustomPainter {
  _CircularFaceAlignPainter({
    required this.pose,
    required this.mirrored,
    required this.guideColor,
    this.drawTrack = true,
  });

  final GuideFacePose pose;
  final bool mirrored;
  final Color guideColor;
  final bool drawTrack;

  static const _outerWhite = Color(0x80FFFFFF);
  static const _innerWhite = Color(0x66FFFFFF);

  Offset _targetCenter(Size size) => Offset(
        size.width * GuideFacePose.guideCenterX,
        size.height * GuideFacePose.guideCenterY,
      );

  double _outerRadius(Size size) => pose.outerRadiusPx(size);

  double _innerRadius(Size size) => pose.innerTargetRadiusPx(size);

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const segments = 40;
    const dashRatio = 0.55;
    for (var i = 0; i < segments; i++) {
      final start = (i / segments) * 2 * math.pi;
      final sweep = (2 * math.pi / segments) * dashRatio;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final targetCenter = _targetCenter(size);
    final outerR = _outerRadius(size);
    final innerR = _innerRadius(size);
    final aligned = pose.computeAligned(size, mirrored: mirrored);

    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: targetCenter, radius: outerR));
    canvas.drawPath(
      dim,
      Paint()..color = Colors.black.withValues(alpha: 0.38),
    );

    // 얼굴 윤곽 그림은 그리지 않는다. 정렬은 정적 링과 추적 원만으로 한다.
    if (drawTrack && pose.detected) {
      final trackCenter = pose.faceCenterPx(size, mirrored: mirrored);
      final trackR = pose.faceRadiusPx(size);
      if (trackR > 0) {
        canvas.drawCircle(
          trackCenter,
          trackR,
          Paint()
            ..color = guideColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = aligned ? 2.6 : 1.6,
        );
      }
    }

    _drawDashedCircle(
      canvas,
      targetCenter,
      innerR,
      Paint()
        ..color = aligned ? guideColor : _innerWhite
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? 2.4 : 1.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      targetCenter,
      outerR,
      Paint()
        ..color = aligned ? guideColor : _outerWhite
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? 2.0 : 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularFaceAlignPainter oldDelegate) {
    return oldDelegate.pose.detected != pose.detected ||
        oldDelegate.pose.centerX != pose.centerX ||
        oldDelegate.pose.centerY != pose.centerY ||
        oldDelegate.pose.faceRadius != pose.faceRadius ||
        oldDelegate.mirrored != mirrored ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.drawTrack != drawTrack;
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

/// 포즈 인식 안정성 측정기 — 1단계 프로토타입 보고용.
///
/// 정렬 판정에는 쓰지 않는다. 실기기에서 인식률·흔들림을 숫자로 보고
/// 그 결과로 허용 오차를 정하기 위한 계측기다.
class _BodyAlignProbe {
  static const int windowSize = 60;

  final List<bool> _detected = [];
  final List<double> _jitter = [];
  final List<double> _visibility = [];
  Offset? _lastCenter;

  void reset() {
    _detected.clear();
    _jitter.clear();
    _visibility.clear();
    _lastCenter = null;
  }

  void add(
    GuideBodyPose pose,
    GuideBodyTarget target,
    Size frameSize, {
    bool mirrored = false,
  }) {
    final usable = pose.hasPointsFor(target);
    _push(_detected, usable);
    if (!usable) {
      _lastCenter = null;
      return;
    }
    _push(_visibility, pose.averageVisibility);
    final center = pose.centerPx(target, frameSize, mirrored: mirrored);
    if (center == null) return;
    final prev = _lastCenter;
    if (prev != null) _push(_jitter, (center - prev).distance);
    _lastCenter = center;
  }

  int get samples => _detected.length;

  int get detectRatePercent {
    if (_detected.isEmpty) return 0;
    final ok = _detected.where((v) => v).length;
    return (ok * 100 / _detected.length).round();
  }

  double get jitterPx => _mean(_jitter);

  double get jitterMaxPx =>
      _jitter.isEmpty ? 0 : _jitter.reduce((a, b) => a > b ? a : b);

  int get visibilityPercent => (_mean(_visibility) * 100).round();

  static double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    var sum = 0.0;
    for (final v in values) {
      sum += v;
    }
    return sum / values.length;
  }

  static void _push<T>(List<T> list, T value) {
    list.add(value);
    if (list.length > windowSize) list.removeAt(0);
  }
}

/// 인식된 랜드마크를 점으로 찍는다. 얼굴 페인터와 무관한 별도 레이어다.
class _BodyLandmarkProbePainter extends CustomPainter {
  _BodyLandmarkProbePainter({
    required this.pose,
    required this.target,
    required this.mirrored,
  });

  final GuideBodyPose pose;
  final GuideBodyTarget target;
  final bool mirrored;

  static Color _visibilityColor(double v) {
    if (v >= 0.8) return const Color(0xFF3DDC84);
    if (v >= GuideBodyPose.visibilityThreshold) return const Color(0xFFFFC845);
    return const Color(0xFFFF5A5A);
  }

  void _line(Canvas canvas, Offset? a, Offset? b, Color color) {
    if (a == null || b == null) return;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color.withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  Offset? _mid(GuideBodyLandmark? a, GuideBodyLandmark? b, Size size) {
    if (a == null || b == null) return null;
    return Offset.lerp(
      a.toPx(size, mirrored: mirrored),
      b.toPx(size, mirrored: mirrored),
      0.5,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!pose.detected) return;

    final shoulderMid = _mid(pose.leftShoulder, pose.rightShoulder, size);
    final hipMid = _mid(pose.leftHip, pose.rightHip, size);
    final ankleMid = _mid(pose.leftAnkle, pose.rightAnkle, size);

    const skeleton = Color(0xFF7CD4FD);
    _line(
      canvas,
      pose.leftShoulder?.toPx(size, mirrored: mirrored),
      pose.rightShoulder?.toPx(size, mirrored: mirrored),
      skeleton,
    );
    _line(
      canvas,
      pose.leftHip?.toPx(size, mirrored: mirrored),
      pose.rightHip?.toPx(size, mirrored: mirrored),
      skeleton,
    );
    _line(
      canvas,
      pose.leftAnkle?.toPx(size, mirrored: mirrored),
      pose.rightAnkle?.toPx(size, mirrored: mirrored),
      skeleton,
    );
    _line(canvas, shoulderMid, hipMid, skeleton);
    _line(canvas, hipMid, ankleMid, skeleton);

    for (final (label, point) in pose.labeled) {
      final p = point.toPx(size, mirrored: mirrored);
      canvas.drawCircle(
        p,
        6,
        Paint()..color = Colors.black.withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        p,
        4,
        Paint()..color = _visibilityColor(point.visibility),
      );
      _label(canvas, p + const Offset(9, -7), label);
    }

    // 이 프리셋이 실제로 쓰는 중심 — 정렬 판정의 기준이 될 값이다.
    final center = pose.centerPx(target, size, mirrored: mirrored);
    if (center != null) {
      final cross = Paint()
        ..color = SoriTokens.cameraYellow
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center - const Offset(14, 0),
        center + const Offset(14, 0),
        cross,
      );
      canvas.drawLine(
        center - const Offset(0, 14),
        center + const Offset(0, 14),
        cross,
      );
    }

    // 크기 기준(세로 거리)을 왼쪽 눈금으로 — 거리 변화가 눈에 보이게.
    final span = pose.scalePx(target, size);
    if (span != null && span > 0 && center != null) {
      final x = 22.0;
      final top = center.dy - span / 2;
      final bottom = center.dy + span / 2;
      final bar = Paint()
        ..color = SoriTokens.cameraYellow.withValues(alpha: 0.85)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), bar);
      canvas.drawLine(Offset(x - 6, top), Offset(x + 6, top), bar);
      canvas.drawLine(Offset(x - 6, bottom), Offset(x + 6, bottom), bar);
      _label(
        canvas,
        Offset(x + 10, (top + bottom) / 2 - 8),
        '${span.round()}px',
      );
    }
  }

  void _label(Canvas canvas, Offset at, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _BodyLandmarkProbePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.target != target ||
        oldDelegate.mirrored != mirrored;
  }
}

/// 프로토타입 계측 결과 패널 — 실기기에서 이 숫자를 보고 허용 오차를 정한다.
class _BodyProbeReadout extends StatelessWidget {
  const _BodyProbeReadout({
    required this.loading,
    required this.pose,
    required this.probe,
  });

  final bool loading;
  final GuideBodyPose pose;
  final _BodyAlignProbe probe;

  @override
  Widget build(BuildContext context) {
    final lines = loading
        ? const ['포즈 모델 받는 중']
        : [
            '인식 ${probe.detectRatePercent}% (${probe.samples}프레임)',
            '흔들림 평균 ${probe.jitterPx.toStringAsFixed(1)}px · '
                '최대 ${probe.jitterMaxPx.toStringAsFixed(1)}px',
            '신뢰도 ${probe.visibilityPercent}%',
            if (pose.shoulderTiltDegrees case final tilt?)
              '어깨 기울기 ${tilt.toStringAsFixed(1)}°',
          ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '포즈 인식 시험 중',
            style: TextStyle(
              color: SoriTokens.cameraYellow,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          for (final line in lines)
            Text(
              line,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

