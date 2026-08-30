import 'package:flutter/material.dart';

/// Resolved engagement actions for a feed card (disabled = grey + snackbar).
class PostEngagementBindings {
  const PostEngagementBindings({
    required this.liked,
    required this.bookmarked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
    required this.onBookmark,
    required this.onMentoring,
    required this.onBoost,
    this.likeEnabled = true,
    this.commentEnabled = true,
    this.bookmarkEnabled = true,
    this.mentoringEnabled = false,
    this.boostEnabled = false,
    this.likeDisabledReason,
    this.commentDisabledReason,
    this.bookmarkDisabledReason,
    this.mentoringDisabledReason,
    this.boostDisabledReason,
  });

  final bool liked;
  final bool bookmarked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback onMentoring;
  final VoidCallback onBoost;
  final bool likeEnabled;
  final bool commentEnabled;
  final bool bookmarkEnabled;
  final bool mentoringEnabled;
  final bool boostEnabled;
  final String? likeDisabledReason;
  final String? commentDisabledReason;
  final String? bookmarkDisabledReason;
  final String? mentoringDisabledReason;
  final String? boostDisabledReason;
}
