import 'package:flutter/material.dart';

import '../models/omni_compose_category.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/category_presentation_map.dart';
import '../utils/sori_bottom_sheet.dart';
import '../views/post_first_creation_page.dart';

enum UnifiedComposeCategory {
  whisper,
  interior,
  deviceReview,
  marketplace;

  String get label => switch (this) {
        UnifiedComposeCategory.whisper =>
          CategoryPresentationMap.labelOf('whisper', fallback: '조용한 이야기'),
        UnifiedComposeCategory.interior => '인테리어',
        UnifiedComposeCategory.deviceReview =>
          CategoryPresentationMap.labelOf('tip_device', fallback: '현장 팁'),
        UnifiedComposeCategory.marketplace => '중고',
      };
}

/// PRD v7.8 C6 — 빠른 등록 시트 (전후·세미나·팁·멘토) → Omni 짧 폼.
Future<void> showQuickComposeSheet(
  BuildContext context, {
  required SoriStore store,
  required bool isDirector,
  required VoidCallback onDirectorOnly,
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
            '빠른 등록',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '카테고리를 고르면 짧은 작성 화면으로 이동합니다.',
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
              for (final cat in OmniComposeCategory.quickComposePrimary)
                _ComposeCategoryChip(
                  key: Key('quick-compose-${cat.name}'),
                  label: cat.label,
                  onTap: () async {
                    if (!isDirector) {
                      Navigator.pop(ctx);
                      onDirectorOnly();
                      return;
                    }
                    Navigator.pop(ctx);
                    await PostFirstCreationPage.open(
                      context,
                      store: store,
                      initialCategory: cat,
                    );
                  },
                ),
              if (OmniComposeCategory.quickComposeMore.isNotEmpty)
                _ComposeCategoryChip(
                  key: const Key('quick-compose-more'),
                  label: CategoryPresentationMap.composeMoreCategories,
                  onTap: () async {
                    final more = await showSoriSolidBottomSheet<OmniComposeCategory>(
                      context: ctx,
                      builder: (sheetCtx) => SoriSheetFrame(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              CategoryPresentationMap.composeMoreCategories,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final cat
                                in OmniComposeCategory.quickComposeMore)
                              ListTile(
                                title: Text(cat.label),
                                subtitle: Text(cat.description),
                                onTap: () => Navigator.pop(sheetCtx, cat),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (more == null) return;
                    if (!ctx.mounted) return;
                    if (!isDirector) {
                      Navigator.pop(ctx);
                      onDirectorOnly();
                      return;
                    }
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    await PostFirstCreationPage.open(
                      context,
                      store: store,
                      initialCategory: more,
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Legacy FAB → 4 category chips → existing composer sheets.
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
          Text(
            CategoryPresentationMap.composeTitle,
            style: const TextStyle(
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
    super.key,
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
