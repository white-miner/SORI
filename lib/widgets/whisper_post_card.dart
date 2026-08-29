import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'author_content_actions_sheet.dart';
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

  bool get _isAuthor {
    final sid = store.shop.id.trim();
    if (sid.isNotEmpty && post.shopId.trim() == sid) return true;
    final uid = store.session?.id.trim() ?? '';
    return uid.isNotEmpty && post.authorUserId?.trim() == uid;
  }

  Future<void> _openAuthorMenu(BuildContext context) async {
    final action = await showAuthorContentActionsSheet(
      context,
      showDraft: false,
      showEdit: false,
      showDelete: true,
    );
    if (!context.mounted) return;
    if (action != AuthorContentAction.delete) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Whisper 삭제'),
        content: const Text('이 Whisper 게시물을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: SoriTokens.systemRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await store.removeCommunityPost(post.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Whisper를 삭제했습니다.' : '삭제에 실패했습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                        'Whisper',
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
                if (_isAuthor)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: '관리',
                    onPressed: () => _openAuthorMenu(context),
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
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
                      'This Whisper is visible to selected recipients only.',
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
