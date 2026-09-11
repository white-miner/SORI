import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import 'sori_action_buttons.dart';

/// 빈 상태 = 다음 행동 (DESIGN LAWS §9). 큰 일러스트·오류코드 금지.
class SoriEmptyState extends StatelessWidget {
  const SoriEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textSecondary,
            ),
          ),
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
    );
  }
}
