import 'package:flutter/material.dart';

import '../../models/post_engagement_bindings.dart';
import '../../models/unified_feed_item.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/post_navigation.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../widgets/post/post_engagement_action_row.dart';
import '../../widgets/post/post_view_data.dart';
import '../../widgets/sori_network_image.dart';

/// Full-viewport Story Rail card — Social Glass (Phase 3).
class StoryRailCard extends StatelessWidget {
  const StoryRailCard({
    super.key,
    required this.item,
    required this.store,
    required this.bindings,
    this.onOpenDetail,
  });

  final UnifiedFeedItem item;
  final SoriStore store;
  final PostEngagementBindings bindings;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final data = PostViewData.fromUnifiedFeedItem(item);
    final imageUrl = data.thumbnailUrl?.trim() ?? '';
    final hasImage = imageUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VisitGlassTokens.radiusXl),
        child: DecoratedBox(
          decoration: VisitGlassTokens.cardDecoration(
            socialGlow: true,
            radius: VisitGlassTokens.radiusXl,
          ),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  SoriNetworkImage(
                    url: imageUrl,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    color: VisitGlassTokens.careSoft,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      size: 48,
                      color: VisitGlassTokens.care.withValues(alpha: 0.6),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  top: 14,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white24,
                        backgroundImage: (data.avatarUrl?.trim().isNotEmpty ??
                                false)
                            ? NetworkImage(data.avatarUrl!.trim())
                            : null,
                        child: (data.avatarUrl?.trim().isEmpty ?? true)
                            ? Text(
                                data.authorName.characters.first,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
                              data.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              data.categoryLabel,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (data.isBoosted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: VisitGlassTokens.care.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Boost',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (data.bodyText.trim().isNotEmpty)
                        GestureDetector(
                          onTap: onOpenDetail ??
                              () => openUnifiedPostOriginal(
                                    context,
                                    item: item,
                                    store: store,
                                  ),
                          child: Text(
                            data.bodyText.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      PostEngagementActionRow(bindings: bindings),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical snap Story Rail — Recommend tab hero (Phase 3).
class StoryRailView extends StatefulWidget {
  const StoryRailView({
    super.key,
    required this.items,
    required this.store,
    required this.engagementBuilder,
  });

  final List<UnifiedFeedItem> items;
  final SoriStore store;
  final PostEngagementBindings Function(UnifiedFeedItem item) engagementBuilder;

  @override
  State<StoryRailView> createState() => _StoryRailViewState();
}

class _StoryRailViewState extends State<StoryRailView> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final height = MediaQuery.sizeOf(context).height * 0.52;
    final clampedHeight = height.clamp(360.0, 520.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Text(
                'Story Rail',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_index + 1}/${widget.items.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: clampedHeight,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return StoryRailCard(
                item: item,
                store: widget.store,
                bindings: widget.engagementBuilder(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
