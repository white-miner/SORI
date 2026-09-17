import 'package:flutter/material.dart';

import 'animated_booster_avatar.dart';

export 'animated_booster_avatar.dart';

/// Legacy alias — prefer [AnimatedBoosterAvatar].
@Deprecated('Use AnimatedBoosterAvatar')
class FanBoostAuroraAvatar extends StatelessWidget {
  const FanBoostAuroraAvatar({
    super.key,
    required this.imageUrl,
    required this.isBoostActive,
    this.isFanBoost = false,
    this.premiumTier = '',
    this.radius = 18,
    this.onTap,
    this.fallbackChild,
  });

  final String imageUrl;
  final bool isBoostActive;
  final bool isFanBoost;
  final String premiumTier;
  final double radius;
  final VoidCallback? onTap;
  final Widget? fallbackChild;

  @override
  Widget build(BuildContext context) {
    return AnimatedBoosterAvatar(
      imageUrl: imageUrl,
      isBoosted: isBoostActive,
      isFanBoost: isFanBoost,
      premiumTier: premiumTier,
      radius: radius,
      onTap: onTap,
      fallbackChild: fallbackChild,
    );
  }
}
