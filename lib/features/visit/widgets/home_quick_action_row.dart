import 'package:flutter/material.dart';

import '../home_visual_tokens.dart';

/// PRD v7.0 ② — 신규 / 재방문 라우팅 버튼.
///
/// Q2(a) 색상 헌법: 보라 = 신규 진입, Green = 케어 실행(Timer 탭 전용).
class HomeQuickActionRow extends StatelessWidget {
  const HomeQuickActionRow({
    super.key,
    required this.onNewCustomer,
    required this.onReturningCustomer,
  });

  final VoidCallback onNewCustomer;
  final VoidCallback onReturningCustomer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            label: '신규 고객',
            icon: Icons.person_add_alt_1_rounded,
            filled: true,
            onTap: onNewCustomer,
          ),
        ),
        const SizedBox(width: HomeVisualTokens.quickActionGap),
        Expanded(
          child: _QuickActionButton(
            label: '재방문 고객',
            icon: Icons.history_rounded,
            filled: false,
            onTap: onReturningCustomer,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : HomeVisualTokens.dateTextColor;
    final radius =
        BorderRadius.circular(HomeVisualTokens.quickActionRadius);

    final button = Material(
      color: filled
          ? HomeVisualTokens.quickNewFill
          : HomeVisualTokens.quickReturningFill,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: filled
                ? null
                : Border.all(
                    color: HomeVisualTokens.quickReturningBorder,
                  ),
          ),
          child: SizedBox(
            height: HomeVisualTokens.quickActionHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: HomeVisualTokens.quickActionIconSize,
                  color: fg,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: HomeVisualTokens.quickActionTextSize,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!filled) return button;
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [HomeVisualTokens.quickNewShadow],
      ),
      child: button,
    );
  }
}
