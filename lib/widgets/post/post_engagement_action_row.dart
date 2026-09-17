import 'package:flutter/material.dart';

import '../../models/post_engagement_bindings.dart';
import 'post_action_row.dart';

/// Maps [PostEngagementBindings] to GIS action dock with disabled UX.
class PostEngagementActionRow extends StatelessWidget {
  const PostEngagementActionRow({
    super.key,
    required this.bindings,
    this.compact = false,
  });

  final PostEngagementBindings bindings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PostActionRow(
      compact: compact,
      liked: bindings.liked,
      bookmarked: bindings.bookmarked,
      likeCount: bindings.likeCount,
      commentCount: bindings.commentCount,
      mentoringActive: bindings.mentoringEnabled && bindings.liked,
      isBoosted: bindings.boostEnabled,
      onLike: _wrap(
        context,
        enabled: bindings.likeEnabled,
        reason: bindings.likeDisabledReason,
        action: bindings.onLike,
      ),
      onComment: _wrap(
        context,
        enabled: bindings.commentEnabled,
        reason: bindings.commentDisabledReason,
        action: bindings.onComment,
      ),
      onBookmark: _wrap(
        context,
        enabled: bindings.bookmarkEnabled,
        reason: bindings.bookmarkDisabledReason,
        action: bindings.onBookmark,
      ),
      onMentoring: _wrap(
        context,
        enabled: bindings.mentoringEnabled,
        reason: bindings.mentoringDisabledReason,
        action: bindings.onMentoring,
      ),
      onBoost: _wrap(
        context,
        enabled: bindings.boostEnabled,
        reason: bindings.boostDisabledReason,
        action: bindings.onBoost,
      ),
      likeEnabled: bindings.likeEnabled,
      commentEnabled: bindings.commentEnabled,
      bookmarkEnabled: bindings.bookmarkEnabled,
      mentoringEnabled: bindings.mentoringEnabled,
      boostEnabled: bindings.boostEnabled,
    );
  }

  VoidCallback _wrap(
    BuildContext context, {
    required bool enabled,
    required String? reason,
    required VoidCallback action,
  }) {
    if (enabled) return action;
    return () {
      final msg = reason ?? '준비 중입니다';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    };
  }
}
