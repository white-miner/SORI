import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/community_trust_header.dart';
import '../widgets/sori_network_image.dart';

/// 리뷰 브릿지 이후 — 특정 기기명의 중고/판매 리스트.
class DeviceMarketListingsPage extends StatelessWidget {
  const DeviceMarketListingsPage({
    super.key,
    required this.store,
    required this.deviceName,
  });

  final SoriStore store;
  final String deviceName;

  static Future<void> open(
    BuildContext context, {
    required SoriStore store,
    required String deviceName,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => DeviceMarketListingsPage(
          store: store,
          deviceName: deviceName,
        ),
      ),
    );
  }

  static bool matchesDevice(CommunityPost post, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    final names = <String>[
      post.deviceReview?.deviceName ?? '',
      post.listing?.deviceName ?? '',
      post.title,
    ];
    for (final n in names) {
      final t = n.trim().toLowerCase();
      if (t.isEmpty) continue;
      if (t.contains(q) || q.contains(t)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final listings = store.communityPosts
        .where(
          (p) =>
              p.listing != null &&
              p.listing!.status != MarketListingStatus.removed &&
              p.listing!.status != MarketListingStatus.hidden &&
              matchesDevice(p, deviceName),
        )
        .toList();

    // Prefer active/reserved first.
    listings.sort((a, b) {
      final sa = a.listing!.status;
      final sb = b.listing!.status;
      int rank(MarketListingStatus s) => switch (s) {
            MarketListingStatus.active => 0,
            MarketListingStatus.reserved => 1,
            MarketListingStatus.sold => 2,
            _ => 3,
          };
      return rank(sa).compareTo(rank(sb));
    });

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        backgroundColor: SoriTokens.background,
        title: Text(
          '$deviceName · 거래',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: listings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 44,
                      color: SoriTokens.textSecondary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '아직 $deviceName 매물이 없어요',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '다른 원장님의 실사용 후기를 더 읽어보거나\n나중에 다시 확인해 보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              itemCount: listings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ListingDealCard(post: listings[i]),
            ),
    );
  }
}

class _ListingDealCard extends StatelessWidget {
  const _ListingDealCard({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final listing = post.listing!;
    final sold = listing.status == MarketListingStatus.sold;
    final phone = listing.contactPhone?.trim() ?? '';
    final img = post.primaryImageUrl;

    return Opacity(
      opacity: sold ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SoriTokens.outlinePurple),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: CommunityTrustHeader(post: post),
            ),
            if (img != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: SoriNetworkImage(url: img, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _DealStatusChip(status: listing.status),
                      const Spacer(),
                      if (listing.price > 0)
                        Text(
                          '${_formatWon(listing.price)}원',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: SoriTokens.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.deviceName.trim().isEmpty
                        ? deviceFallback(post)
                        : listing.deviceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _conditionLabel(listing.condition),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!sold) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (phone.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  launchUrl(Uri.parse('tel:$phone')),
                              icon: const Icon(Icons.phone_outlined, size: 18),
                              label: const Text('연락'),
                            ),
                          ),
                        if (phone.isNotEmpty) const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '구매 요청이 판매자에게 전달됩니다',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                            ),
                            label: const Text('채팅 / 구매 요청'),
                            style: FilledButton.styleFrom(
                              backgroundColor: SoriTokens.primary,
                            ),
                          ),
                        ),
                      ],
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

  static String deviceFallback(CommunityPost post) {
    final t = post.title.trim();
    return t.isEmpty ? '매물' : t;
  }

  static String _conditionLabel(String c) => switch (c) {
        'new' => '새제품',
        'like_new' => '거의 새것',
        'fair' => '사용감 있음',
        _ => '양호',
      };

  static String _formatWon(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rev = s.length - i;
      buf.write(s[i]);
      if (rev > 1 && rev % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}

class _DealStatusChip extends StatelessWidget {
  const _DealStatusChip({required this.status});
  final MarketListingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MarketListingStatus.active => SoriTokens.primary,
      MarketListingStatus.reserved => SoriTokens.warningText,
      MarketListingStatus.sold => SoriTokens.textSecondary,
      _ => SoriTokens.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
