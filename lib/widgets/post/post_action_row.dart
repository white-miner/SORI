import 'package:flutter/material.dart';

import '../../theme/sori_tokens.dart';

/// Unified bottom action row — no reservation/booking per PO retention rule.
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
    this.onMentoring,
    this.showMentoring = false,
    this.compact = false,
  });

  final int likeCount;
  final int commentCount;
  final bool liked;
  final bool bookmarked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback? onMentoring;
  final bool showMentoring;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 20.0 : 22.0;
    final countStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: compact ? 11.5 : 12.5,
      color: SoriTokens.textPrimary,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 2 : 4, 0, compact ? 2 : 4, 4),
      child: Row(
        children: [
          _ActionIcon(
            icon: liked ? Icons.favorite : Icons.favorite_border,
            color: liked ? SoriTokens.systemRed : SoriTokens.textTertiary,
            size: iconSize,
            onTap: onLike,
          ),
          Text('$likeCount', style: countStyle),
          _ActionIcon(
            icon: Icons.chat_bubble_outline_rounded,
            color: SoriTokens.textTertiary,
            size: iconSize,
            onTap: onComment,
          ),
          Text(
            '$commentCount',
            style: countStyle.copyWith(color: SoriTokens.textSecondary),
          ),
          if (showMentoring && onMentoring != null) ...[
            _ActionIcon(
              icon: Icons.people_alt_outlined,
              color: SoriTokens.primary,
              size: iconSize,
              onTap: onMentoring!,
            ),
            Icon(
              Icons.sync_rounded,
              size: compact ? 14 : 16,
              color: SoriTokens.primary.withValues(alpha: 0.8),
            ),
          ],
          const Spacer(),
          _ActionIcon(
            icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: bookmarked ? SoriTokens.textPrimary : SoriTokens.textTertiary,
            size: iconSize + 2,
            onTap: onBookmark,
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
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: size, color: color),
    );
  }
}
