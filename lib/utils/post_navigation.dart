import 'package:flutter/material.dart';

import '../models/home_feed_entry.dart';
import '../models/unified_feed_item.dart';
import '../services/sori_store.dart';
import '../views/sori_post_original_page.dart';
import '../widgets/post/post_view_data.dart';
import '../views/device_review_detail_page.dart';
import '../views/seminar_class_detail_page.dart';

/// Central routing for all post tiers → Original detail.
void openPostOriginal(
  BuildContext context, {
  required PostViewData data,
  required SoriStore store,
  bool liked = false,
  bool bookmarked = false,
  VoidCallback? onLike,
  VoidCallback? onComment,
  VoidCallback? onBookmark,
  VoidCallback? onMentoring,
  VoidCallback? onBoost,
}) {
  switch (data.kind) {
    case PostViewKind.seminar:
      if (data.seminar != null) {
        SeminarClassDetailPage.open(
          context,
          store: store,
          classId: data.seminar!.id,
        );
        return;
      }
    case PostViewKind.deviceReview:
    case PostViewKind.marketplace:
      if (data.post != null) {
        DeviceReviewDetailPage.open(
          context,
          store: store,
          post: data.post!,
        );
        return;
      }
    case PostViewKind.ba:
    case PostViewKind.whisper:
    case PostViewKind.interior:
      break;
  }

  SoriPostOriginalPage.open(
    context,
    data: data,
    store: store,
    liked: liked,
    bookmarked: bookmarked,
    onLike: onLike,
    onComment: onComment,
    onBookmark: onBookmark,
    onMentoring: onMentoring,
    onBoost: onBoost,
  );
}

void openUnifiedPostOriginal(
  BuildContext context, {
  required UnifiedFeedItem item,
  required SoriStore store,
}) {
  openPostOriginal(
    context,
    data: PostViewData.fromUnifiedFeedItem(item),
    store: store,
  );
}

void openHomeEntryOriginal(
  BuildContext context, {
  required HomeFeedEntry entry,
  required SoriStore store,
  bool liked = false,
  bool bookmarked = false,
  VoidCallback? onLike,
  VoidCallback? onComment,
  VoidCallback? onBookmark,
  VoidCallback? onMentoring,
  VoidCallback? onBoost,
}) {
  openPostOriginal(
    context,
    data: PostViewData.fromHomeFeedEntry(entry),
    store: store,
    liked: liked,
    bookmarked: bookmarked,
    onLike: onLike,
    onComment: onComment,
    onBookmark: onBookmark,
    onMentoring: onMentoring,
    onBoost: onBoost,
  );
}

/// @deprecated Use [openUnifiedPostOriginal].
void openMiniPostDetail(
  BuildContext context, {
  required UnifiedFeedItem item,
  required SoriStore store,
}) =>
    openUnifiedPostOriginal(context, item: item, store: store);
