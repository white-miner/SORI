import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Bright "thick glass" material: a translucent white frame around inset
/// content, edge highlights, a surface sheen and a two-layer shadow.
///
/// The block itself is pure decoration (no [BackdropFilter]) so it stays cheap
/// in long scrolling lists on web. Blur lives only where it is needed:
/// [SoriGlassFade] (progressive blur + smoked tint at the bottom of a photo,
/// no backdrop read) and [SoriFrostedPanel] (small boxed panel).
///
/// First used by HOME ▸ DESK B&A 게시물 cards (`ManagementCaseCard(glass: true)`).
/// Other surfaces can opt in later by wrapping content in [SoriGlassBlock].
abstract final class SoriGlassStyle {
  /// Warm white canvas behind glass blocks — reads white, not beige or gray.
  static const Color warmCanvas = Color(0xFFFBF9F6);

  static const double blockRadius = 24;

  /// Thickness of the translucent frame around the inset content.
  static const double frameWidth = 9;

  /// Frame: white 72% → 58% over the warm canvas.
  static const LinearGradient frameGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xB8FFFFFF), Color(0x94FFFFFF)],
  );

  /// Outer edge: bright white on top/left fading to a faint dark line on
  /// bottom/right.
  static const LinearGradient edgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xE6FFFFFF), Color(0x80FFFFFF), Color(0x14000000)],
    stops: [0.0, 0.45, 1.0],
  );
  static const double edgeWidth = 1.25;

  /// Bevel where the inset content meets the frame — the inverse of the
  /// outer edge (dark top/left, bright bottom/right) so the frame reads thick.
  static const LinearGradient innerEdgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1F000000), Color(0x0A000000), Color(0xB3FFFFFF)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Diagonal gloss over the upper-left part of the block (18% → 0).
  static const LinearGradient sheenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.center,
    colors: [Color(0x2EFFFFFF), Color(0x14FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Wide soft lift + tight contact shadow (replaces a single gray blur).
  /// Painted outside the block only ([SoriGlassShadowPainter]) so it never
  /// shows through the translucent frame and grays it out.
  static const List<BoxShadow> shadows = [
    BoxShadow(color: Color(0x12000000), blurRadius: 36, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x17000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  // ── Small glass controls (chips, pills, round icon buttons) ──────────────

  static const LinearGradient controlFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x4DFFFFFF), Color(0x29FFFFFF)], // 30% → 16%
  );
  static const Color controlBorder = Color(0x8CFFFFFF); // 55%

  static const List<BoxShadow> controlShadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Keeps white glyphs legible on bright photos.
  static const List<Shadow> glyphShadow = [
    Shadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static BoxDecoration controlDecoration({
    BoxShape shape = BoxShape.rectangle,
    double radius = 999,
  }) {
    return BoxDecoration(
      gradient: controlFill,
      shape: shape,
      borderRadius: shape == BoxShape.circle
          ? null
          : BorderRadius.circular(radius),
      border: Border.all(color: controlBorder),
      boxShadow: controlShadow,
    );
  }

  // ── Frosted text panel ───────────────────────────────────────────────────

  /// Smoked glass: white text stays readable on bright photos.
  static const LinearGradient panelFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x2E000000), Color(0x42000000)], // 18% → 26%
  );
  static const Color panelBorder = Color(0x40FFFFFF);
  static const double panelBlurSigma = 12;

  static const List<Shadow> textShadow = [
    Shadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 1)),
  ];

  // ── Progressive blur fade (text straight on the photo, no box) ───────────

  /// Share of the photo height covered by [SoriGlassFade], from the bottom.
  static const double fadeHeightFactor = 0.5;

  /// Smoked tint reached at the very bottom — same as the panel's bottom
  /// ([panelFill] 26% black).
  static const Color fadeTint = Color(0x42000000);

  /// Smoothstep ramp (3t² − 2t³) sampled at 8 stops: starts flat at the top so
  /// the blur has no visible starting edge, lands flat at full strength.
  static const List<double> fadeStops = [0, .15, .3, .45, .6, .75, .9, 1];
  static const List<double> fadeRamp = [
    0,
    .061,
    .216,
    .425,
    .648,
    .844,
    .972,
    1,
  ];

  /// Top → bottom gradient from transparent to [color] along [fadeRamp].
  static LinearGradient fadeGradient(Color color) {
    final a = color.a;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [for (final t in fadeRamp) color.withValues(alpha: a * t)],
      stops: fadeStops,
    );
  }
}

/// Thick translucent glass frame with edge highlights, sheen and shadow.
/// [child] is inset by [frame] and clipped to a concentric inner radius.
class SoriGlassBlock extends StatelessWidget {
  const SoriGlassBlock({
    super.key,
    required this.child,
    this.margin,
    this.radius = SoriGlassStyle.blockRadius,
    this.frame = SoriGlassStyle.frameWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double frame;

  double get innerRadius => radius - frame;

  @override
  Widget build(BuildContext context) {
    final outer = BorderRadius.circular(radius);
    final block = CustomPaint(
      painter: SoriGlassShadowPainter(radius: radius),
      child: DecoratedBox(
        key: const Key('sori-glass-block'),
        decoration: BoxDecoration(
          gradient: SoriGlassStyle.frameGradient,
          borderRadius: outer,
        ),
        child: Stack(
          children: [
            Padding(
              key: const Key('sori-glass-frame'),
              padding: EdgeInsets.all(frame),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(innerRadius),
                child: child,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const Key('sori-glass-sheen'),
                  decoration: BoxDecoration(
                    borderRadius: outer,
                    gradient: SoriGlassStyle.sheenGradient,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const Key('sori-glass-edge'),
                  painter: SoriGlassEdgePainter(
                    radius: radius,
                    innerInset: frame,
                    innerRadius: innerRadius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final m = margin;
    return m == null ? block : Padding(padding: m, child: block);
  }
}

/// Paints [shadows] around a rounded rect but clips out the rect itself,
/// so a translucent surface on top stays clean instead of turning gray.
class SoriGlassShadowPainter extends CustomPainter {
  const SoriGlassShadowPainter({
    required this.radius,
    this.shadows = SoriGlassStyle.shadows,
  });

  final double radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(120)),
      Path()..addRRect(rrect),
    );
    canvas.save();
    canvas.clipPath(outside);
    for (final shadow in shadows) {
      canvas.drawRRect(
        rrect.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SoriGlassShadowPainter old) =>
      old.radius != radius || old.shadows != shadows;
}

/// Gradient stroke on the outer edge (+ optional hairline around the inset).
class SoriGlassEdgePainter extends CustomPainter {
  const SoriGlassEdgePainter({
    required this.radius,
    this.gradient = SoriGlassStyle.edgeGradient,
    this.strokeWidth = SoriGlassStyle.edgeWidth,
    this.innerInset,
    this.innerRadius,
    this.innerGradient = SoriGlassStyle.innerEdgeGradient,
  });

  final double radius;
  final Gradient gradient;
  final double strokeWidth;
  final double? innerInset;
  final double? innerRadius;
  final Gradient innerGradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final half = strokeWidth / 2;
    final outer = RRect.fromRectAndRadius(
      rect.deflate(half),
      Radius.circular((radius - half).clamp(0, radius)),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..shader = gradient.createShader(rect),
    );

    final inset = innerInset;
    if (inset != null && inset > 0) {
      final r = innerRadius ?? (radius - inset);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(inset - 0.5),
          Radius.circular(r + 0.5),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = innerGradient.createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SoriGlassEdgePainter old) =>
      old.radius != radius ||
      old.gradient != gradient ||
      old.strokeWidth != strokeWidth ||
      old.innerInset != innerInset ||
      old.innerRadius != innerRadius ||
      old.innerGradient != innerGradient;
}

/// Small frosted panel. The blur is clipped to the panel only.
class SoriFrostedPanel extends StatelessWidget {
  const SoriFrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
    this.radius = 14,
    this.blurSigma = SoriGlassStyle.panelBlurSigma,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          key: const Key('sori-frosted-panel'),
          decoration: BoxDecoration(
            gradient: SoriGlassStyle.panelFill,
            borderRadius: r,
            border: Border.all(color: SoriGlassStyle.panelBorder),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Progressive "frosted smoke" fade over the bottom of a photo: fully clear at
/// the top of the zone, full [blurSigma] blur + full [tint] at the bottom edge.
///
/// No [BackdropFilter]: a blurred copy of [child] (the same photo, so the image
/// cache shares one decode) is masked with a smooth alpha ramp, then a smoked
/// tint uses the same ramp. Only the bottom zone is painted, so the blur is
/// clipped to it. Everything added here ignores pointers and semantics.
///
/// Wrap each photo pane individually (e.g. both halves of a
/// [BeforeAfterSlider]) so the fade follows any clipping applied to the pane.
class SoriGlassFade extends StatelessWidget {
  const SoriGlassFade({
    super.key,
    required this.child,
    this.heightFactor = SoriGlassStyle.fadeHeightFactor,
    this.blurSigma = SoriGlassStyle.panelBlurSigma,
    this.tint = SoriGlassStyle.fadeTint,
  });

  final Widget child;
  final double heightFactor;
  final double blurSigma;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        if (!w.isFinite || !h.isFinite || h <= 0) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: h * heightFactor,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Stack(
                    key: const Key('sori-glass-fade'),
                    fit: StackFit.expand,
                    children: [
                      ShaderMask(
                        key: const Key('sori-glass-fade-blur'),
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => SoriGlassStyle.fadeGradient(
                          const Color(0xFF000000),
                        ).createShader(rect),
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.bottomCenter,
                            minWidth: w,
                            maxWidth: w,
                            minHeight: h,
                            maxHeight: h,
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: blurSigma,
                                sigmaY: blurSigma,
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                      DecoratedBox(
                        key: const Key('sori-glass-fade-tint'),
                        decoration: BoxDecoration(
                          gradient: SoriGlassStyle.fadeGradient(tint),
                        ),
                      ),
                    ],
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
