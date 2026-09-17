import 'package:flutter/material.dart';

import '../../../theme/sori_tokens.dart';
import '../../../visit_kernel/theme/visit_glass_tokens.dart';
import '../models/visit_biometrics.dart';

/// PRD v4.0 Module 3 — 수면/생리/음주 원터치 패드.
class BiometricQuickPad extends StatelessWidget {
  const BiometricQuickPad({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final VisitBiometrics value;
  final ValueChanged<VisitBiometrics> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: VisitGlassTokens.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 컨디션 (원터치)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BiometricTile(
                  label: '수면',
                  icon: Icons.bedtime_rounded,
                  state: value.sleep,
                  onTap: () => onChanged(
                    value.copyWith(sleep: value.sleep.next()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BiometricTile(
                  label: '생리',
                  icon: Icons.nightlight_round,
                  state: value.cycle,
                  onTap: () => onChanged(
                    value.copyWith(cycle: value.cycle.next()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BiometricTile(
                  label: '음주',
                  icon: Icons.local_bar_rounded,
                  state: value.alcohol,
                  onTap: () => onChanged(
                    value.copyWith(alcohol: value.alcohol.next()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BiometricTile extends StatelessWidget {
  const _BiometricTile({
    required this.label,
    required this.icon,
    required this.state,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final BiometricTouchState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      BiometricTouchState.ok => (
          Colors.white.withValues(alpha: 0.9),
          VisitGlassTokens.care,
        ),
      BiometricTouchState.caution => (
          const Color(0xFFE5E5EA),
          VisitGlassTokens.careSoft,
        ),
      BiometricTouchState.active => (
          VisitGlassTokens.care,
          Colors.white,
        ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                state.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
