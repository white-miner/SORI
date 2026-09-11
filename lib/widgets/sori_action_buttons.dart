import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import 'sori_pressable.dart';

/// Filled brand CTA — 화면당 최대 1개 (DESIGN LAWS).
class SoriPrimaryButton extends StatelessWidget {
  const SoriPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = SoriPressable(
      enabled: onPressed != null,
      semanticLabel: label,
      onTap: onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: onPressed == null
              ? SoriTokens.brand.withValues(alpha: 0.4)
              : SoriTokens.brand,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: SoriTokens.onBrand,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class SoriSecondaryButton extends StatelessWidget {
  const SoriSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = SoriPressable(
      enabled: onPressed != null,
      semanticLabel: label,
      onTap: onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SoriTokens.inputBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onPressed == null
                ? SoriTokens.textTertiary
                : SoriTokens.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// 파괴 행동만 — Red. 일반 알림에 쓰지 말 것.
class SoriDestructiveButton extends StatelessWidget {
  const SoriDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = SoriPressable(
      enabled: onPressed != null,
      semanticLabel: label,
      onTap: onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SoriTokens.destructive),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: SoriTokens.destructive,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
