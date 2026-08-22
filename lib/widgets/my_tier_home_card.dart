import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../models/shop_tier_badge.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import 'shop_tier_badge_chip.dart';

/// 원장 소개 옆 소형 티어 마크 — 탭 시 전체 등급 가이드.
class MyTierBadgeButton extends StatelessWidget {
  const MyTierBadgeButton({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showFullTierGuideSheet(context, shop: shop),
      borderRadius: BorderRadius.circular(99),
      child: shop.tierBadge.isVisible
          ? ShopTierBadgeChip(badge: shop.tierBadge, compact: true)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: SoriTokens.primarySoft,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: SoriTokens.outlinePurple),
              ),
              child: const Text(
                '등급',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.primary,
                ),
              ),
            ),
    );
  }
}

/// @deprecated Home에서는 [MyTierBadgeButton] 사용. 호환용 유지.
class MyTierHomeCard extends StatelessWidget {
  const MyTierHomeCard({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return MyTierBadgeButton(shop: shop);
  }
}

Future<void> showMyTierProgressSheet(
  BuildContext context, {
  required Shop shop,
}) =>
    showFullTierGuideSheet(context, shop: shop);

/// 아이언 → 그랜드 디렉터 전체 등급표 + 달성 조건.
Future<void> showFullTierGuideSheet(
  BuildContext context, {
  required Shop shop,
}) {
  final current = shop.tierBadge;
  final all = <ShopTierThreshold>[
    ...ShopTierThreshold.social,
    ...ShopTierThreshold.business,
  ];

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: SoriTokens.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      final bottom = soriSheetBottomPadding(ctx);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (ctx, scroll) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SoriTokens.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '전체 등급 가이드',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  '아이언(Iron)부터 마스터 디렉터(Master Director)까지',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  current.isVisible
                      ? '현재 · ${current.label} (${current.englishLabel})'
                      : '현재 등급 준비 중',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: SoriTokens.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: scroll,
                    itemCount: all.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final t = all[i];
                      final isCurrent = t.badge == current;
                      final isSocial = i < ShopTierThreshold.social.length;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? SoriTokens.primarySoft
                              : SoriTokens.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? SoriTokens.primary
                                : SoriTokens.border,
                            width: isCurrent ? 1.4 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ShopTierBadgeChip(
                                  badge: t.badge,
                                  compact: true,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.badge.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        t.badge.englishLabel,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: SoriTokens.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  isSocial ? '소셜' : '비즈니스',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSocial
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFFFBBF24),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ..._thresholdLines(t).map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '· $line',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: SoriTokens.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

List<String> _thresholdLines(ShopTierThreshold t) {
  if (t.shared > 0 || t.likes > 0 || t.followers > 0) {
    return [
      '공유 차트 ${t.shared}+',
      '좋아요 ${t.likes}+',
      '팔로워 ${t.followers}+',
    ];
  }
  final lines = <String>[
    '세미나 요청 ${t.requests}+',
    '세미나 개최 ${t.seminars}+',
  ];
  if (t.funding > 0) {
    final won = t.funding >= 100000000
        ? '${t.funding ~/ 100000000}억+'
        : '${t.funding ~/ 10000}만+';
    lines.add('펀딩 $won');
  }
  return lines;
}
