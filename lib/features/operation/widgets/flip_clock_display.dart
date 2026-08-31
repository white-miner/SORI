import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PRD v4.5 — CDG flip-clock with digit flip animation.
class FlipClockDisplay extends StatelessWidget {
  const FlipClockDisplay({
    super.key,
    required this.totalSeconds,
    this.subtitle,
    this.stepLabel,
    this.compact = false,
  });

  final int totalSeconds;
  final String? subtitle;
  final String? stepLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final segments = h > 0
        ? [
            _timeSegment(h, 2),
            ':',
            _timeSegment(m, 2),
            ':',
            _timeSegment(s, 2),
          ]
        : [
            _timeSegment(m, 2),
            ':',
            _timeSegment(s, 2),
          ];

    final digitHeight = compact ? 52.0 : 76.0;
    final digitWidth = compact ? 34.0 : 48.0;
    final colonSize = compact ? 36.0 : 52.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stepLabel != null && stepLabel!.isNotEmpty) ...[
          Text(
            stepLabel!,
            style: GoogleFonts.nunito(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8E8E93),
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
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
                      color: const Color(0xFF1C1C1E).withValues(alpha: 0.35),
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
                ),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: compact ? 8 : 12),
          Text(
            subtitle!,
            style: GoogleFonts.nunito(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8E8E93),
            ),
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
  });

  final String value;
  final double height;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < value.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _FlipDigit(
            digit: value[i],
            height: height,
            width: width,
            compact: compact,
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
  });

  final String digit;
  final double height;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 34.0 : 48.0;

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
          color: Colors.white.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.95),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          digit,
          style: GoogleFonts.nunito(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: const Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }
}
