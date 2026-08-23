import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/session_user.dart';
import '../models/shop_tier_badge.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/community_comments_section.dart';
import '../widgets/community_motivation.dart';
import '../widgets/community_seminar_bridge.dart';
import '../widgets/community_trust_header.dart';
import '../widgets/sori_network_image.dart';
import 'device_market_listings_page.dart';

/// 기기 실사용 리뷰 상세 — 스토리 先, 거래 브릿지는 Sticky CTA.
class DeviceReviewDetailPage extends StatefulWidget {
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

  @override
  State<DeviceReviewDetailPage> createState() => _DeviceReviewDetailPageState();
}

class _DeviceReviewDetailPageState extends State<DeviceReviewDetailPage> {
  late CommunityPost _post;
  bool _unlocking = false;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    store.refreshPointWallet();
  }

  String get _deviceName {
    final r = _post.deviceReview?.deviceName.trim() ?? '';
    if (r.isNotEmpty) return r;
    final l = _post.listing?.deviceName.trim() ?? '';
    if (l.isNotEmpty) return l;
    final t = _post.title.trim();
    return t.isEmpty ? '이 기기' : t;
  }

  bool get _unlocked {
    if (_post.isBodyLocked) return false;
    final isAuthor =
        _post.shopId.isNotEmpty && _post.shopId == store.shop.id;
    final isDirector = store.session?.activeMode == UserRole.director;
    return _post.visibility.canView(
      viewerTier: store.shop.tierBadge,
      isAuthor: isAuthor,
      isDirector: isDirector,
    );
  }

  Future<void> _unlockWithPoints() async {
    if (_unlocking) return;
    setState(() => _unlocking = true);
    try {
      final updated = await store.unlockCommunityPostWithPoints(
        _post,
        cost: _post.unlockCost,
      );
      if (!mounted) return;
      if (updated != null) {
        setState(() => _post = updated);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('insufficient')
                ? '포인트가 부족합니다. 충전소에서 충전하세요.'
                : '열람 실패',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _post.deviceReview;
    final img = _post.primaryImageUrl;
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
                  post: _post,
                  animateBadge:
                      _post.tierBadge.rank >= ShopTierBadge.gold.rank,
                ),
                CommunitySeminarBridge(store: store, shopId: _post.shopId),
                const SizedBox(height: 8),
                if (img != null && unlocked)
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
                    previewText: _post.body.trim().isEmpty
                        ? _post.title
                        : _post.body.trim(),
                    unlockCost: _post.unlockCost,
                    walletBalance: store.pointWallet.totalBalance,
                    unlocking: _unlocking,
                    onUnlockWithPoints: _unlockWithPoints,
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
                    const SizedBox(height: 16),
                  ],
                  Text(
                    _post.body.trim().isEmpty ? _post.title : _post.body,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.7,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFD4D4D8),
                    ),
                  ),
                  if (review != null &&
                      (review.pros.isNotEmpty || review.cons.isNotEmpty)) ...[
                    const SizedBox(height: 20),
                    if (review.pros.isNotEmpty)
                      _ProsCons(
                        label: '장점',
                        lines: review.pros,
                        color: const Color(0xFF4ADE80),
                      ),
                    if (review.cons.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ProsCons(
                        label: '단점',
                        lines: review.cons,
                        color: const Color(0xFFF87171),
                      ),
                    ],
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
                if (unlocked)
                  CommunityCommentsSection(store: store, postId: _post.id),
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
                    onPressed: () {
                      final isDirector =
                          store.session?.activeMode == UserRole.director;
                      if (!isDirector) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '중고·신상 거래는 원장 전용입니다',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      DeviceMarketListingsPage.open(
                        context,
                        store: store,
                        deviceName: _deviceName,
                      );
                    },
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        final half = !filled && rating > i && rating < i + 1;
        return Icon(
          half
              ? Icons.star_half_rounded
              : filled
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
          size: 22,
          color: const Color(0xFFFBBF24),
        );
      }),
    );
  }
}

class _ProsCons extends StatelessWidget {
  const _ProsCons({
    required this.label,
    required this.lines,
    required this.color,
  });

  final String label;
  final List<String> lines;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        ...lines.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '· $l',
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
