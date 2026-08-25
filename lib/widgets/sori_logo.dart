import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

/// SORI 브랜드 로고 에셋 헬퍼.
class SoriLogo extends StatelessWidget {
  const SoriLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  static const String assetPath = 'assets/images/sori_logo.png';

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width ?? height ?? 48,
          height: height ?? width ?? 48,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF18181B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'S',
                style: TextStyle(
                  color: SoriTokens.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
