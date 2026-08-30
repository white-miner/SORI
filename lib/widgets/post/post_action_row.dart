import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// Unified bottom action row — like · comment · mentoring · boost (+ bookmark).
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
    this.mentoringActive = false,
    this.isBoosted = false,
    this.compact = false,
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
  final bool compact;

  static const double _groupGap = 12;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 19.0 : 22.0;
    final countStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: compact ? 11.5 : 12.5,
      color: SoriTokens.textPrimary,
    );
    final verticalPad = compact ? 8.0 : 10.0;
    final bottomPad = compact ? 10.0 : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 12,
        verticalPad,
        compact ? 8 : 12,
        bottomPad,
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
                  _ActionIcon(
                    icon: liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? SoriTokens.systemRed : SoriTokens.textTertiary,
                    size: iconSize,
                    onTap: onLike,
                    compact: compact,
                  ),
                  Text('$likeCount', style: countStyle),
                  const SizedBox(width: _groupGap),
                  _ActionIcon(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: SoriTokens.textTertiary,
                    size: iconSize,
                    onTap: onComment,
                    compact: compact,
                  ),
                  Text(
                    '$commentCount',
                    style: countStyle.copyWith(color: SoriTokens.textSecondary),
                  ),
                  const SizedBox(width: _groupGap),
                  _ActionIcon(
                    icon: mentoringActive ? Icons.star : Icons.star_border,
                    color: mentoringActive
                        ? SoriTokens.warningText
                        : SoriTokens.textTertiary,
                    size: iconSize,
                    onTap: onMentoring,
                    compact: compact,
                  ),
                  const SizedBox(width: _groupGap),
                  _ActionIcon(
                    icon: Icons.local_fire_department,
                    color: isBoosted
                        ? SoriTokens.warningText
                        : SoriTokens.textTertiary,
                    size: iconSize,
                    onTap: onBoost,
                    compact: compact,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: _groupGap),
          _ActionIcon(
            icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: bookmarked ? SoriTokens.textPrimary : SoriTokens.textTertiary,
            size: iconSize + 1,
            onTap: onBookmark,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.all(compact ? 4 : 6),
      constraints: BoxConstraints(
        minWidth: compact ? 30 : 34,
        minHeight: compact ? 30 : 34,
      ),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: size, color: color),
    );
  }
}
