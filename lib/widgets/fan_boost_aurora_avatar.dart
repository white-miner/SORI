import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/sori_tokens.dart';
import 'sori_logo.dart';

/// Fan-Boost 활성 시 원장 아바타에 오로라 LED 링 (CRM 링과 분리).
class FanBoostAuroraAvatar extends StatefulWidget {
  const FanBoostAuroraAvatar({
    super.key,
    required this.imageUrl,
    required this.isBoostActive,
    this.isFanBoost = false,
    this.radius = 18,
    this.onTap,
    this.fallbackChild,
  });

  final String imageUrl;
  final bool isBoostActive;
  final bool isFanBoost;
  final double radius;
  final VoidCallback? onTap;
  final Widget? fallbackChild;

  @override
  State<FanBoostAuroraAvatar> createState() => _FanBoostAuroraAvatarState();
}

class _FanBoostAuroraAvatarState extends State<FanBoostAuroraAvatar>
    with SingleTickerProviderStateMixin {
  static const double _ringWidth = 2.8;
  static const double _ringGap = 2.0;
  static const Duration _spinDuration = Duration(seconds: 4);

  AnimationController? _spin;

  bool get _shouldSpin => widget.isBoostActive && widget.isFanBoost;

  @override
  void initState() {
    super.initState();
    _ensureSpin();
  }

  @override
  void didUpdateWidget(covariant FanBoostAuroraAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBoostActive != widget.isBoostActive ||
        oldWidget.isFanBoost != widget.isFanBoost) {
      _ensureSpin();
    }
  }

  void _ensureSpin() {
    if (_shouldSpin) {
      _spin ??= AnimationController(vsync: this, duration: _spinDuration);
      if (!_spin!.isAnimating) _spin!.repeat();
    } else {
      _spin?.stop();
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureSpin();
    });

    final url = widget.imageUrl.trim();
    final hasImage = url.isNotEmpty && !url.startsWith('data:');
    final outer = widget.radius + _ringWidth + _ringGap;

    Widget avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: SoriTokens.surfaceOverlay,
      backgroundImage: hasImage ? NetworkImage(url) : null,
      child: !hasImage
          ? (widget.fallbackChild ??
              const Padding(
                padding: EdgeInsets.all(5),
                child: SoriLogo(width: 20, height: 20),
              ))
          : null,
    );

    if (_shouldSpin) {
      Widget ring = CustomPaint(
        size: Size.square(outer * 2),
        painter: _AuroraRingPainter(isFanBoost: widget.isFanBoost),
      );
      if (_spin != null) {
        ring = RotationTransition(turns: _spin!, child: ring);
      }
      avatar = RepaintBoundary(
        child: SizedBox(
          width: outer * 2,
          height: outer * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [ring, avatar],
          ),
        ),
      );
    }

    if (widget.onTap != null) {
      avatar = GestureDetector(onTap: widget.onTap, child: avatar);
    }
    return avatar;
  }
}

class _AuroraRingPainter extends CustomPainter {
  _AuroraRingPainter({required this.isFanBoost});

  final bool isFanBoost;

  static const List<Color> _fanColors = [
    Color(0xFF7C3AED),
    Color(0xFFF472B6),
    Color(0xFF38BDF8),
    Color(0xFFA78BFA),
    Color(0xFF7C3AED),
  ];

  static const List<Color> _adColors = [
    Color(0xFFFBBF24),
    Color(0xFFF59E0B),
    Color(0xFFFDE68A),
    Color(0xFFFBBF24),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const ringWidth = 2.8;
    final radius = size.width / 2 - ringWidth / 2;
    final colors = isFanBoost ? _fanColors : _adColors;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..shader = SweepGradient(colors: colors).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraRingPainter oldDelegate) =>
      oldDelegate.isFanBoost != isFanBoost;
}
