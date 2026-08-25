import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'community_comments_section.dart';

/// 피드 내 속삭임(Whisper) 포스트 — 수신자에게만 본문 노출, 시각적 차별화.
class WhisperPostCard extends StatelessWidget {
  const WhisperPostCard({
    super.key,
    required this.post,
    required this.store,
    this.compact = false,
    this.onTap,
  });

  final CommunityPost post;
  final SoriStore store;

  /// 3열 대시보드용 — 패딩·본문 줄 수 축소.
  final bool compact;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = post.isBodyLocked;
    final body = post.body.trim();

    final radius = compact ? 14.0 : 16.0;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: SoriTokens.primary.withValues(alpha: 0.45),
          width: compact ? 1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: SoriTokens.primary.withValues(alpha: 0.08),
            blurRadius: compact ? 8 : 12,
            offset: Offset(0, compact ? 2 : 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 14,
          compact ? 10 : 12,
          compact ? 10 : 14,
          compact ? 10 : 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SoriTokens.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: SoriTokens.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '속삭임',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: SoriTokens.primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (post.whisperRecipientCount > 0)
                  Text(
                    '${post.whisperRecipientCount}명에게',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SoriTokens.textTertiary.withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: compact ? 13 : 16,
                  backgroundColor: SoriTokens.primary.withValues(alpha: 0.2),
                  backgroundImage: post.shopAvatarUrl != null &&
                          post.shopAvatarUrl!.trim().isNotEmpty
                      ? NetworkImage(post.shopAvatarUrl!)
                      : null,
                  child: post.shopAvatarUrl == null ||
                          post.shopAvatarUrl!.trim().isEmpty
                      ? Text(
                          post.authorDisplayName.characters.first,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (post.shopName.trim().isNotEmpty)
                        Text(
                          post.shopName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: SoriTokens.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            if (locked)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 16,
                    color: SoriTokens.textTertiary.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '이 속삭임은 지정된 수신자만 볼 수 있어요.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: SoriTokens.textSecondary.withValues(alpha: 0.9),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                body,
                maxLines: compact ? 5 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: TextStyle(
                  fontSize: compact ? 13 : 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (!compact && !locked && post.commentCount > 0) ...[
              const SizedBox(height: 12),
              CommunityCommentsSection(
                store: store,
                postId: post.id,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}
