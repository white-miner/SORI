import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../widgets/glass/sori_glass_style.dart';
import 'sori_tokens.dart';

/// App-wide **no-blur glass look** for controls (buttons, chips, segments,
/// FAB) on the warm-white canvas ([SoriTokens.canvas]).
///
/// Glass here = translucent white fill + dark hairline + top highlight +
/// soft shadow. Nothing in the theme blurs: on a plain canvas there is
/// nothing behind a control to blur, so a `BackdropFilter` would only cost GPU.
/// Real blur stays opt-in for floating layers and controls over photos/maps
/// (see `docs/SORI_GLASS_PERFORMANCE.md`), using [blurSigma].
///
/// [onMediaFill] / [onMediaBorder] / [onMediaShadows] / [onMediaGlyphShadows]
/// are the DESK white-on-photo recipe ([SoriGlassStyle.controlDecoration]).
@immutable
class SoriGlassTheme extends ThemeExtension<SoriGlassTheme> {
  const SoriGlassTheme({
    required this.fill,
    required this.fillPressed,
    required this.fillDisabled,
    required this.border,
    required this.highlight,
    required this.pressOverlay,
    required this.foreground,
    required this.shadows,
    required this.elevation,
    required this.shadowColor,
    required this.radius,
    required this.blurSigma,
    required this.onMediaFill,
    required this.onMediaBorder,
    required this.onMediaShadows,
    required this.onMediaGlyphShadows,
    required this.onMediaForeground,
  });

  /// Default tokens registered in `AppTheme.theme`.
  static const SoriGlassTheme standard = SoriGlassTheme(
    fill: Color(0xCCFFFFFF), // white 80%
    fillPressed: Color(0xE6FFFFFF), // white 90%
    fillDisabled: Color(0x80FFFFFF), // white 50%
    border: Color(0x17000000), // black 9% hairline
    highlight: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x73FFFFFF), Color(0x00FFFFFF)], // white 45% → 0
      stops: [0.0, 0.6],
    ),
    pressOverlay: Color(0x0F111111), // charcoal 6%
    foreground: SoriTokens.textPrimary,
    shadows: [
      BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 3)),
      BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
    elevation: 1,
    shadowColor: Color(0x40000000),
    radius: 14,
    blurSigma: 12,
    onMediaFill: SoriGlassStyle.controlFill,
    onMediaBorder: SoriGlassStyle.controlBorder,
    onMediaShadows: SoriGlassStyle.controlShadow,
    onMediaGlyphShadows: SoriGlassStyle.glyphShadow,
    onMediaForeground: Colors.white,
  );

  /// Translucent control fill on the canvas / white cards.
  final Color fill;
  final Color fillPressed;
  final Color fillDisabled;

  /// Dark hairline — the edge that makes a near-white control readable.
  final Color border;

  /// Top-edge sheen painted inside the control (no blur).
  final LinearGradient highlight;

  /// Pressed/hovered overlay for flat text buttons.
  final Color pressOverlay;

  /// Charcoal label/icon colour for legibility on the warm canvas.
  final Color foreground;

  /// Soft shadow for custom glass widgets ([controlDecoration]).
  final List<BoxShadow> shadows;

  /// Material elevation + colour used by themed buttons (a [ButtonStyle]
  /// cannot take a [BoxShadow] list).
  final double elevation;
  final Color shadowColor;

  final double radius;

  /// Blur for opt-in real-glass widgets only. Never used by the theme.
  final double blurSigma;

  // ── Over photos / maps (DESK B&A card recipe) ───────────────────────────
  final Gradient onMediaFill;
  final Color onMediaBorder;
  final List<BoxShadow> onMediaShadows;
  final List<Shadow> onMediaGlyphShadows;
  final Color onMediaForeground;

  static SoriGlassTheme of(BuildContext context) =>
      Theme.of(context).extension<SoriGlassTheme>() ?? standard;

  /// Glass control on the plain canvas (no blur).
  BoxDecoration controlDecoration({
    BoxShape shape = BoxShape.rectangle,
    double? radius,
    bool pressed = false,
  }) {
    final base = pressed ? fillPressed : fill;
    return BoxDecoration(
      // Fill + top sheen baked into one gradient (BoxDecoration ignores
      // `color` when a gradient is set).
      gradient: LinearGradient(
        begin: highlight.begin,
        end: highlight.end,
        stops: highlight.stops,
        colors: [for (final c in highlight.colors) Color.alphaBlend(c, base)],
      ),
      shape: shape,
      borderRadius: shape == BoxShape.circle
          ? null
          : BorderRadius.circular(radius ?? this.radius),
      border: Border.all(color: border),
      boxShadow: shadows,
    );
  }

  /// Glass control over a photo/map (white glyphs, no blur).
  BoxDecoration onMediaDecoration({
    BoxShape shape = BoxShape.rectangle,
    double radius = 999,
  }) {
    return BoxDecoration(
      gradient: onMediaFill,
      shape: shape,
      borderRadius: shape == BoxShape.circle
          ? null
          : BorderRadius.circular(radius),
      border: Border.all(color: onMediaBorder),
      boxShadow: onMediaShadows,
    );
  }

  /// [ButtonStyle.backgroundBuilder] that paints [highlight] over the fill.
  /// The button's Material clips it to the button shape.
  Widget highlightBackground(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) {
    if (states.contains(WidgetState.disabled)) {
      return child ?? const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(gradient: highlight),
      child: child,
    );
  }

  /// Local opt-out for outlined buttons on dark surfaces (photo viewers etc.):
  /// `style: OutlinedButton.styleFrom(...).merge(SoriGlassTheme.flatOnDark)`.
  static final ButtonStyle flatOnDark = ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    elevation: const WidgetStatePropertyAll<double>(0),
    backgroundBuilder: (context, states, child) =>
        child ?? const SizedBox.shrink(),
  );

  @override
  SoriGlassTheme copyWith({
    Color? fill,
    Color? fillPressed,
    Color? fillDisabled,
    Color? border,
    LinearGradient? highlight,
    Color? pressOverlay,
    Color? foreground,
    List<BoxShadow>? shadows,
    double? elevation,
    Color? shadowColor,
    double? radius,
    double? blurSigma,
    Gradient? onMediaFill,
    Color? onMediaBorder,
    List<BoxShadow>? onMediaShadows,
    List<Shadow>? onMediaGlyphShadows,
    Color? onMediaForeground,
  }) {
    return SoriGlassTheme(
      fill: fill ?? this.fill,
      fillPressed: fillPressed ?? this.fillPressed,
      fillDisabled: fillDisabled ?? this.fillDisabled,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      pressOverlay: pressOverlay ?? this.pressOverlay,
      foreground: foreground ?? this.foreground,
      shadows: shadows ?? this.shadows,
      elevation: elevation ?? this.elevation,
      shadowColor: shadowColor ?? this.shadowColor,
      radius: radius ?? this.radius,
      blurSigma: blurSigma ?? this.blurSigma,
      onMediaFill: onMediaFill ?? this.onMediaFill,
      onMediaBorder: onMediaBorder ?? this.onMediaBorder,
      onMediaShadows: onMediaShadows ?? this.onMediaShadows,
      onMediaGlyphShadows: onMediaGlyphShadows ?? this.onMediaGlyphShadows,
      onMediaForeground: onMediaForeground ?? this.onMediaForeground,
    );
  }

  @override
  SoriGlassTheme lerp(covariant SoriGlassTheme? other, double t) {
    if (other == null) return this;
    return SoriGlassTheme(
      fill: Color.lerp(fill, other.fill, t)!,
      fillPressed: Color.lerp(fillPressed, other.fillPressed, t)!,
      fillDisabled: Color.lerp(fillDisabled, other.fillDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      highlight: LinearGradient.lerp(highlight, other.highlight, t)!,
      pressOverlay: Color.lerp(pressOverlay, other.pressOverlay, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      shadows: BoxShadow.lerpList(shadows, other.shadows, t)!,
      elevation: lerpDouble(elevation, other.elevation, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      radius: lerpDouble(radius, other.radius, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      onMediaFill: Gradient.lerp(onMediaFill, other.onMediaFill, t)!,
      onMediaBorder: Color.lerp(onMediaBorder, other.onMediaBorder, t)!,
      onMediaShadows:
          BoxShadow.lerpList(onMediaShadows, other.onMediaShadows, t)!,
      onMediaGlyphShadows:
          Shadow.lerpList(onMediaGlyphShadows, other.onMediaGlyphShadows, t)!,
      onMediaForeground:
          Color.lerp(onMediaForeground, other.onMediaForeground, t)!,
    );
  }
}
