import 'package:flutter/material.dart';

import 'sori_glass_chip.dart';
import 'sori_glass_tokens.dart';

/// GIS feed action dock — replaces flat [PostActionRow].
class SoriGlassActionDock extends StatelessWidget {
  const SoriGlassActionDock({
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
    final chipSize = compact ? SoriGlassTokens.chipSm : SoriGlassTokens.chipMd;
    final trayRadius = compact ? 16.0 : 20.0;
    final verticalPad = compact ? 8.0 : 10.0;
    final bottomPad = compact ? 10.0 : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 12,
        verticalPad,
        compact ? 8 : 12,
        bottomPad,
      ),
      child: DecoratedBox(
        decoration: SoriGlassTokens.dockTrayDecoration(radius: trayRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SoriGlassTokens.dockPadH,
            vertical: SoriGlassTokens.dockPadV,
          ),
          child: Row(
            children: [
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SoriGlassMetricChip(
                        icon: liked ? Icons.favorite : Icons.favorite_border,
                        semantic: SoriGlassSemantic.like,
                        count: likeCount,
                        active: liked,
                        enabled: likeEnabled,
                        compact: compact,
                        onTap: loading ? null : onLike,
                      ),
                      const SizedBox(width: SoriGlassTokens.dockGap),
                      SoriGlassMetricChip(
                        icon: Icons.chat_bubble_outline_rounded,
                        semantic: SoriGlassSemantic.comment,
                        count: commentCount,
                        enabled: commentEnabled,
                        compact: compact,
                        onTap: loading ? null : onComment,
                      ),
                      const SizedBox(width: SoriGlassTokens.dockGap),
                      SoriGlassChip(
                        icon: mentoringActive ? Icons.star : Icons.star_border,
                        semantic: SoriGlassSemantic.mentoring,
                        active: mentoringActive,
                        enabled: mentoringEnabled,
                        size: chipSize,
                        loading: loading,
                        tooltip: '멘토링',
                        onTap: loading ? null : onMentoring,
                        onLongPress: onMentoringLongPress ?? onMentoring,
                      ),
                      const SizedBox(width: SoriGlassTokens.dockGap),
                      SoriGlassChip(
                        icon: Icons.local_fire_department,
                        semantic: SoriGlassSemantic.boost,
                        active: isBoosted,
                        enabled: boostEnabled,
                        size: chipSize,
                        loading: loading,
                        tooltip: '부스트',
                        onTap: loading ? null : onBoost,
                        onLongPress: onBoostLongPress ?? onBoost,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: SoriGlassTokens.dockGap),
              SoriGlassChip(
                icon: bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                semantic: SoriGlassSemantic.bookmark,
                active: bookmarked,
                enabled: bookmarkEnabled,
                size: chipSize,
                loading: loading,
                tooltip: '저장',
                onTap: loading ? null : onBookmark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
