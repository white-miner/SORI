import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import '../widgets/community_comments_section.dart';
import '../widgets/community_hotspot_image.dart';
import '../widgets/community_motivation.dart';

/// 탐색에서 연 커뮤니티 포스트 원본 (인테리어·케이스 공유 등).
class ExploreCommunityPostPage extends StatelessWidget {
  const ExploreCommunityPostPage({
    super.key,
    required this.store,
    required this.post,
  });

  final SoriStore store;
  final CommunityPost post;

  static Future<void> open(
    BuildContext context, {
    required SoriStore store,
    required CommunityPost post,
  }) {
    return pushRootPage<void>(
      context,
      ExploreCommunityPostPage(store: store, post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = post.media;
    final primary = media.isNotEmpty ? media.first : null;
    final tags = primary == null
        ? const <CommunityPostTag>[]
        : post.tagsForMedia(primary.id);
    final title = post.title.trim();
    final body = post.body.trim();

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: Text(post.postType.label),
        backgroundColor: SoriTokens.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        children: [
          CommunityPostShell(
            store: store,
            post: post,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                            height: 1.35,
                          ),
                        ),
                      if (body.isNotEmpty) ...[
                        SizedBox(height: title.isEmpty ? 0 : 12),
                        Text(
                          body,
                          style: const TextStyle(
                            fontSize: 15.5,
                            height: 1.72,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFD4D4D8),
                          ),
                        ),
                      ],
                      if (post.styleTags.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: post.styleTags
                              .take(6)
                              .map(
                                (t) => Text(
                                  t.startsWith('#') ? t : '#$t',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: SoriTokens.primary
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                if (media.length <= 1)
                  CommunityHotspotImage(
                    imageUrl: primary?.imageUrl ?? post.primaryImageUrl,
                    tags: tags,
                    aspectRatio: 4 / 3,
                    store: store,
                    ownerShopId: post.shopId,
                    postId: post.id,
                  )
                else
                  SizedBox(
                    height: 280,
                    child: PageView.builder(
                      itemCount: media.length,
                      itemBuilder: (context, i) {
                        final m = media[i];
                        return CommunityHotspotImage(
                          imageUrl: m.imageUrl,
                          tags: post.tagsForMedia(m.id),
                          aspectRatio: 1,
                          store: store,
                          ownerShopId: post.shopId,
                          postId: post.id,
                        );
                      },
                    ),
                  ),
                CommunityCommentsSection(store: store, postId: post.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
