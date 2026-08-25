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
        ? SoriTokens.premium
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

/// 잠금 본문 Fallback — 블러 + Echo 해금 / 리뷰 CTA.
class CommunityLockedBody extends StatelessWidget {
  const CommunityLockedBody({
    super.key,
    required this.previewText,
    required this.onUnlockCta,
    this.unlockCost = 5,
    this.walletBalance,
    this.onUnlockWithPoints,
    this.unlocking = false,
  });

  final String previewText;
  final VoidCallback onUnlockCta;
  final int unlockCost;
  final int? walletBalance;
  final VoidCallback? onUnlockWithPoints;
  final bool unlocking;

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
                    Text(
                      walletBalance == null
                          ? '리뷰 작성으로 등급을 올리거나\nEcho로 즉시 열람할 수 있어요'
                          : '보유 ${walletBalance}E · 해금 ${unlockCost}E',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (onUnlockWithPoints != null) ...[
                      FilledButton(
                        onPressed: unlocking ? null : onUnlockWithPoints,
                        style: FilledButton.styleFrom(
                          backgroundColor: SoriTokens.primary,
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: Text(
                          unlocking
                              ? '열람 처리 중…'
                              : '$unlockCost E를 사용해 즉시 열람하기',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextButton(
                      onPressed: onUnlockCta,
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

/// 피드 카드 공통 셸 — 권위 하이라이트 + 신뢰 헤더 + 잠금 + CTA.
class CommunityPostShell extends StatefulWidget {
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

  @override
  State<CommunityPostShell> createState() => _CommunityPostShellState();
}

class _CommunityPostShellState extends State<CommunityPostShell> {
  bool _unlocking = false;
  CommunityPost? _unlockedOverride;

  CommunityPost get _post => _unlockedOverride ?? widget.post;

  bool get _unlocked {
    final post = _post;
    if (post.isBodyLocked) return false;
    final isAuthor =
        post.shopId.isNotEmpty && post.shopId == widget.store.shop.id;
    final isDirector =
        widget.store.session?.activeMode == UserRole.director;
    return post.visibility.canView(
      viewerTier: widget.store.shop.tierBadge,
      isAuthor: isAuthor,
      isDirector: isDirector,
    );
  }

  Future<void> _unlockWithPoints() async {
    if (_unlocking) return;
    setState(() => _unlocking = true);
    try {
      final updated = await widget.store.unlockCommunityPostWithPoints(
        widget.post,
        cost: widget.post.unlockCost,
      );
      if (!mounted) return;
      if (updated != null) {
        setState(() => _unlockedOverride = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.post.unlockCost}E로 열람했습니다 · 작성자에게 Echo 수익이 분배됩니다',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('insufficient')
          ? 'Echo가 부족합니다. 마이페이지 충전소에서 충전해 주세요.'
          : '열람에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final elite = post.tierBadge.rank >= ShopTierBadge.gold.rank;
    final bal = widget.store.pointWallet.pointTotal;

    return CommunityAuthorityFrame(
      post: post,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
            child: CommunityTrustHeader(
              post: post,
              trailing: widget.trailing,
              animateBadge: elite,
            ),
          ),
          if (_unlocked)
            widget.body
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: CommunityLockedBody(
                previewText: post.body.trim().isEmpty
                    ? post.title
                    : post.body.trim(),
                unlockCost: post.unlockCost,
                walletBalance: bal > 0 || widget.store.pointWallet.id.isNotEmpty
                    ? bal
                    : null,
                unlocking: _unlocking,
                onUnlockWithPoints: _unlockWithPoints,
                onUnlockCta: widget.onComposeReview ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '기기 리뷰 탭에서 리뷰를 작성하면 잠금이 해제됩니다',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
              ),
            ),
          CommunityMonetizationCtaBar(store: widget.store, post: post),
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
