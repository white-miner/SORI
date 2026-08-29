import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/unified_feed_item.dart';
import '../pages/case_detail_page.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../views/device_review_detail_page.dart';
import '../views/seminar_class_detail_page.dart';
import '../widgets/whisper_post_card.dart';

/// Routes [UnifiedFeedItem] to the existing detail surfaces.
void openMiniPostDetail(
  BuildContext context, {
  required UnifiedFeedItem item,
  required SoriStore store,
}) {
  switch (item.kind) {
    case UnifiedFeedKind.ba:
      CaseDetailPage.push(
        context,
        page: CaseDetailPage(
          item: item.caseItem!,
          review: store.reviewForChart(item.caseItem!.chart.id),
          currentUserId: store.session?.id,
        ),
      );
    case UnifiedFeedKind.seminar:
      SeminarClassDetailPage.open(
        context,
        store: store,
        classId: item.seminar!.id,
      );
    case UnifiedFeedKind.whisper:
      _openWhisperSheet(context, item.post!, store);
    case UnifiedFeedKind.interior:
      _openInteriorSheet(context, item.post!, store);
    case UnifiedFeedKind.deviceReview:
    case UnifiedFeedKind.marketplace:
      DeviceReviewDetailPage.open(
        context,
        store: store,
        post: item.post!,
      );
  }
}

void _openWhisperSheet(
  BuildContext context,
  CommunityPost post,
  SoriStore store,
) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: WhisperPostCard(post: post, store: store),
      ),
    ),
  );
}

void _openInteriorSheet(
  BuildContext context,
  CommunityPost post,
  SoriStore store,
) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              post.title.trim().ifEmpty(post.shopName),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.body.trim(),
              style: const TextStyle(
                height: 1.45,
                color: SoriTokens.textSecondary,
              ),
            ),
            if (post.primaryImageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.primaryImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

extension _MiniPostString on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : trim();
}
