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
          ),
        ),
        const SizedBox(width: HomeVisualTokens.quickActionGap),
        Expanded(
          child: _QuickActionButton(
            eyebrow: 'RETURNING',
            label: '재방문 고객',
            icon: Icons.search_rounded,
            onTap: onReturningCustomer,
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
  });

  final String eyebrow;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HomeVisualTokens.quickActionRadius);
    return Material(
      color: const Color(0xFF1C1C1E),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          height: 112,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: const Color(0xFFC7C7CC)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFFC7C7CC),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: Colors.white,
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
