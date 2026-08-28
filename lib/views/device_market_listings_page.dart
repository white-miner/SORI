import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_post.dart';
import '../models/market_listing_trust.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/community_trust_header.dart';
import '../widgets/sori_network_image.dart';

/// E3 — 신뢰순 중고 거래 리스트.
class DeviceMarketListingsPage extends StatefulWidget {
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
  State<DeviceMarketListingsPage> createState() =>
      _DeviceMarketListingsPageState();
}

class _DeviceMarketListingsPageState extends State<DeviceMarketListingsPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await widget.store.refreshMarketListingsScored(
      deviceName: widget.deviceName,
      limit: 80,
    );
    if (mounted) setState(() => _loading = false);
  }

  List<CommunityPost> get _posts {
    final scored = {
      for (final r in widget.store.marketListingsScored) r.postId: r
    };
    final posts = widget.store.communityPosts.where((p) {
      if (p.listing == null) return false;
      if (scored.containsKey(p.id)) return true;
      return DeviceMarketListingsPage.matchesDevice(p, widget.deviceName);
    }).toList();

    posts.sort((a, b) {
      final sa = scored[a.id]?.sellerTrustScore ??
          a.listing?.sellerTrustScore ??
          0;
      final sb = scored[b.id]?.sellerTrustScore ??
          b.listing?.sellerTrustScore ??
          0;
      if (sa != sb) return sb.compareTo(sa);
      return (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0));
    });
    return posts;
  }

  @override
  Widget build(BuildContext context) {
    final listings = _posts;
    final scoredByPost = {
      for (final r in widget.store.marketListingsScored) r.postId: r
    };

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        backgroundColor: SoriTokens.background,
        title: Text(
          '${widget.deviceName} · 거래',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: SoriTokens.primary),
            )
          : listings.isEmpty
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
                          '아직 ${widget.deviceName} 매물이 없어요',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    itemCount: listings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ListingDealCard(
                      store: widget.store,
                      post: listings[i],
                      scored: scoredByPost[listings[i].id],
                    ),
                  ),
                ),
    );
  }
}

class _ListingDealCard extends StatelessWidget {
  const _ListingDealCard({
    required this.store,
    required this.post,
    this.scored,
  });

  final SoriStore store;
  final CommunityPost post;
  final MarketListingScoredRow? scored;

  Future<void> _inquiry(BuildContext context) async {
    final listing = post.listing!;
    try {
      final ok = await store.submitMarketListingInquiry(
        listingId: listing.id,
        message: '${listing.deviceName} 구매 문의드립니다.',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? '문의가 판매자에게 전달됐어요.' : '문의 전송에 실패했어요.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('문의 전송에 실패했어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = post.listing!;
    final sold = listing.status == MarketListingStatus.sold;
    final phone = listing.contactPhone?.trim() ?? '';
    final img = post.primaryImageUrl;
    final trustScore =
        scored?.sellerTrustScore ?? listing.sellerTrustScore;
    final trustLabel =
        scored?.sellerTrustLabel ?? listing.sellerTrustLabel;
    final escrowHeld = scored?.hasEscrowHeld ?? listing.escrowHeld;
    final isOwner =
        store.shop.id.isNotEmpty && listing.shopId == store.shop.id;

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
              child: CommunityTrustHeader(
                post: post,
                trailing: _TrustChip(score: trustScore, label: trustLabel),
              ),
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
                      if (escrowHeld) ...[
                        const SizedBox(width: 6),
                        const _EscrowChip(),
                      ],
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
                            onPressed: () => _inquiry(context),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                            ),
                            label: const Text('구매 문의'),
                          ),
                        ),
                      ],
                    ),
                    if (isOwner && listing.status == MarketListingStatus.active)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton(
                          onPressed: () async {
                            await store.holdMarketEscrowForListing(listing.id);
                          },
                          child: const Text('에스크로 보류 시작'),
                        ),
                      ),
                    if (isOwner &&
                        (escrowHeld ||
                            listing.status == MarketListingStatus.reserved))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await store
                                      .refundMarketEscrowForListing(listing.id);
                                },
                                child: const Text('환불'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  await store.completeMarketEscrowForListing(
                                    listing.id,
                                  );
                                },
                                child: const Text('거래 완료'),
                              ),
                            ),
                          ],
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

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.score, required this.label});

  final int score;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SoriTokens.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$score · $label',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: SoriTokens.primary,
        ),
      ),
    );
  }
}

class _EscrowChip extends StatelessWidget {
  const _EscrowChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SoriTokens.warningText.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        '에스크로',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: SoriTokens.warningText,
        ),
      ),
    );
  }
}

String deviceFallback(CommunityPost post) =>
    post.title.trim().isEmpty ? '기기 매물' : post.title.trim();

String _formatWon(int price) {
  final s = price.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _conditionLabel(String condition) => switch (condition) {
      'new' => '새 제품급',
      'like_new' => '거의 새것',
      'good' => '양호',
      'fair' => '사용감 있음',
      _ => '상태 양호',
    };

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
