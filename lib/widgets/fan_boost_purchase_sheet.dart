import 'package:flutter/material.dart';

import '../models/point_shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'insufficient_points_sheet.dart';

/// 부스터 후원 구매 시트 — 부족 시 55E IAP 원탭.
Future<bool> showFanBoostPurchaseSheet(
  BuildContext context, {
  required SoriStore store,
  required String chartId,
  required String targetShopId,
  String caseTitle = '',
}) async {
  await store.refreshPointShopItems();
  await store.refreshCustomerEchoWallet();
  if (!context.mounted) return false;

  final items = store.pointShopBoosters.isNotEmpty
      ? store.pointShopBoosters
      : PointShopItem.catalogBoosters;
  final specialItems = store.supporterGiftItems.isNotEmpty
      ? store.supporterGiftItems
      : PointShopItem.catalogSpecialGifts;

  final purchased = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      var busySku = '';
      return StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> purchaseItem(PointShopItem item, {required bool special}) async {
            if (busySku.isNotEmpty) return;
            setModal(() => busySku = item.sku);
            final label = special ? '스페셜 후원' : '부스터 후원';
            try {
              await store.refreshCustomerEchoWallet();
              final bal = store.customerEchoWallet.pointTotal;
              if (bal < item.pricePoints) {
                final charged = await showInsufficientPointsSheet(
                  ctx,
                  store: store,
                  need: item.pricePoints,
                  have: bal,
                  productLabel: label,
                  useCustomerWallet: true,
                );
                if (charged != true || !ctx.mounted) {
                  if (ctx.mounted) setModal(() => busySku = '');
                  return;
                }
              }

              var result = special
                  ? await store.purchaseSpecialSupporterForChart(
                      chartId: chartId,
                      sku: item.sku,
                      targetShopId: targetShopId,
                    )
                  : await store.purchaseFanBoostForChart(
                      chartId: chartId,
                      sku: item.sku,
                      targetShopId: targetShopId,
                    );
              if (!ctx.mounted) return;

              if (result.insufficient) {
                final charged = await showInsufficientPointsSheet(
                  ctx,
                  store: store,
                  need: result.need > 0 ? result.need : item.pricePoints,
                  have: result.have,
                  productLabel: label,
                  useCustomerWallet: true,
                );
                if (charged == true && ctx.mounted) {
                  result = special
                      ? await store.purchaseSpecialSupporterForChart(
                          chartId: chartId,
                          sku: item.sku,
                          targetShopId: targetShopId,
                        )
                      : await store.purchaseFanBoostForChart(
                          chartId: chartId,
                          sku: item.sku,
                          targetShopId: targetShopId,
                        );
                } else {
                  setModal(() => busySku = '');
                  return;
                }
              }

              if (!ctx.mounted) return;
              if (result.ok) {
                Navigator.pop(ctx, true);
                return;
              }
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    result.message.isEmpty
                        ? '$label에 실패했습니다.'
                        : result.message,
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } catch (_) {
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('$label 실패. 마이그레이션을 확인해 주세요.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } finally {
              if (ctx.mounted) setModal(() => busySku = '');
            }
          }

          Widget skuTile(PointShopItem item, {required bool special}) {
            final busy = busySku == item.sku;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: special
                    ? const Color(0xFF2A2410)
                    : SoriTokens.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: busySku.isNotEmpty
                      ? null
                      : () => purchaseItem(item, special: special),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: special
                            ? const Color(0x66FBBF24)
                            : SoriTokens.textSecondary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                special
                                    ? '${item.pricePoints}E · 기존 부스트 위에 겹쳐집니다'
                                    : '${item.pricePoints}E · 닉네임 공개 응원',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: SoriTokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (busy)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Text(
                            special ? '스페셜 후원' : 'Echo로 띄워주기',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                              color: SoriTokens.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final bal = store.customerEchoWallet.pointTotal;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SoriTokens.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '🔥 우리 원장님 게시물 응원하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '🔥 부스터 후원',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    caseTitle.trim().isEmpty
                        ? '내 Echo로 원장님 케이스를 「우리 지역」 상단에 올려요. 닉네임이 피드에 공개됩니다 · 정산금 변동 없음.'
                        : '「$caseTitle」에 부스터를 지원합니다. 내 닉네임이 후원자로 노출됩니다.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x22F472B6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x55F472B6)),
                    ),
                    child: Text(
                      (store.session?.name ?? '').trim().isNotEmpty
                          ? '🔥 후원자 표기: ${(store.session?.name ?? '').trim()} (익명 불가)'
                          : '🔥 후원자 닉네임이 피드·상세에 공개됩니다 (익명 불가)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '내 보유 ${bal}E · 1 Echo = 100원',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (specialItems.isNotEmpty) ...[
                    const Text(
                      '✨ 스페셜 후원',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '이미 부스트 중이어도 스페셜 후원은 위에 겹쳐집니다.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textTertiary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...specialItems.map((item) => skuTile(item, special: true)),
                    const SizedBox(height: 8),
                    const Text(
                      '🔥 부스터 후원',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ...items.map((item) => skuTile(item, special: false)),
                  TextButton(
                    onPressed:
                        busySku.isNotEmpty ? null : () => Navigator.pop(ctx, false),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return purchased == true;
}
