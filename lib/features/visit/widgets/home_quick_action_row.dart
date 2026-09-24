import 'package:flutter/material.dart';

import '../home_visual_tokens.dart';

/// 신규 / 재방문. 사진 위 캡션과 같은 검은 패널.
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
            eyebrow: 'NEW CLIENT',
            label: '신규 고객',
            icon: Icons.add_rounded,
            onTap: onNewCustomer,
            fill: HomeVisualTokens.quickNewFill,
            foreground: Colors.white,
          ),
        ),
        const SizedBox(width: HomeVisualTokens.quickActionGap),
        Expanded(
          child: _QuickActionButton(
            eyebrow: 'RETURNING',
            label: '재방문 고객',
            icon: Icons.search_rounded,
            onTap: onReturningCustomer,
            fill: HomeVisualTokens.quickReturningFill,
            foreground: HomeVisualTokens.tabActiveColor,
            borderColor: HomeVisualTokens.quickReturningBorder,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.eyebrow,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.fill,
    required this.foreground,
    this.borderColor,
  });

  final String eyebrow;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color fill;
  final Color foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HomeVisualTokens.quickActionRadius);
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          height: 96,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: foreground.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.55,
                          color: foreground.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: foreground,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
