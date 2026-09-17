import 'package:flutter/material.dart';

import '../glass/sori_glass_action_dock.dart';

/// Feed action row — delegates to GIS [SoriGlassActionDock].
class PostActionRow extends StatelessWidget {
  const PostActionRow({
    super.key,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required this.bookmarked,
    required this.onLike,
    required this.onComment,
    required this.onBookmark,
    required this.onMentoring,
    required this.onBoost,
    this.onMentoringLongPress,
    this.onBoostLongPress,
    this.mentoringActive = false,
    this.isBoosted = false,
    this.compact = false,
    this.loading = false,
    this.likeEnabled = true,
    this.commentEnabled = true,
    this.bookmarkEnabled = true,
    this.mentoringEnabled = true,
    this.boostEnabled = true,
  });

  final int likeCount;
  final int commentCount;
  final bool liked;
  final bool bookmarked;
  final bool mentoringActive;
  final bool isBoosted;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback onMentoring;
  final VoidCallback onBoost;
  final VoidCallback? onMentoringLongPress;
  final VoidCallback? onBoostLongPress;
  final bool compact;
  final bool loading;
  final bool likeEnabled;
  final bool commentEnabled;
  final bool bookmarkEnabled;
  final bool mentoringEnabled;
  final bool boostEnabled;

  @override
  Widget build(BuildContext context) {
    return SoriGlassActionDock(
      likeCount: likeCount,
      commentCount: commentCount,
      liked: liked,
      bookmarked: bookmarked,
      onLike: onLike,
      onComment: onComment,
      onBookmark: onBookmark,
      onMentoring: onMentoring,
      onBoost: onBoost,
      onMentoringLongPress: onMentoringLongPress,
      onBoostLongPress: onBoostLongPress,
      mentoringActive: mentoringActive,
      isBoosted: isBoosted,
      compact: compact,
      loading: loading,
      likeEnabled: likeEnabled,
      commentEnabled: commentEnabled,
      bookmarkEnabled: bookmarkEnabled,
      mentoringEnabled: mentoringEnabled,
      boostEnabled: boostEnabled,
    );
  }
}
