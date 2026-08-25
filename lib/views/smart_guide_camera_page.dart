import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/chart_photo_compressor.dart';
import '../services/chart_photo_storage.dart';
import '../services/guide_camera_session.dart';
import '../services/guide_camera_zoom_memory.dart';
import '../services/guide_face_align.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import '../widgets/media_permission_dialogs.dart';

enum GuideCameraKind { before, after }

enum GuideCaptureMode { selfFront, directorRear }

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

  /// MediaPipe 원형 정렬을 쓰는 프리셋.
  bool get usesFaceAlign =>
      this == GuidePreset.face || this == GuidePreset.decollete;
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
  bool _busy = false;
  String? _error;
  String? _viewType;
  int? _countdown;
  double? _deviceRoll;
  GuideFacePose _facePose = GuideFacePose.none;
  double _zoom = GuideCameraZoomMemory.defaultZoom;
  StreamSubscription<double?>? _rollSub;
  StreamSubscription<GuideFacePose>? _poseSub;
  Timer? _timer;
  Timer? _zoomSaveTimer;

  bool get _isAfter => widget.kind == GuideCameraKind.after;
  bool get _canGhost {
    final u = widget.ghostBeforeUrl?.trim() ?? '';
    return _isAfter && u.isNotEmpty;
  }

  bool get _faceAlignActive => _preset.usesFaceAlign;

  List<GuidePreset> get _presets => _mode == GuideCaptureMode.selfFront
      ? const [GuidePreset.face, GuidePreset.decollete]
      : const [
          GuidePreset.face,
          GuidePreset.abdomen,
          GuidePreset.lowerBody,
          GuidePreset.fullBody,
        ];

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
    _rollSub?.cancel();
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
    setState(() {
      _starting = true;
      _error = null;
      _viewType = null;
      _facePose = GuideFacePose.none;
    });
    await _faceAlign.stop();
    try {
      final front = _mode == GuideCaptureMode.selfFront;
      await _session.start(front: front, zoom: _zoom);
      if (_mode == GuideCaptureMode.directorRear) {
        await _session.requestOrientationPermission();
      }
      await _rollSub?.cancel();
      _rollSub = _session.rollDegrees.listen((r) {
        if (!mounted || _faceAlignActive) return;
        final prev = _deviceRoll;
        if (prev != null && r != null && (prev - r).abs() < 0.6) return;
        setState(() => _deviceRoll = r);
      });

      await _poseSub?.cancel();
      _poseSub = _faceAlign.poses.listen((p) {
        if (!mounted) return;
        setState(() => _facePose = p);
      });

      if (_faceAlignActive) {
        final video = _session.mlVideoHandle;
        if (video != null) {
          unawaited(_faceAlign.start(video));
        }
      }

      if (!mounted) return;
      setState(() {
        _viewType = _session.viewType;
        _starting = false;
      });
    } catch (e) {
      debugPrint('guide camera start failed: $e');
      if (!mounted) return;
      if (isMediaPermissionDeniedError(e)) {
        MediaPermissionSession.guideAccepted = false;
        await showMediaPermissionDeniedDialog(context);
      }
      setState(() {
        _starting = false;
        _error = '카메라를 열 수 없어요. 브라우저 카메라 권한을 확인해 주세요.\n$e';
      });
    }
  }

  Future<void> _switchMode(GuideCaptureMode mode) async {
    if (_mode == mode || _busy) return;
    setState(() {
      _mode = mode;
      _preset = _presets.first;
    });
    await _startCamera();
  }

  Future<void> _selectPreset(GuidePreset p) async {
    if (_preset == p) return;
    setState(() {
      _preset = p;
      _facePose = GuideFacePose.none;
    });
    if (!_session.isRunning) return;
    if (p.usesFaceAlign) {
      final video = _session.mlVideoHandle;
      if (video != null) unawaited(_faceAlign.start(video));
    } else {
      await _faceAlign.stop();
    }
  }

  void _onZoomChanged(double v) {
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

  void _startTimerCapture() {
    if (_busy || _countdown != null) return;
    var n = 3;
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

  @override
  Widget build(BuildContext context) {
    final kindLabel =
        widget.kind == GuideCameraKind.before ? 'Before' : 'After';
    final orientation = MediaQuery.orientationOf(context);
    final portrait = orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: portrait ? _buildPortrait(kindLabel) : _buildLandscape(kindLabel),
      ),
    );
  }

  Widget _buildPortrait(String kindLabel) {
    return Column(
      children: [
        _TopBar(
          kindLabel: kindLabel,
          onClose: () => Navigator.pop(context),
        ),
        Expanded(child: _buildViewfinder()),
        _buildControls(),
      ],
    );
  }

  Widget _buildLandscape(String kindLabel) {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildViewfinder()),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _TopBar(
                kindLabel: kindLabel,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(child: SingleChildScrollView(child: _buildControls())),
            ],
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
                  const Center(
                    child: CircularProgressIndicator(color: SoriTokens.primary),
                  )
                else if (_error != null)
                  Center(
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
                if (_faceAlignActive)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _CircularFaceAlignPainter(
                        pose: _facePose,
                        mirrored: _mode == GuideCaptureMode.selfFront,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  )
                else
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _BodyGuidePainter(preset: _preset),
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (!_faceAlignActive &&
                    _mode == GuideCaptureMode.directorRear)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _LevelCrosshairPainter(rollDegrees: _deviceRoll),
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (_countdown != null)
                  IgnorePointer(
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
                  const AbsorbPointer(
                    child: ColoredBox(
                      color: Color(0x59000000),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
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

  Widget _buildControls() {
    return Material(
      color: const Color(0xFF111113),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: '셀프 · 전면',
                    active: _mode == GuideCaptureMode.selfFront,
                    onTap: () => _switchMode(GuideCaptureMode.selfFront),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChip(
                    label: '원장 · 후면',
                    active: _mode == GuideCaptureMode.directorRear,
                    onTap: () => _switchMode(GuideCaptureMode.directorRear),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = _presets[i];
                  final active = _preset == p;
                  return ChoiceChip(
                    label: Text(p.label),
                    selected: active,
                    onSelected: (_) => unawaited(_selectPreset(p)),
                    selectedColor: SoriTokens.primarySoft,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color:
                          active ? SoriTokens.primary : SoriTokens.textSecondary,
                    ),
                    backgroundColor: SoriTokens.surfaceOverlay,
                    side: BorderSide(
                      color: active ? SoriTokens.primary : Colors.transparent,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _ZoomSlider(
              value: _zoom,
              onChanged: _onZoomChanged,
            ),
            if (_faceAlignActive) ...[
              const SizedBox(height: 8),
              Text(
                !_facePose.detected
                    ? '얼굴을 원 안에 맞춰 주세요'
                    : (_facePose.isAligned
                        ? '정렬됨 · 촬영 가능'
                        : '고개를 정면으로 맞춰 주세요'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _facePose.isAligned
                      ? SoriTokens.primary
                      : SoriTokens.textSecondary,
                ),
              ),
            ],
            if (_canGhost) ...[
              const SizedBox(height: 10),
              Material(
                color: _ghostOn
                    ? SoriTokens.primarySoft
                    : SoriTokens.surfaceOverlay,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => setState(() => _ghostOn = !_ghostOn),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _ghostOn
                              ? Icons.layers_rounded
                              : Icons.layers_clear_rounded,
                          color: _ghostOn
                              ? SoriTokens.primary
                              : SoriTokens.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _ghostOn ? '잔상 켜짐 (Before 25%)' : '잔상 꺼짐',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: _ghostOn
                                  ? SoriTokens.primary
                                  : SoriTokens.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _ghostOn ? '끄기' : '켜기',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: _ghostOn
                                ? SoriTokens.primary
                                : SoriTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (_mode == GuideCaptureMode.selfFront)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          (_busy || _countdown != null || _viewType == null)
                              ? null
                              : _startTimerCapture,
                      icon: const Icon(Icons.timer_outlined),
                      label: const Text(
                        '3초 타이머',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: SoriTokens.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                if (_mode == GuideCaptureMode.selfFront)
                  const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed:
                        (_busy || _countdown != null || _viewType == null)
                            ? null
                            : _captureAndUpload,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(
                      _busy ? '저장 중…' : '촬영',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _faceAlignActive && _facePose.isAligned
                          ? SoriTokens.primary
                          : SoriTokens.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              '줌',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(2)}×',
              style: const TextStyle(
                color: SoriTokens.primary,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: SoriTokens.primary,
            inactiveTrackColor: SoriTokens.surfaceOverlay,
            thumbColor: SoriTokens.primary,
            overlayColor: SoriTokens.primarySoft,
            trackHeight: 3,
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
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.kindLabel, required this.onClose});

  final String kindLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
            Expanded(
              child: Text(
                '가이드 촬영 · $kindLabel',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? SoriTokens.primarySoft : SoriTokens.surfaceOverlay,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? SoriTokens.primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: active ? SoriTokens.primary : SoriTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Face ID 스타일 원형 뷰파인더 + Pitch/Yaw/Roll 인디케이터.
class _CircularFaceAlignPainter extends CustomPainter {
  _CircularFaceAlignPainter({
    required this.pose,
    required this.mirrored,
  });

  final GuideFacePose pose;
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.46;
    final radius = math.min(size.width, size.height) * 0.36;
    final center = Offset(cx, cy);

    // 원 밖 딤
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(
      dim,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );

    final aligned = pose.isAligned;
    final borderColor = !pose.detected
        ? Colors.white.withValues(alpha: 0.55)
        : (aligned
            ? SoriTokens.primary
            : const Color(0xFFFBBF24).withValues(alpha: 0.95));

    // 소프트 글로우
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

    // 안쪽 얇은 링
    canvas.drawCircle(
      center,
      radius - 10,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    if (!pose.detected || aligned) return;

    final yaw = mirrored ? -pose.yaw : pose.yaw;
    final pitch = pose.pitch;
    final roll = pose.roll;
    const tol = GuideFacePose.alignToleranceDeg;

    final arrowPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.fill;

    void drawArrow(Offset tip, double angleRad) {
      canvas.save();
      canvas.translate(tip.dx, tip.dy);
      canvas.rotate(angleRad);
      final path = Path()
        ..moveTo(0, -14)
        ..lineTo(11, 10)
        ..lineTo(0, 5)
        ..lineTo(-11, 10)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawPath(path, arrowPaint);
      canvas.restore();
    }

    // Yaw: 좌/우
    if (yaw.abs() > tol) {
      final dir = yaw > 0 ? 1.0 : -1.0; // +yaw → 오른쪽 화살 (고개를 왼쪽으로)
      drawArrow(
        Offset(cx + dir * (radius + 22), cy),
        dir > 0 ? math.pi / 2 : -math.pi / 2,
      );
    }
    // Pitch: 상/하
    if (pitch.abs() > tol) {
      final dir = pitch > 0 ? 1.0 : -1.0; // +pitch 아래
      drawArrow(
        Offset(cx, cy + dir * (radius + 22)),
        dir > 0 ? math.pi : 0,
      );
    }
    // Roll: 원 가장자리 회전 힌트
    if (roll.abs() > tol) {
      final sweep = (roll.clamp(-35, 35) / 35) * (math.pi * 0.55);
      final arcPaint = Paint()
        ..color = const Color(0xFFFBBF24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 6),
        -math.pi / 2,
        sweep,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularFaceAlignPainter oldDelegate) {
    return oldDelegate.pose.detected != pose.detected ||
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

class _LevelCrosshairPainter extends CustomPainter {
  _LevelCrosshairPainter({required this.rollDegrees});

  final double? rollDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final base = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(cx - 48, cy), Offset(cx + 48, cy), base);
    canvas.drawLine(Offset(cx, cy - 48), Offset(cx, cy + 48), base);

    final roll = rollDegrees ?? 0;
    final leveled = roll.abs() < 2.5;
    final levelPaint = Paint()
      ..color = leveled
          ? const Color(0xFF34D399)
          : SoriTokens.primary.withValues(alpha: 0.9)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(roll * math.pi / 180);
    canvas.drawLine(const Offset(-70, 0), const Offset(70, 0), levelPaint);
    canvas.restore();

    canvas.drawCircle(
      Offset(cx, cy),
      4,
      Paint()..color = leveled ? const Color(0xFF34D399) : Colors.white70,
    );
  }

  @override
  bool shouldRepaint(covariant _LevelCrosshairPainter oldDelegate) {
    return oldDelegate.rollDegrees != rollDegrees;
  }
}
