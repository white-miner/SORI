import 'package:flutter/material.dart';

import '../models/point_shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'insufficient_points_sheet.dart';

/// 고객 Fan-Boost 구매 시트 — 부족 시 55E IAP 원탭.
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
          Future<void> buy(PointShopItem item) async {
            if (busySku.isNotEmpty) return;
            setModal(() => busySku = item.sku);
            try {
              await store.refreshCustomerEchoWallet();
              final bal = store.customerEchoWallet.pointTotal;
              if (bal < item.pricePoints) {
                // Gap UX: 25E 이하·부족 시 55E 팩 유도
                final charged = await showInsufficientPointsSheet(
                  ctx,
                  store: store,
                  need: item.pricePoints,
                  have: bal,
                  productLabel: 'Fan-Boost',
                  useCustomerWallet: true,
                );
                if (charged != true || !ctx.mounted) {
                  if (ctx.mounted) setModal(() => busySku = '');
                  return;
                }
              }

              var result = await store.purchaseFanBoostForChart(
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
                  productLabel: 'Fan-Boost',
                  useCustomerWallet: true,
                );
                if (charged == true && ctx.mounted) {
                  result = await store.purchaseFanBoostForChart(
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
                        ? 'Fan-Boost에 실패했습니다.'
                        : result.message,
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } catch (_) {
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Fan-Boost 실패. 마이그레이션 057을 확인해 주세요.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } finally {
              if (ctx.mounted) setModal(() => busySku = '');
            }
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
                    '우리 원장님 홍보 부스터',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    caseTitle.trim().isEmpty
                        ? '내 Echo로 원장님 케이스를 「우리 지역」 상단에 올려요. 닉네임이 피드에 공개됩니다 · 정산금 변동 없음.'
                        : '「$caseTitle」를 Fan-Boost로 고정합니다. 내 닉네임이 스폰서로 노출됩니다.',
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
                          ? '🔥 스폰서 표기: ${(store.session?.name ?? '').trim()} (익명 불가)'
                          : '🔥 스폰서 닉네임이 피드·상세에 강제 노출됩니다 (익명 불가)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF9A8D4),
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
                      color: Color(0xFFF9A8D4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...items.map((item) {
                    final busy = busySku == item.sku;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: busySku.isNotEmpty ? null : () => buy(item),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SoriTokens.textPrimary,
                          side: BorderSide(
                            color: const Color(0xFFF472B6).withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
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
                                '${item.pricePoints}E',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFF9A8D4),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
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
