import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/session_user.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/community_comments_section.dart';
import '../widgets/community_motivation.dart';
import '../widgets/community_seminar_bridge.dart';
import '../widgets/community_trust_header.dart';
import '../widgets/sori_network_image.dart';
import 'device_market_listings_page.dart';

/// 기기 실사용 리뷰 상세 — 스토리 先, 거래 브릿지는 Sticky CTA.
class DeviceReviewDetailPage extends StatelessWidget {
  const DeviceReviewDetailPage({
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
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => DeviceReviewDetailPage(store: store, post: post),
      ),
    );
  }

  String get _deviceName {
    final r = post.deviceReview?.deviceName.trim() ?? '';
    if (r.isNotEmpty) return r;
    final l = post.listing?.deviceName.trim() ?? '';
    if (l.isNotEmpty) return l;
    final t = post.title.trim();
    return t.isEmpty ? '이 기기' : t;
  }

  bool get _unlocked {
    final isAuthor =
        post.shopId.isNotEmpty && post.shopId == store.shop.id;
    final isDirector = store.session?.activeMode == UserRole.director;
    return post.visibility.canView(
      viewerTier: store.shop.tierBadge,
      isAuthor: isAuthor,
      isDirector: isDirector,
    );
  }

  @override
  Widget build(BuildContext context) {
    final review = post.deviceReview;
    final img = post.primaryImageUrl;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final unlocked = _unlocked;

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        backgroundColor: SoriTokens.background,
        title: Text(
          _deviceName,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                CommunityTrustHeader(
                  post: post,
                  animateBadge:
                      post.tierBadge.rank >= 4, // gold+
                ),
                CommunitySeminarBridge(store: store, shopId: post.shopId),
                const SizedBox(height: 8),
                if (img != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: SoriNetworkImage(url: img, fit: BoxFit.cover),
                    ),
                  ),
                const SizedBox(height: 20),
                if (!unlocked)
                  CommunityLockedBody(
                    previewText: post.body.trim(),
                    onUnlockCta: () => Navigator.pop(context),
                  )
                else ...[
                  if (review?.rating != null) ...[
                    Row(
                      children: [
                        _DetailStars(rating: review!.rating!),
                        const SizedBox(width: 10),
                        Text(
                          review.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (review != null && review.usageMonths > 0)
                    Text(
                      '${review.usageMonths}개월 실사용 후기',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  if (post.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      post.body.trim(),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.75,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE4E4E7),
                      ),
                    ),
                  ],
                  if (review != null && review.pros.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const Text(
                      '장점',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...review.pros.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('·  ', style: TextStyle(height: 1.5)),
                            Expanded(
                              child: Text(
                                p,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.55,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (review != null && review.cons.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      '단점',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF87171),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...review.cons.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('·  ', style: TextStyle(height: 1.5)),
                            Expanded(
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.55,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (review?.brand.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 20),
                    Text(
                      '브랜드 · ${review!.brand}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                CommunityCommentsSection(store: store, postId: post.id),
                const SizedBox(height: 80),
              ],
            ),
          ),
          if (unlocked)
            Material(
              color: SoriTokens.surface,
              elevation: 12,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => DeviceMarketListingsPage.open(
                      context,
                      store: store,
                      deviceName: _deviceName,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      '$_deviceName 중고/신제품 알아보기',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailStars extends StatelessWidget {
  const _DetailStars({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final full = rating.round().clamp(1, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= full ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 22,
            color: const Color(0xFFFBBF24),
          ),
      ],
    );
  }
}
