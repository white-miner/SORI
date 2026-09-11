import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import 'sori_action_buttons.dart';

/// 빈 상태 = 다음 행동 (DESIGN LAWS §9).
/// 기존 `icon`/`subtitle` API 유지(Expand) + optional CTA.
class SoriEmptyState extends StatelessWidget {
  const SoriEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData? icon;
  final String message;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 40, color: SoriTokens.textTertiary),
              const SizedBox(height: 14),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: SoriTokens.textTertiary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              SoriPrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
