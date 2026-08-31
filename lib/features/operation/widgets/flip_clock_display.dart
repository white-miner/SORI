import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'semantic_signal_theme.dart';
import 'volume_glass_theme.dart';

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
  });

  final int totalSeconds;
  final String? subtitle;
  final String? stepLabel;
  final bool compact;
  final bool hero;
  final bool showSeconds;

  @override
  Widget build(BuildContext context) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final List<String> segments;
    if (!showSeconds) {
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

    final digitHeight = hero ? 108.0 : (compact ? 56.0 : 80.0);
    final digitWidth = hero ? 68.0 : (compact ? 36.0 : 52.0);
    final colonSize = hero ? 52.0 : (compact ? 32.0 : 40.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stepLabel != null && stepLabel!.isNotEmpty) ...[
          Text(
            stepLabel!,
            style: VolumeGlassTheme.labelTextStyle(compact: compact),
          ),
          SizedBox(height: compact ? 8 : 12),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final segment in segments)
              if (segment == ':')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ':',
                    style: GoogleFonts.nunito(
                      fontSize: colonSize,
                      fontWeight: FontWeight.w800,
                      color: SemanticSignalTheme.heroTextColor
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
                ),
          ],
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
  });

  final String value;
  final double height;
  final double width;
  final bool compact;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < value.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          _FlipDigit(
            digit: value[i],
            height: height,
            width: width,
            compact: compact,
            hero: hero,
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
  });

  final String digit;
  final double height;
  final double width;
  final bool compact;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final fontSize = hero
        ? 52.0
        : (compact
            ? VolumeGlassTheme.kpiFontSizeCompact
            : VolumeGlassTheme.kpiFontSizeHero);

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
      child: Container(
        key: ValueKey<String>(digit),
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: VolumeGlassTheme.cardFillColor(),
          borderRadius: BorderRadius.circular(hero ? 20 : (compact ? 14 : 18)),
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
}
