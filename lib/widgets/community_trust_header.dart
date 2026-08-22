import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../theme/sori_tokens.dart';
import 'shop_tier_badge_chip.dart';

/// Community 카드 상단 — 원장 이름 + 티어 + 사업자 인증.
class CommunityTrustHeader extends StatelessWidget {
  const CommunityTrustHeader({
    super.key,
    required this.post,
    this.trailing,
    this.animateBadge = false,
  });

  final CommunityPost post;
  final Widget? trailing;
  final bool animateBadge;

  @override
  Widget build(BuildContext context) {
    final avatar = post.shopAvatarUrl?.trim();
    final name = post.authorDisplayName;
    final shop = post.shopName.trim();
    final hasAvatar = avatar != null &&
        (avatar.startsWith('http') || avatar.startsWith('data:'));

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: SoriTokens.primarySoft,
          backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
          child: hasAvatar
              ? null
              : Text(
                  name.isEmpty ? '?' : name.characters.first,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: SoriTokens.primary,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (post.businessVerified) ...[
                    const SizedBox(width: 6),
                    const _BusinessVerifiedMark(),
                  ],
                ],
              ),
              if (shop.isNotEmpty && shop != name)
                Text(
                  shop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        if (post.tierBadge.isVisible) ...[
          const SizedBox(width: 6),
          ShopTierBadgeChip(
            badge: post.tierBadge,
            compact: true,
            animateGlow: animateBadge,
          ),
        ],
        if (trailing != null) ...[
          const SizedBox(width: 2),
          trailing!,
        ],
      ],
    );
  }
}

class _BusinessVerifiedMark extends StatelessWidget {
  const _BusinessVerifiedMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: const Color(0xFF0EA5E9).withValues(alpha: 0.45),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: Color(0xFF38BDF8)),
          SizedBox(width: 3),
          Text(
            '사업자 인증',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7DD3FC),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
