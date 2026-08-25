import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/chart_photo_compressor.dart';
import '../services/chart_photo_storage.dart';
import '../services/guide_camera_session.dart';
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

  /// 태블릿 ~1m 거리에서 인물이 알맞게 차도록 하는 목표 배율.
  double get targetZoom => switch (this) {
        GuidePreset.face => 1.9,
        GuidePreset.decollete => 1.7,
        GuidePreset.abdomen => 1.55,
        GuidePreset.lowerBody => 1.4,
        GuidePreset.fullBody => 1.25,
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

/// 스마트 가이드 카메라 — E0 캡처 + E1 Ghost(After).
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
  GuideCaptureMode _mode = GuideCaptureMode.selfFront;
  GuidePreset _preset = GuidePreset.face;
  bool _ghostOn = true;
  bool _starting = true;
  bool _busy = false;
  String? _error;
  String? _viewType;
  int? _countdown;
  double? _roll;
  StreamSubscription<double?>? _rollSub;
  Timer? _timer;

  bool get _isAfter => widget.kind == GuideCameraKind.after;
  bool get _canGhost {
    final u = widget.ghostBeforeUrl?.trim() ?? '';
    return _isAfter && u.isNotEmpty;
  }

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
    if (_isAfter && !_canGhost) {
      _ghostOn = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rollSub?.cancel();
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

    final ok = await showMediaPermissionGuideDialog(context);
    if (!mounted) return;
    if (!ok) {
      Navigator.pop(context);
      return;
    }
    MediaPermissionSession.guideAccepted = true;

    await _startCamera();
  }

  Future<void> _startCamera() async {
    setState(() {
      _starting = true;
      _error = null;
      _viewType = null;
    });
    try {
      final front = _mode == GuideCaptureMode.selfFront;
      await _session.start(front: front, zoom: _preset.targetZoom);
      if (_mode == GuideCaptureMode.directorRear) {
        await _session.requestOrientationPermission();
      }
      await _rollSub?.cancel();
      _rollSub = _session.rollDegrees.listen((r) {
        if (!mounted) return;
        final prev = _roll;
        if (prev != null && r != null && (prev - r).abs() < 0.6) return;
        setState(() => _roll = r);
      });
      if (!mounted) return;
      setState(() {
        _viewType = _session.viewType;
        _starting = false;
      });
    } catch (e) {
      debugPrint('guide camera start failed: $e');
      if (!mounted) return;
      if (isMediaPermissionDeniedError(e)) {
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
    setState(() => _preset = p);
    if (_session.isRunning) {
      await _session.setZoom(p.targetZoom);
    }
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
        // 컨트롤은 뷰파인더 Stack 밖 — 플랫폼 뷰 오버플로와 분리
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
                IgnorePointer(
                  child: CustomPaint(
                    painter: _GuideSilhouettePainter(
                      preset: _preset,
                      mode: _mode,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                if (_mode == GuideCaptureMode.directorRear)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _LevelCrosshairPainter(rollDegrees: _roll),
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
                      backgroundColor: SoriTokens.primary,
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

/// 차트용 정밀 실루엣 + 드롭섀도우 (명암 배경 모두 시인성).
class _GuideSilhouettePainter extends CustomPainter {
  _GuideSilhouettePainter({required this.preset, required this.mode});

  final GuidePreset preset;
  final GuideCaptureMode mode;

  Paint get _fill => Paint()
    ..color = Colors.white.withValues(alpha: 0.05)
    ..style = PaintingStyle.fill;

  void _strokePath(Canvas canvas, Path path, {double width = 2.4}) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 3.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glow);
    canvas.drawPath(path, shadow);
    canvas.drawPath(path, stroke);
  }

  void _dashedHLine(Canvas canvas, double y, double left, double right) {
    const dash = 7.0;
    const gap = 5.0;
    var x = left;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    while (x < right) {
      final x2 = math.min(x + dash, right);
      canvas.drawLine(Offset(x, y + 0.8), Offset(x2, y + 0.8), shadow);
      canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
      x += dash + gap;
    }
  }

  Path _faceOvalPath(Rect r) {
    // 타원 + 살짝 좁은 턱선 (미용 차트용 얼굴형)
    final cx = r.center.dx;
    final top = r.top;
    final bottom = r.bottom;
    final left = r.left;
    final right = r.right;
    final midY = r.center.dy;
    final path = Path();
    path.moveTo(cx, top);
    path.cubicTo(
      right - r.width * 0.02,
      top + r.height * 0.08,
      right + r.width * 0.02,
      midY - r.height * 0.05,
      right - r.width * 0.06,
      midY + r.height * 0.12,
    );
    path.cubicTo(
      right - r.width * 0.12,
      bottom - r.height * 0.08,
      cx + r.width * 0.18,
      bottom + r.height * 0.02,
      cx,
      bottom,
    );
    path.cubicTo(
      cx - r.width * 0.18,
      bottom + r.height * 0.02,
      left + r.width * 0.12,
      bottom - r.height * 0.08,
      left + r.width * 0.06,
      midY + r.height * 0.12,
    );
    path.cubicTo(
      left - r.width * 0.02,
      midY - r.height * 0.05,
      left + r.width * 0.02,
      top + r.height * 0.08,
      cx,
      top,
    );
    path.close();
    return path;
  }

  void _paintFace(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final face = Rect.fromCenter(
      center: Offset(cx, size.height * 0.42),
      width: size.width * 0.58,
      height: size.height * 0.52,
    );
    final oval = _faceOvalPath(face);
    canvas.drawPath(oval, _fill);
    _strokePath(canvas, oval, width: 2.6);

    // 눈 / 코 / 입 가로 점선 (얼굴 높이 기준)
    final guideL = face.left + face.width * 0.14;
    final guideR = face.right - face.width * 0.14;
    _dashedHLine(canvas, face.top + face.height * 0.38, guideL, guideR); // 눈
    _dashedHLine(canvas, face.top + face.height * 0.55, guideL + 18, guideR - 18); // 코
    _dashedHLine(canvas, face.top + face.height * 0.72, guideL + 10, guideR - 10); // 입

    // 중앙 세로 미세 가이드
    final vPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, face.top + face.height * 0.28),
      Offset(cx, face.bottom - face.height * 0.12),
      vPaint,
    );
  }

  void _paintDecollete(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final head = Rect.fromCenter(
      center: Offset(cx, size.height * 0.18),
      width: size.width * 0.26,
      height: size.height * 0.16,
    );
    final headPath = _faceOvalPath(head);
    canvas.drawPath(headPath, _fill);
    _strokePath(canvas, headPath, width: 2);

    // 목 → 승모근 → 어깨 → 쇄골
    final neckTop = head.bottom - 4;
    final clavY = size.height * 0.42;
    final shoulderY = size.height * 0.48;
    final path = Path()
      ..moveTo(cx - size.width * 0.07, neckTop)
      ..quadraticBezierTo(
        cx - size.width * 0.09,
        size.height * 0.32,
        cx - size.width * 0.16,
        clavY,
      )
      ..quadraticBezierTo(
        cx - size.width * 0.28,
        shoulderY - 6,
        size.width * 0.08,
        shoulderY + size.height * 0.02,
      )
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.62,
        size.width * 0.14,
        size.height * 0.78,
      )
      ..lineTo(size.width * 0.86, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.62,
        size.width * 0.92,
        shoulderY + size.height * 0.02,
      )
      ..quadraticBezierTo(
        cx + size.width * 0.28,
        shoulderY - 6,
        cx + size.width * 0.16,
        clavY,
      )
      ..quadraticBezierTo(
        cx + size.width * 0.09,
        size.height * 0.32,
        cx + size.width * 0.07,
        neckTop,
      );

    canvas.drawPath(path, _fill);
    _strokePath(canvas, path, width: 2.4);

    // 쇄골 라인
    final clav = Path()
      ..moveTo(cx - size.width * 0.22, clavY + 4)
      ..quadraticBezierTo(cx, clavY - 10, cx + size.width * 0.22, clavY + 4);
    _strokePath(canvas, clav, width: 1.8);

    // 어깨 윗선
    final shoulder = Path()
      ..moveTo(size.width * 0.12, shoulderY)
      ..quadraticBezierTo(cx, shoulderY - size.height * 0.04, size.width * 0.88, shoulderY);
    _strokePath(canvas, shoulder, width: 1.6);
  }

  void _paintAbdomen(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final box = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: size.width * 0.58,
            height: size.height * 0.48,
          ),
          const Radius.circular(18),
        ),
      );
    _strokePath(canvas, box, width: 2);
    _dashedHLine(canvas, cy, size.width * 0.22, size.width * 0.78);
    canvas.drawCircle(
      Offset(cx, cy),
      5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _paintLowerBody(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx, size.height * 0.12)
      ..lineTo(cx, size.height * 0.9);
    _strokePath(canvas, path, width: 2);
    _dashedHLine(
      canvas,
      size.height * 0.55,
      size.width * 0.25,
      size.width * 0.75,
    );
  }

  void _paintFullBody(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, size.height * 0.55),
            width: size.width * 0.4,
            height: size.height * 0.72,
          ),
          const Radius.circular(22),
        ),
      );
    _strokePath(canvas, body, width: 2);
    final head = _faceOvalPath(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.14),
        width: size.width * 0.16,
        height: size.height * 0.1,
      ),
    );
    _strokePath(canvas, head, width: 1.8);
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (preset) {
      case GuidePreset.face:
        _paintFace(canvas, size);
      case GuidePreset.decollete:
        _paintDecollete(canvas, size);
      case GuidePreset.abdomen:
        _paintAbdomen(canvas, size);
      case GuidePreset.lowerBody:
        _paintLowerBody(canvas, size);
      case GuidePreset.fullBody:
        _paintFullBody(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _GuideSilhouettePainter oldDelegate) {
    return oldDelegate.preset != preset || oldDelegate.mode != mode;
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
