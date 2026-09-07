import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'semantic_signal_theme.dart';
import 'volume_glass_theme.dart';

/// Visual surface for flip digit panels.
enum FlipClockStyle {
  lightSoft,
  darkGlass,
}

/// 다크 글래스 시·분·초 숫자 굵기. 구석 초와 메인 타일이 이 값을 공유한다.
const FontWeight kDarkGlassDigitWeight = FontWeight.w700;

/// PRD v4.7 — Soft UI flip-clock with digit flip animation.
class FlipClockDisplay extends StatelessWidget {
  const FlipClockDisplay({
    super.key,
    required this.totalSeconds,
    this.subtitle,
    this.stepLabel,
    this.compact = false,
    this.hero = false,
    this.homeHero = false,
    this.showSeconds = true,
    this.showCornerSeconds = false,
    this.heroTag,
    this.style = FlipClockStyle.lightSoft,
  });

  final int totalSeconds;
  final String? subtitle;
  final String? stepLabel;
  final bool compact;
  final bool hero;
  /// PRD v5.4 — home dashboard flip clock (132dp digits, min zone 200dp).
  final bool homeHero;
  final bool showSeconds;
  /// PRD v5.2 — HH:MM + small SS at lower-right (care fullscreen).
  final bool showCornerSeconds;
  final Object? heroTag;
  final FlipClockStyle style;

  bool get _darkGlass => style == FlipClockStyle.darkGlass;

  @override
  Widget build(BuildContext context) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final List<String> segments;
    if (!showSeconds || showCornerSeconds) {
      segments = [
        _timeSegment(h, 2),
        ':',
        _timeSegment(m, 2),
      ];
    } else if (h > 0) {
      segments = [
        _timeSegment(h, 2),
        ':',
        _timeSegment(m, 2),
        ':',
        _timeSegment(s, 2),
      ];
    } else {
      segments = [
        _timeSegment(m, 2),
        ':',
        _timeSegment(s, 2),
      ];
    }

    final digitHeight = homeHero
        ? 132.0
        : (_darkGlass && hero
            ? 124.0
            : (hero ? 108.0 : (compact ? 56.0 : 80.0)));
    final digitWidth = homeHero
        ? 82.0
        : (_darkGlass && hero
            ? 78.0
            : (hero ? 68.0 : (compact ? 36.0 : 52.0)));
    final colonSize = homeHero
        ? 56.0
        : (_darkGlass && hero
            ? 56.0
            : (hero ? 52.0 : (compact ? 32.0 : 40.0)));
    final pairGap = (homeHero || (_darkGlass && hero)) ? 10.0 : 6.0;
    final cornerSsScale = homeHero ? 0.38 : (_darkGlass && hero ? 0.40 : 0.42);

    final clock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stepLabel != null && stepLabel!.isNotEmpty) ...[
          Text(
            stepLabel!,
            style: VolumeGlassTheme.labelTextStyle(compact: compact),
          ),
          SizedBox(height: compact ? 8 : 12),
        ],
        _buildClockRow(
          segments: segments,
          digitHeight: digitHeight,
          digitWidth: digitWidth,
          colonSize: colonSize,
          pairGap: pairGap,
          seconds: s,
          cornerSsScale: cornerSsScale,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: compact ? 10 : 14),
          Text(
            subtitle!,
            style: VolumeGlassTheme.labelTextStyle(compact: true),
          ),
        ],
      ],
    );

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: clock);
    }
    return clock;
  }

  Widget _buildClockRow({
    required List<String> segments,
    required double digitHeight,
    required double digitWidth,
    required double colonSize,
    required double pairGap,
    required int seconds,
    required double cornerSsScale,
  }) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final segment in segments)
          if (segment == ':')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hero ? 8 : 4),
              child: Text(
                ':',
                style: GoogleFonts.nunito(
                  fontSize: colonSize,
                  fontWeight: FontWeight.w700,
                  // 다크 글래스는 타일만 어둡고 주변은 밝은 카드다.
                  // 흰 콜론을 쓰면 흰 배경에 묻혀 구분자가 사라진다.
                  color: _darkGlass
                      ? const Color(0xFF1C1C1E).withValues(alpha: 0.65)
                      : SemanticSignalTheme.heroTextColor
                          .withValues(alpha: 0.28),
                  height: 1,
                ),
              ),
            )
          else
            _FlipDigitPair(
              value: segment,
              height: digitHeight,
              width: digitWidth,
              compact: compact,
              hero: hero,
              style: style,
              digitGap: pairGap,
            ),
      ],
    );

    if (!showCornerSeconds) return row;

    // SS는 HH:MM 뒤에 이어 붙이는 게 아니라, 시계 박스 **안쪽** 우측 하단에
    // 얹는다. Row로 이어 붙이거나 음수 offset으로 밖에 걸면 SS 폭만큼 시계가
    // 밀려 화면을 벗어난다. 오른쪽에 SS 자리만큼 여백을 미리 떼어 두고
    // Stack의 크기를 그 여백 포함으로 확정한 뒤, 그 안에 SS를 고정한다.
    final ssSize = digitHeight * cornerSsScale;
    final ssBoxW = ssSize * _ssBoxWidthRatio;
    final ssBoxH = ssSize * _ssBoxHeightRatio;
    final gutter = ssBoxW + ssSize * _ssGapRatio;

    return Stack(
      children: [
        // 이 Padding이 Stack의 크기를 결정한다 → SS는 절대 밖으로 못 나간다.
        Padding(
          padding: EdgeInsets.only(right: gutter),
          child: row,
        ),
        Positioned(
          right: 0,
          bottom: ssSize * _ssBottomInsetRatio,
          width: ssBoxW,
          height: ssBoxH,
          child: _CornerSeconds(
            seconds: seconds,
            fontSize: ssSize,
            darkGlass: _darkGlass,
          ),
        ),
      ],
    );
  }

  /// SS 두 자리(tabular) + 패널 여백. 폰트가 바뀌어도 FittedBox가 흡수한다.
  static const _ssBoxWidthRatio = 1.72;
  static const _ssBoxHeightRatio = 1.38;
  static const _ssGapRatio = 0.16;
  static const _ssBottomInsetRatio = 0.10;

  String _timeSegment(int value, int width) =>
      value.toString().padLeft(width, '0');
}

/// HH:MM 우측 하단에 얹히는 초(SS) 패널.
///
/// 시/분 타일과 같은 다크 글래스를 깔아야 한다. 배경 없이 흰 글자만 두면
/// 밝은 히어로 카드 위에서 초가 통째로 사라진다.
class _CornerSeconds extends StatelessWidget {
  const _CornerSeconds({
    required this.seconds,
    required this.fontSize,
    required this.darkGlass,
  });

  final int seconds;
  final double fontSize;
  final bool darkGlass;

  @override
  Widget build(BuildContext context) {
    final radius = fontSize * 0.34;
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        key: const Key('dark-glass-corner-digit'),
        seconds.toString().padLeft(2, '0'),
        maxLines: 1,
        softWrap: false,
        style: GoogleFonts.nunito(
          fontSize: fontSize,
          fontWeight: kDarkGlassDigitWeight,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: darkGlass
              ? Colors.white.withValues(alpha: 0.92)
              : SemanticSignalTheme.heroTextColor.withValues(alpha: 0.55),
          height: 1,
        ),
      ),
    );

    if (!darkGlass) {
      return Align(alignment: Alignment.bottomRight, child: text);
    }

    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: text,
    );
  }
}

class _FlipDigitPair extends StatelessWidget {
  const _FlipDigitPair({
    required this.value,
    required this.height,
    required this.width,
    required this.compact,
    required this.hero,
    required this.style,
    required this.digitGap,
  });

  final String value;
  final double height;
  final double width;
  final bool compact;
  final bool hero;
  final FlipClockStyle style;
  final double digitGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < value.length; i++) ...[
          if (i > 0) SizedBox(width: digitGap),
          _FlipDigit(
            digit: value[i],
            height: height,
            width: width,
            compact: compact,
            hero: hero,
            style: style,
          ),
        ],
      ],
    );
  }
}

class _FlipDigit extends StatelessWidget {
  const _FlipDigit({
    required this.digit,
    required this.height,
    required this.width,
    required this.compact,
    required this.hero,
    required this.style,
  });

  final String digit;
  final double height;
  final double width;
  final bool compact;
  final bool hero;
  final FlipClockStyle style;

  bool get _darkGlass => style == FlipClockStyle.darkGlass;

  @override
  Widget build(BuildContext context) {
    final fontSize = _darkGlass && hero
        ? 58.0
        : (hero
            ? 52.0
            : (compact
                ? VolumeGlassTheme.kpiFontSizeCompact
                : VolumeGlassTheme.kpiFontSizeHero));
    final radius = _darkGlass && hero ? 22.0 : (hero ? 20.0 : (compact ? 14.0 : 18.0));

    if (_darkGlass) {
      return _SplitFlapDigit(
        digit: digit,
        height: height,
        width: width,
        fontSize: fontSize,
        radius: radius,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final rotate = Tween(begin: math.pi / 2, end: 0.0).animate(animation);
        return AnimatedBuilder(
          animation: rotate,
          child: child,
          builder: (context, child) {
            final tilt = animation.status == AnimationStatus.reverse
                ? -rotate.value
                : rotate.value;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateX(tilt),
              child: Opacity(
                opacity: animation.value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [...previous, if (current != null) current],
      ),
      child: _darkGlass
          ? ClipRRect(
              key: ValueKey<String>(digit),
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: _darkGlassPanel(
                  digit: digit,
                  height: height,
                  width: width,
                  fontSize: fontSize,
                  radius: radius,
                ),
              ),
            )
          : Container(
              key: ValueKey<String>(digit),
              width: width,
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: VolumeGlassTheme.cardFillColor(),
                borderRadius: BorderRadius.circular(radius),
                boxShadow: VolumeGlassTheme.volumeShadow(alpha: 0.06),
              ),
              child: Text(
                digit,
                style: GoogleFonts.nunito(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: SemanticSignalTheme.heroTextColor,
                ),
              ),
            ),
    );
  }

  Widget _darkGlassPanel({
    required String digit,
    required double height,
    required double width,
    required double fontSize,
    required double radius,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2C2C2E),
            Color(0xFF1C1C1E),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.22),
          ],
          stops: const [0.0, 0.48, 1.0],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 6,
            right: 6,
            top: height * 0.5 - 0.5,
            child: Container(
              height: 1,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
          Text(
            digit,
            style: GoogleFonts.nunito(
              fontSize: fontSize,
              fontWeight: kDarkGlassDigitWeight,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 다크 글래스 전용 스플릿플랩.
///
/// 타일을 위/아래 고정 패널로 나누고, 숫자가 바뀔 때만 윗조각이
/// 가운데 힌지에서 접혔다 펴진다. 통짜 3D 회전이 아니다.
class _SplitFlapDigit extends StatefulWidget {
  const _SplitFlapDigit({
    required this.digit,
    required this.height,
    required this.width,
    required this.fontSize,
    required this.radius,
  });

  static const Duration flipDuration = Duration(milliseconds: 420);

  final String digit;
  final double height;
  final double width;
  final double fontSize;
  final double radius;

  @override
  State<_SplitFlapDigit> createState() => _SplitFlapDigitState();
}

class _SplitFlapDigitState extends State<_SplitFlapDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late String _shown;
  String? _from;
  String? _to;
  String? _queued;

  @override
  void initState() {
    super.initState();
    _shown = widget.digit;
    _ctrl = AnimationController(vsync: this, duration: _SplitFlapDigit.flipDuration)
      ..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final landed = _to ?? _shown;
    _ctrl.reset();
    _from = null;
    _to = null;
    _shown = landed;
    final next = _queued;
    _queued = null;
    if (!mounted) return;
    if (next != null && next != _shown) {
      _begin(next);
    } else {
      setState(() {});
    }
  }

  void _begin(String next) {
    setState(() {
      _from = _shown;
      _to = next;
    });
    _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _SplitFlapDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.digit == oldWidget.digit) return;
    if (_ctrl.isAnimating) {
      _queued = widget.digit;
      return;
    }
    if (widget.digit != _shown) _begin(widget.digit);
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_onStatus);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final flipping = _from != null && _to != null && (t > 0 || _ctrl.isAnimating);
        final topDigit = flipping ? _from! : _shown;
        final bottomDigit = flipping ? _to! : _shown;
        final flapDigit = !flipping
            ? _shown
            : (t < 0.5 ? _from! : _to!);
        final flapAngle = !flipping ? 0.0 : _flapAngle(t);

        return _glassShell(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _half(
                digit: bottomDigit,
                align: Alignment.bottomCenter,
              ),
              _half(
                digit: topDigit,
                align: Alignment.topCenter,
              ),
              if (flipping)
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: widget.height / 2,
                    width: widget.width,
                    child: Transform(
                      key: const Key('split-flap-leaf'),
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateX(flapAngle),
                      child: _halfFace(flapDigit),
                    ),
                  ),
                ),
              Positioned(
                left: 6,
                right: 6,
                top: widget.height * 0.5 - 0.5,
                child: Container(
                  height: 1,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 0~50%: 이전 윗조각이 0°→90°. 50~100%: 새 윗조각이 90°→0°.
  double _flapAngle(double t) {
    if (t < 0.5) return (t / 0.5) * (math.pi / 2);
    return (1 - ((t - 0.5) / 0.5)) * (math.pi / 2);
  }

  Widget _glassShell({required Widget child}) {
    final radius = widget.radius;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.22),
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _half({required String digit, required Alignment align}) {
    return ClipRect(
      child: Align(
        alignment: align,
        heightFactor: 0.5,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: _digitText(digit),
        ),
      ),
    );
  }

  /// 플랩은 윗절반만 담는다. 숫자 기준점은 타일 전체와 같다.
  Widget _halfFace(String digit) {
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: widget.height,
          maxHeight: widget.height,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: _digitText(digit),
          ),
        ),
      ),
    );
  }

  Widget _digitText(String digit) {
    return Center(
      child: Text(
        digit,
        key: const Key('dark-glass-digit'),
        style: GoogleFonts.nunito(
          fontSize: widget.fontSize,
          fontWeight: kDarkGlassDigitWeight,
          height: 1.0,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: Colors.white,
        ),
      ),
    );
  }
}
