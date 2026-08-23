import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../views/device_market_listings_page.dart';
import 'community_seminar_bridge.dart';

/// 피드 카드 하단 표준 수익화 CTA — 세미나 / 매물 / 제휴.
class CommunityMonetizationCtaBar extends StatelessWidget {
  const CommunityMonetizationCtaBar({
    super.key,
    required this.store,
    required this.post,
    this.affiliateUrl,
    this.affiliateLabel = '',
  });

  final SoriStore store;
  final CommunityPost post;
  final String? affiliateUrl;
  final String affiliateLabel;

  bool get _showSeminar =>
      post.postType == CommunityPostType.caseShare ||
      post.postType == CommunityPostType.seminar ||
      post.postType == CommunityPostType.interior ||
      post.postType == CommunityPostType.deviceReview;

  bool get _showMarket {
    if (post.postType == CommunityPostType.deviceReview ||
        post.postType == CommunityPostType.marketplace) {
      return true;
    }
    final name = post.deviceReview?.deviceName.trim() ?? '';
    return name.isNotEmpty;
  }

  String? get _resolvedAffiliate {
    final explicit = affiliateUrl?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    for (final t in post.tags) {
      final u = t.externalUrl?.trim() ?? '';
      if (u.startsWith('http')) return u;
    }
    return null;
  }

  String get _deviceQuery {
    final n = post.deviceReview?.deviceName.trim() ?? '';
    if (n.isNotEmpty) return n;
    final title = post.title.trim();
    return title.isEmpty ? '기기' : title;
  }

  @override
  Widget build(BuildContext context) {
    final aff = _resolvedAffiliate;
    final showAff = aff != null && aff.isNotEmpty;
    if (!_showSeminar && !_showMarket && !showAff) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showSeminar)
            CommunitySeminarBridge(
              store: store,
              shopId: post.shopId,
              compactLabel: '세미나 신청',
            ),
          if (_showMarket) ...[
            const SizedBox(height: 6),
            _CtaButton(
              icon: Icons.shopping_bag_outlined,
              label: '기기 매물 보기',
              onTap: () => DeviceMarketListingsPage.open(
                context,
                store: store,
                deviceName: _deviceQuery,
              ),
            ),
          ],
          if (showAff) ...[
            const SizedBox(height: 6),
            _CtaButton(
              icon: Icons.link_rounded,
              label: affiliateLabel.trim().isEmpty
                  ? '제휴 링크'
                  : affiliateLabel.trim(),
              onTap: () {
                store.openAffiliateExternalUrl(
                  url: aff,
                  ownerShopId: post.shopId,
                  label: affiliateLabel,
                  postId: post.id,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC4B5FD),
        side: BorderSide(color: SoriTokens.primary.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
