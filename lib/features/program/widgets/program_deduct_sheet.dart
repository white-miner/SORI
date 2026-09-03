import 'package:flutter/material.dart';

import '../../../models/program_sales.dart';
import '../../visit/home_visual_tokens.dart';

/// R8 — 매칭 회원권이 2장 이상이면 어느 장을 깎을지 묻는다.
Future<String?> showProgramDeductPickSheet({
  required BuildContext context,
  required List<ProgramMembership> candidates,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: HomeVisualTokens.heroCardFill,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '어느 회원권에서 차감할까요',
                key: Key('program-deduct-pick-title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              for (final m in candidates) ...[
                OutlinedButton(
                  key: Key('program-deduct-pick-${m.id}'),
                  onPressed: () => Navigator.pop(ctx, m.id),
                  child: Text(
                    '${m.serviceName} · 잔여 ${m.remainingVisits}회'
                    '${m.expiresAt == null ? '' : ' · 만료 임박'}',
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> resolveProgramDeductMembership({
  required BuildContext context,
  required List<ProgramMembership> candidates,
}) async {
  if (candidates.isEmpty) return null;
  if (candidates.length == 1) return candidates.first.id;
  if (!context.mounted) return null;
  return showProgramDeductPickSheet(
    context: context,
    candidates: candidates,
  );
}
