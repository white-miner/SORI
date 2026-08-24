import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// Community 허브 — 팔로잉 탭 (KeepAlive).
class CommunityFollowingPane extends StatefulWidget {
  const CommunityFollowingPane({
    super.key,
    required this.store,
    required this.onOpenDiscover,
  });

  final SoriStore store;
  final VoidCallback onOpenDiscover;

  @override
  State<CommunityFollowingPane> createState() => _CommunityFollowingPaneState();
}

class _CommunityFollowingPaneState extends State<CommunityFollowingPane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshFollowingFeed(soft: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final emptySubs = store.subscriptionCount == 0;
    final posts = store.followingFeedPosts;
    final loading = store.followingFeedLoading && posts.isEmpty;

    if (emptySubs) {
      return _FollowingEmpty(onDiscover: widget.onOpenDiscover);
    }

    if (loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    if (posts.isEmpty) {
      return RefreshIndicator(
        color: SoriTokens.primary,
        onRefresh: () => store.refreshFollowingFeed(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
          children: [
            const Text(
              '팔로우한 원장님의 새 글이 아직 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '홈 탐색에서 더 많은 원장님을 팔로우해 보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: SoriTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: FilledButton(
                onPressed: widget.onOpenDiscover,
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  '홈 탐색으로 이동',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: SoriTokens.primary,
      onRefresh: () => store.refreshFollowingFeed(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _FollowingPostTile(post: posts[i]),
      ),
    );
  }
}

class _FollowingEmpty extends StatelessWidget {
  const _FollowingEmpty({required this.onDiscover});
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 120),
      child: Column(
        children: [
          const Icon(
            Icons.favorite_border_rounded,
            size: 40,
            color: SoriTokens.textTertiary,
          ),
          const SizedBox(height: 18),
          const Text(
            '마음에 드는 원장님을 찾아보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '팔로우하면 그 원장님의 새 소식이 이 탭에 모입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDiscover,
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '홈 탐색에서 원장 찾기',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowingPostTile extends StatelessWidget {
  const _FollowingPostTile({required this.post});
  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final cover = post.media.isNotEmpty ? post.media.first.imageUrl : '';
    return DecoratedBox(
      decoration: SoriTokens.card(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  cover,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 72,
                    height: 72,
                    color: SoriTokens.surfaceOverlay,
                  ),
                ),
              )
            else
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: SoriTokens.surfaceOverlay,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.article_outlined,
                  color: SoriTokens.textTertiary,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title.trim().isEmpty ? post.postType.label : post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.shopName.isNotEmpty ? post.shopName : 'Community',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: SoriTokens.textTertiary,
                    ),
                  ),
                  if (post.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.body.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
