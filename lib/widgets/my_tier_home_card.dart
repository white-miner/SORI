import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../models/shop_tier_badge.dart';
import '../theme/sori_tokens.dart';
import 'shop_tier_badge_chip.dart';

/// Home「내 등급」— 중앙 뱃지 + 탭 시 승급 조건 바텀시트.
class MyTierHomeCard extends StatelessWidget {
  const MyTierHomeCard({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final snap = shop.tierProgress;
    final label = shop.tierBadge.isVisible
        ? shop.tierBadge.label
        : '등급 준비 중';

    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showMyTierProgressSheet(context, shop: shop),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SoriTokens.outlinePurple),
          ),
          child: Column(
            children: [
              const Text(
                '내 등급',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (shop.tierBadge.isVisible)
                ShopTierBadgeChip(badge: shop.tierBadge, compact: false)
              else
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: SoriTokens.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: SoriTokens.primary,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: SoriTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                snap.nextSocial != null
                    ? '다음 ${snap.nextSocial!.label}까지 ${(snap.socialRatio * 100).round()}%'
                    : (snap.nextBusiness != null
                        ? '다음 ${snap.nextBusiness!.label}까지 ${(snap.businessRatio * 100).round()}%'
                        : '최고 등급에 도달했어요'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: SoriTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '탭하여 승급 조건 보기',
                style: TextStyle(
                  fontSize: 11,
                  color: SoriTokens.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showMyTierProgressSheet(
  BuildContext context, {
  required Shop shop,
}) {
  final snap = shop.tierProgress;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SoriTokens.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SoriTokens.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              ShopTierBadgeChip(badge: shop.tierBadge, compact: false),
              const SizedBox(height: 10),
              Text(
                shop.tierBadge.isVisible ? shop.tierBadge.label : '등급 없음',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              if (snap.nextSocial != null) ...[
                _TierConditionBlock(
                  title: '다음 등급 · ${snap.nextSocial!.label}',
                  lines: _socialProgressLines(snap),
                  ratio: snap.socialRatio,
                ),
                const SizedBox(height: 14),
              ],
              if (snap.nextBusiness != null) ...[
                _TierConditionBlock(
                  title: '비즈니스 · ${snap.nextBusiness!.label}',
                  lines: _businessProgressLines(snap),
                  ratio: snap.businessRatio,
                ),
              ],
              if (snap.nextSocial == null && snap.nextBusiness == null)
                const Text(
                  '모든 승급 조건을 달성했습니다.',
                  style: TextStyle(color: SoriTokens.textSecondary),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

List<String> _socialProgressLines(ShopTierProgressSnapshot snap) {
  ShopTierThreshold? next;
  for (final t in ShopTierThreshold.social) {
    if (t.badge == snap.nextSocial) {
      next = t;
      break;
    }
  }
  if (next == null) return snap.socialRemain;
  return [
    '공유 차트  ${snap.shared} / ${next.shared}',
    '좋아요     ${snap.likes} / ${next.likes}',
    '팔로워    ${snap.followers} / ${next.followers}',
  ];
}

List<String> _businessProgressLines(ShopTierProgressSnapshot snap) {
  ShopTierThreshold? next;
  for (final t in ShopTierThreshold.business) {
    if (t.badge == snap.nextBusiness) {
      next = t;
      break;
    }
  }
  if (next == null) return snap.businessRemain;
  final lines = <String>[
    '세미나 요청  ${snap.requests} / ${next.requests}',
    '세미나 개최  ${snap.seminars} / ${next.seminars}',
  ];
  if (next.funding > 0) {
    lines.add('펀딩  ${snap.funding} / ${next.funding}');
  }
  return lines;
}

class _TierConditionBlock extends StatelessWidget {
  const _TierConditionBlock({
    required this.title,
    required this.lines,
    required this.ratio,
  });

  final String title;
  final List<String> lines;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoriTokens.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoriTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '· $line',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.04, 1),
              minHeight: 6,
              backgroundColor: SoriTokens.primarySoft,
              color: SoriTokens.primary,
            ),
          ),
        ],
      ),
    );
  }
}
