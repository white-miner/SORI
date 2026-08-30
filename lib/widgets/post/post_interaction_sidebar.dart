import 'package:flutter/material.dart';

import '../../theme/sori_date_picker.dart';
import '../../services/sori_store.dart';
import '../community_comments_section.dart';
import 'post_view_data.dart';

/// Desktop sticky sidebar — "댓글" title + threads only.
/// Author [PostHeader] belongs on the left post column (PO image_35).
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
  /// Kept for API compatibility; mentoring CTA lives on left action dock.
  final VoidCallback? onMentoring;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: SoriGlassPanel(
        borderRadius: 20,
        child: SizedBox.expand(
          child: CommunityCommentsSection(
            store: store,
            postId: postId,
            embeddedInSidebar: true,
          ),
        ),
      ),
    );
  }
}
