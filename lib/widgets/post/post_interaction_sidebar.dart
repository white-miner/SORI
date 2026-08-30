import 'package:flutter/material.dart';

import '../../theme/sori_date_picker.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../community_comments_section.dart';
import 'post_header.dart';
import 'post_view_data.dart';

/// Desktop sticky sidebar — glass panel with author, mentoring, DB comments.
class PostInteractionSidebar extends StatelessWidget {
  const PostInteractionSidebar({
    super.key,
    required this.data,
    required this.store,
    required this.postId,
    this.onMentoring,
  });

  final PostViewData data;
  final SoriStore store;
  final String postId;
  final VoidCallback? onMentoring;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: SoriGlassPanel(
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PostHeader(data: data, dense: true),
            if (data.hasActiveMentoring && onMentoring != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: FilledButton.icon(
                  onPressed: onMentoring,
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.people_alt_outlined, size: 18),
                  label: const Text(
                    '멘토링 요청',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            Divider(
              height: 1,
              color: SoriTokens.outlinePurple.withValues(alpha: 0.35),
            ),
            Expanded(
              child: CommunityCommentsSection(
                store: store,
                postId: postId,
                embeddedInSidebar: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
