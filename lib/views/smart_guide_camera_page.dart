import 'dart:async';

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
      await _session.start(front: front);
      if (_mode == GuideCaptureMode.directorRear) {
        await _session.requestOrientationPermission();
      }
      await _rollSub?.cancel();
      _rollSub = _session.rollDegrees.listen((r) {
        if (mounted) setState(() => _roll = r);
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
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black),
        if (_viewType != null)
          HtmlElementView(viewType: _viewType!)
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
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            ),
          ),
        if (_canGhost && _ghostOn && (widget.ghostBeforeUrl?.isNotEmpty ?? false))
          IgnorePointer(
            child: Opacity(
              opacity: 0.25,
              child: Image.network(
                widget.ghostBeforeUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        CustomPaint(
          painter: _GuideSilhouettePainter(
            preset: _preset,
            mode: _mode,
          ),
          child: const SizedBox.expand(),
        ),
        if (_mode == GuideCaptureMode.directorRear)
          CustomPaint(
            painter: _LevelCrosshairPainter(rollDegrees: _roll),
            child: const SizedBox.expand(),
          ),
        if (_countdown != null)
          Center(
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
        if (_busy)
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.35),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF111113),
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
                  onSelected: (_) => setState(() => _preset = p),
                  selectedColor: SoriTokens.primarySoft,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: active ? SoriTokens.primary : SoriTokens.textSecondary,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    onPressed: (_busy || _countdown != null || _viewType == null)
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
              if (_mode == GuideCaptureMode.selfFront) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: (_busy || _countdown != null || _viewType == null)
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
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.kindLabel, required this.onClose});

  final String kindLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
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

class _GuideSilhouettePainter extends CustomPainter {
  _GuideSilhouettePainter({required this.preset, required this.mode});

  final GuidePreset preset;
  final GuideCaptureMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final fill = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (preset) {
      case GuidePreset.face:
        final r = Rect.fromCenter(
          center: Offset(cx, cy - size.height * 0.04),
          width: size.width * 0.52,
          height: size.height * 0.42,
        );
        canvas.drawOval(r, fill);
        canvas.drawOval(r, stroke);
        // jaw hint
        final jaw = Path()
          ..moveTo(r.left + r.width * 0.18, r.center.dy + r.height * 0.15)
          ..quadraticBezierTo(
            cx,
            r.bottom + 8,
            r.right - r.width * 0.18,
            r.center.dy + r.height * 0.15,
          );
        canvas.drawPath(jaw, stroke);
      case GuidePreset.decollete:
        final shoulderY = cy + size.height * 0.02;
        final path = Path()
          ..moveTo(size.width * 0.12, shoulderY)
          ..quadraticBezierTo(cx, shoulderY - size.height * 0.08, size.width * 0.88, shoulderY)
          ..lineTo(size.width * 0.92, size.height * 0.78)
          ..lineTo(size.width * 0.08, size.height * 0.78)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        // face oval small
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy - size.height * 0.22),
            width: size.width * 0.28,
            height: size.height * 0.2,
          ),
          stroke,
        );
      case GuidePreset.abdomen:
        final lineY = cy;
        canvas.drawLine(
          Offset(size.width * 0.18, lineY),
          Offset(size.width * 0.82, lineY),
          stroke,
        );
        // navel mark
        canvas.drawCircle(Offset(cx, lineY), 5, stroke);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: size.width * 0.55,
            height: size.height * 0.45,
          ),
          stroke,
        );
      case GuidePreset.lowerBody:
        canvas.drawLine(
          Offset(cx, size.height * 0.18),
          Offset(cx, size.height * 0.88),
          stroke,
        );
        // knees
        final kneeY = size.height * 0.55;
        canvas.drawLine(
          Offset(size.width * 0.28, kneeY),
          Offset(size.width * 0.72, kneeY),
          stroke,
        );
      case GuidePreset.fullBody:
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: size.width * 0.42,
            height: size.height * 0.82,
          ),
          stroke,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, size.height * 0.16),
            width: size.width * 0.16,
            height: size.height * 0.1,
          ),
          stroke,
        );
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
    canvas.rotate(roll * 3.1415926535 / 180);
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
