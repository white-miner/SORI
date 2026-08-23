import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../models/session_user.dart';
import '../models/shop_tier_badge.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'community_monetization_cta_bar.dart';
import 'community_trust_header.dart';

/// 상위 티어 게시물 하이라이트 래퍼.
class CommunityAuthorityFrame extends StatelessWidget {
  const CommunityAuthorityFrame({
    super.key,
    required this.post,
    required this.child,
  });

  final CommunityPost post;
  final Widget child;

  bool get _isElite => post.tierBadge.rank >= ShopTierBadge.gold.rank;

  @override
  Widget build(BuildContext context) {
    final isMaster = post.tierBadge.rank >= ShopTierBadge.master.rank;
    final glow = isMaster
        ? const Color(0xFFA78BFA)
        : const Color(0xFFEAB308);

    if (!_isElite) {
      return Container(
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: SoriTokens.outlinePurple.withValues(alpha: 0.55),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glow.withValues(alpha: 0.14),
            SoriTokens.surface,
            glow.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: glow.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// 잠금 본문 Fallback — 블러 + CTA.
class CommunityLockedBody extends StatelessWidget {
  const CommunityLockedBody({
    super.key,
    required this.previewText,
    required this.onUnlockCta,
  });

  final String previewText;
  final VoidCallback onUnlockCta;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: Opacity(
              opacity: 0.55,
              child: Text(
                previewText.isEmpty
                    ? '동료 원장의 노하우와 실전 팁이 여기에 담겨 있습니다. '
                        '직접 경험을 나누면 잠금이 해제됩니다.'
                    : previewText,
                maxLines: 6,
                overflow: TextOverflow.fade,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.65,
                  color: Color(0xFFD4D4D8),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFFFDE68A),
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '골드 등급 이상 공개 콘텐츠',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '직접 리뷰를 1회 작성하거나 등급을 올려\n잠금을 해제하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: onUnlockCta,
                      style: FilledButton.styleFrom(
                        backgroundColor: SoriTokens.primary,
                      ),
                      child: const Text('리뷰 작성하고 잠금 해제'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 피드 카드 공통 셸 — 권위 하이라이트 + 신뢰 헤더 + 세미나 브릿지 + 잠금.
class CommunityPostShell extends StatelessWidget {
  const CommunityPostShell({
    super.key,
    required this.store,
    required this.post,
    required this.body,
    this.trailing,
    this.onComposeReview,
  });

  final SoriStore store;
  final CommunityPost post;
  final Widget body;
  final Widget? trailing;
  final VoidCallback? onComposeReview;

  bool get _unlocked {
    if (post.isBodyLocked) return false;
    final isAuthor =
        post.shopId.isNotEmpty && post.shopId == store.shop.id;
    final isDirector =
        store.session?.activeMode == UserRole.director;
    return post.visibility.canView(
      viewerTier: store.shop.tierBadge,
      isAuthor: isAuthor,
      isDirector: isDirector,
    );
  }

  @override
  Widget build(BuildContext context) {
    final elite = post.tierBadge.rank >= ShopTierBadge.gold.rank;

    return CommunityAuthorityFrame(
      post: post,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
            child: CommunityTrustHeader(
              post: post,
              trailing: trailing,
              animateBadge: elite,
            ),
          ),
          if (_unlocked)
            body
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: CommunityLockedBody(
                previewText: post.body.trim().isEmpty
                    ? post.title
                    : post.body.trim(),
                onUnlockCta: onComposeReview ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '기기·중고 탭에서 리뷰를 작성하면 잠금이 해제됩니다',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
              ),
            ),
          CommunityMonetizationCtaBar(store: store, post: post),
        ],
      ),
    );
  }
}

/// 작성 폼용 공개 범위 선택.
class CommunityVisibilityPicker extends StatelessWidget {
  const CommunityVisibilityPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CommunityVisibility value;
  final ValueChanged<CommunityVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '공개 범위',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(height: 8),
        SegmentedButton<CommunityVisibility>(
          segments: const [
            ButtonSegment(
              value: CommunityVisibility.public,
              label: Text('전체 공개'),
              icon: Icon(Icons.public, size: 16),
            ),
            ButtonSegment(
              value: CommunityVisibility.goldPlus,
              label: Text('골드↑'),
              icon: Icon(Icons.lock_outline, size: 16),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) onChanged(s.first);
          },
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return SoriTokens.primary;
              }
              return SoriTokens.textSecondary;
            }),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value == CommunityVisibility.goldPlus
              ? 'Give & Take — 골드 이상만 본문 열람'
              : '모든 원장에게 공개',
          style: const TextStyle(
            fontSize: 11.5,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
