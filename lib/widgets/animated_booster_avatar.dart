import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import 'sori_logo.dart';

/// Boosted post author avatar — continuous rotating gradient color ring.
///
/// PO: when `isBoosted == true` (AD / fan / premium), show a 2–3px spinning
/// SweepGradient border so boosted posts catch the eye while scrolling.
class AnimatedBoosterAvatar extends StatefulWidget {
  const AnimatedBoosterAvatar({
    super.key,
    required this.imageUrl,
    required this.isBoosted,
    this.isFanBoost = false,
    this.premiumTier = '',
    this.radius = 18,
    this.ringWidth = 2.5,
    this.onTap,
    this.fallbackChild,
  });

  final String imageUrl;

  /// Any active booster (shop AD, fan boost, or premium overlay).
  final bool isBoosted;
  final bool isFanBoost;

  /// gold | platinum | ''
  final String premiumTier;
  final double radius;

  /// Visible border thickness of the spinning color ring (2–3px).
  final double ringWidth;
  final VoidCallback? onTap;
  final Widget? fallbackChild;

  @override
  State<AnimatedBoosterAvatar> createState() => _AnimatedBoosterAvatarState();
}

class _AnimatedBoosterAvatarState extends State<AnimatedBoosterAvatar>
    with SingleTickerProviderStateMixin {
  static const Duration _spinDuration = Duration(seconds: 3);

  AnimationController? _spin;

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant AnimatedBoosterAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBoosted != widget.isBoosted) {
      _syncSpin();
    }
  }

  void _syncSpin() {
    if (widget.isBoosted) {
      _spin ??= AnimationController(vsync: this, duration: _spinDuration);
      if (!_spin!.isAnimating) {
        _spin!.repeat();
      }
    } else {
      _spin?.stop();
      _spin?.reset();
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    _spin = null;
    super.dispose();
  }

  List<Color> get _ringColors {
    final tier = widget.premiumTier.trim().toLowerCase();
    if (tier == 'platinum') {
      return const [
        Color(0xFFE2E8F0),
        Color(0xFF94A3B8),
        Color(0xFFF8FAFC),
        Color(0xFFCBD5E1),
        Color(0xFFE2E8F0),
      ];
    }
    if (tier == 'gold') {
      return const [
        Color(0xFFFBBF24),
        Color(0xFFF59E0B),
        Color(0xFFFDE68A),
        Color(0xFFD97706),
        Color(0xFFFBBF24),
      ];
    }
    if (widget.isFanBoost) {
      return const [
        Color(0xFF7C3AED),
        Color(0xFFF472B6),
        Color(0xFF38BDF8),
        Color(0xFFA78BFA),
        Color(0xFF7C3AED),
      ];
    }
    // Shop AD booster — gold / primary accent ring
    return const [
      Color(0xFFFBBF24),
      Color(0xFFF59E0B),
      Color(0xFFE11D48),
      Color(0xFF7C3AED),
      Color(0xFFFBBF24),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl.trim();
    final hasImage = url.isNotEmpty && !url.startsWith('data:');
    final ring = widget.ringWidth.clamp(2.0, 3.0);
    final photoDiameter = widget.radius * 2;
    final outerDiameter = widget.isBoosted ? photoDiameter + ring * 2 : photoDiameter;

    final photo = CircleAvatar(
      radius: widget.radius,
      backgroundColor: SoriTokens.surfaceOverlay,
      backgroundImage: hasImage ? NetworkImage(url) : null,
      child: !hasImage
          ? (widget.fallbackChild ??
              Padding(
                padding: EdgeInsets.all(widget.radius * 0.28),
                child: const SoriLogo(width: 20, height: 20),
              ))
          : null,
    );

    Widget avatar;
    if (widget.isBoosted && _spin != null) {
      // RotationTransition + SweepGradient; opaque center makes ring look like a border.
      avatar = SizedBox(
        width: outerDiameter,
        height: outerDiameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _spin!,
              child: Container(
                width: outerDiameter,
                height: outerDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: _ringColors),
                ),
              ),
            ),
            Container(
              width: photoDiameter,
              height: photoDiameter,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: SoriTokens.surface,
              ),
              clipBehavior: Clip.antiAlias,
              child: photo,
            ),
          ],
        ),
      );
    } else {
      avatar = photo;
    }

    if (widget.onTap != null) {
      avatar = GestureDetector(onTap: widget.onTap, child: avatar);
    }
    return avatar;
  }
}
