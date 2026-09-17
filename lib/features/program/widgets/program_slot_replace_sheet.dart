import 'package:flutter/material.dart';

import '../../visit/home_visual_tokens.dart';

/// R3 — 3번째 체크 때 어느 슬롯을 바꿀지 묻는다. 몰래 버리지 않는다.
Future<int?> showProgramSlotReplaceSheet({
  required BuildContext context,
  required String leftName,
  required String rightName,
  required String incomingName,
}) {
  return showModalBottomSheet<int>(
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
              Text(
                '$incomingName을 넣으려면 어느 것을 뺄까요',
                key: const Key('program-slot-replace-title'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                key: const Key('program-slot-replace-0'),
                onPressed: () => Navigator.pop(ctx, 0),
                child: Text('왼쪽 빼기 · $leftName'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('program-slot-replace-1'),
                onPressed: () => Navigator.pop(ctx, 1),
                child: Text('오른쪽 빼기 · $rightName'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
