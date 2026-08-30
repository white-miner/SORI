import 'package:flutter/material.dart';

import '../models/unified_feed_item.dart';
import '../services/sori_store.dart';
import 'post/post_view_data.dart';
import 'post/sori_post_mini.dart';

/// @deprecated Use [SoriPostMini] directly.
class SoriMiniPostCard extends StatelessWidget {
  const SoriMiniPostCard({
    super.key,
    required this.item,
    required this.store,
    this.onMore,
    this.horizontal = false,
    this.width,
  });

  final UnifiedFeedItem item;
  final SoriStore store;
  final VoidCallback? onMore;
  final bool horizontal;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SoriPostMini(
      data: PostViewData.fromUnifiedFeedItem(item),
      store: store,
      horizontal: horizontal,
      width: width,
    );
  }
}
