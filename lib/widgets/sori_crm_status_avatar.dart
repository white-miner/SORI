import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/customer_crm_status_resolver.dart';
import '../theme/crm_ring_tokens.dart';
import '../theme/sori_tokens.dart';

/// 인스타 스토리 스타일 CRM 상태 링 + 이니셜 아바타.
/// [animateWhenVisible] false이면 정적 링(회전 off).
class SoriCrmStatusAvatar extends StatefulWidget {
  const SoriCrmStatusAvatar({
    super.key,
    required this.name,
    required this.visual,
    this.radius = 22,
    this.fontSize = 16,
    this.animateWhenVisible = true,
  });

  final String name;
  final CrmRingVisual visual;
  final double radius;
  final double fontSize;
  final bool animateWhenVisible;

  @override
  State<SoriCrmStatusAvatar> createState() => _SoriCrmStatusAvatarState();
}

class _SoriCrmStatusAvatarState extends State<SoriCrmStatusAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  bool get _shouldSpin =>
      widget.visual.animate && widget.animateWhenVisible;

  @override
  void initState() {
    super.initState();
    _ensureSpinController();
  }

  @override
  void didUpdateWidget(SoriCrmStatusAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visual.animate != widget.visual.animate ||
        oldWidget.animateWhenVisible != widget.animateWhenVisible) {
      _ensureSpinController();
    }
  }

  void _ensureSpinController() {
    if (_shouldSpin) {
      _spin ??= AnimationController(
        vsync: this,
        duration: CrmRingTokens.rotationDuration,
      );
      if (!_spin!.isAnimating) {
        _spin!.repeat();
      }
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
      if (mounted) _ensureSpinController();
    });

    final outer = widget.radius + CrmRingTokens.ringWidth + CrmRingTokens.ringGap;
    final initial = widget.name.trim().isEmpty
        ? '?'
        : widget.name.characters.first;

    Widget ring = CustomPaint(
      size: Size.square(outer * 2),
      painter: _CrmRingPainter(colors: widget.visual.gradientColors),
    );

    if (_spin != null && _shouldSpin) {
      ring = RotationTransition(turns: _spin!, child: ring);
    }

    return RepaintBoundary(
      child: Tooltip(
        message: widget.visual.tooltipLabel,
        child: Semantics(
          label: '${widget.name} · ${widget.visual.tooltipLabel}',
          child: SizedBox(
            width: outer * 2,
            height: outer * 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ring,
                CircleAvatar(
                  radius: widget.radius,
                  backgroundColor: SoriTokens.primarySoft,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: SoriTokens.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.fontSize,
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

class _CrmRingPainter extends CustomPainter {
  _CrmRingPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - CrmRingTokens.ringWidth / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = CrmRingTokens.ringWidth
      ..shader = SweepGradient(
        colors: colors.length >= 2 ? colors : [colors.first, colors.first],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_CrmRingPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

/// 리스트 스크롤 시 가시 타일만 링 애니메이션 (고정 높이 타일 기준).
mixin CrmRingScrollVisibility<T extends StatefulWidget> on State<T> {
  ScrollController get crmRingScrollController;

  static const double crmTileHeight = 88;

  bool crmRingAnimateForIndex(int index) {
    if (!crmRingScrollController.hasClients) return true;
    final offset = crmRingScrollController.offset;
    final viewport = MediaQuery.of(context).size.height;
    final first = (offset / crmTileHeight).floor();
    final last = ((offset + viewport) / crmTileHeight).ceil();
    return index >= first - 2 && index <= last + 2;
  }
}
