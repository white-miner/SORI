import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// kDebugMode 전용 — 원장/고객 모드 즉시 전환 칩.
class DebugModeChip extends StatelessWidget {
  const DebugModeChip({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final store = SoriStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final mode = store.session?.activeMode ?? UserRole.customer;
        final isDirector = mode == UserRole.director;
        return Material(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => store.toggleActiveMode(force: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: SoriTokens.outlinePurple),
              ),
              child: Text(
                isDirector ? 'Director ▾' : 'Customer ▾',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
