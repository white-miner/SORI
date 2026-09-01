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

/// PRD v4.7 — Soft UI flip-clock with digit flip animation.
class FlipClockDisplay extends StatelessWidget {
  const FlipClockDisplay({
    super.key,
    required this.totalSeconds,
    this.subtitle,
    this.stepLabel,
    this.compact = false,
    this.hero = false,
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

    final digitHeight = _darkGlass && hero
        ? 124.0
        : (hero ? 108.0 : (compact ? 56.0 : 80.0));
    final digitWidth = _darkGlass && hero
        ? 78.0
        : (hero ? 68.0 : (compact ? 36.0 : 52.0));
    final colonSize = _darkGlass && hero
        ? 56.0
        : (hero ? 52.0 : (compact ? 32.0 : 40.0));
    final pairGap = _darkGlass && hero ? 10.0 : 6.0;

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
                  fontWeight: FontWeight.w300,
                  color: _darkGlass
                      ? Colors.white.withValues(alpha: 0.42)
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

    final ssSize = digitHeight * 0.4;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        row,
        Positioned(
          right: -ssSize * 0.9,
          bottom: -ssSize * 0.15,
          child: Text(
            seconds.toString().padLeft(2, '0'),
            style: GoogleFonts.nunito(
              fontSize: ssSize,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: Colors.white.withValues(alpha: 0.8),
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  String _timeSegment(int value, int width) =>
      value.toString().padLeft(width, '0');
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
              fontWeight: FontWeight.w300,
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
