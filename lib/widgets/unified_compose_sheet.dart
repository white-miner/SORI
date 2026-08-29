import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';

enum UnifiedComposeCategory {
  whisper,
  interior,
  deviceReview,
  marketplace;

  String get label => switch (this) {
        UnifiedComposeCategory.whisper => 'Whisper',
        UnifiedComposeCategory.interior => '인테리어',
        UnifiedComposeCategory.deviceReview => '기기 리뷰',
        UnifiedComposeCategory.marketplace => '중고',
      };
}

/// PO: FAB → 4 category chips → existing composer sheets.
Future<void> showUnifiedComposeSheet(
  BuildContext context, {
  required SoriStore store,
  required bool isDirector,
  required VoidCallback onDirectorOnly,
  required Future<void> Function() onComposeWhisper,
  required Future<void> Function() onComposeInterior,
  required Future<void> Function() onComposeDeviceReview,
  required Future<void> Function() onComposeMarketplace,
}) {
  return showSoriSolidBottomSheet<void>(
    context: context,
    enableDrag: true,
    isScrollControlled: true,
    builder: (ctx) => SoriSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '글쓰기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '카테고리를 선택하세요. B/A와 세미나는 각 전용 퍼널에서 작성합니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in UnifiedComposeCategory.values)
                _ComposeCategoryChip(
                  label: cat.label,
                  onTap: () async {
                    if (!isDirector) {
                      Navigator.pop(ctx);
                      onDirectorOnly();
                      return;
                    }
                    Navigator.pop(ctx);
                    switch (cat) {
                      case UnifiedComposeCategory.whisper:
                        await onComposeWhisper();
                      case UnifiedComposeCategory.interior:
                        await onComposeInterior();
                      case UnifiedComposeCategory.deviceReview:
                        await onComposeDeviceReview();
                      case UnifiedComposeCategory.marketplace:
                        await onComposeMarketplace();
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ComposeCategoryChip extends StatelessWidget {
  const _ComposeCategoryChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surfaceOverlay,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
