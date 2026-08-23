import 'package:flutter/material.dart';

import '../models/point_shop.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'insufficient_points_sheet.dart';

/// 임상 케이스 노출 부스터 구매 시트 + 잔액 부족 시 IAP 원탭 브릿지.
Future<bool> showBoostPurchaseSheet(
  BuildContext context, {
  required SoriStore store,
  required String chartId,
  String caseTitle = '',
}) async {
  await store.refreshPointShopItems();
  await store.refreshPointWallet();
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
              var result = await store.purchaseBoostForChart(
                chartId: chartId,
                sku: item.sku,
              );
              if (!ctx.mounted) return;

              if (result.insufficient) {
                final charged = await showInsufficientPointsSheet(
                  ctx,
                  store: store,
                  need: result.need > 0 ? result.need : item.pricePoints,
                  have: result.have,
                  productLabel: item.title,
                );
                if (!charged || !ctx.mounted) {
                  setModal(() => busySku = '');
                  return;
                }
                result = await store.purchaseBoostForChart(
                  chartId: chartId,
                  sku: item.sku,
                );
                if (!ctx.mounted) return;
              }

              if (result.ok) {
                Navigator.pop(ctx, true);
                return;
              }
              if (result.insufficient) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('충전이 반영됐지만 아직 Echo가 부족합니다.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.message.isEmpty
                          ? '부스터 구매에 실패했습니다.'
                          : result.message,
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (_) {
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('부스터 구매에 실패했습니다. 마이그레이션 055·056을 확인해 주세요.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } finally {
              if (ctx.mounted) setModal(() => busySku = '');
            }
          }

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
                    '노출 부스터 구매',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    caseTitle.trim().isEmpty
                        ? '「우리 지역」탭 최상단에 AD로 고정 노출됩니다. Echo만 사용 · 1E=₩100 · 출금 불가.'
                        : '「$caseTitle」를 우리 지역 최상단에 고정합니다.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '보유 ${store.pointWallet.pointTotal}E · 1 Echo = 100원',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFA78BFA),
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
                            color: SoriTokens.primary.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
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
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  if (item.badge.isNotEmpty)
                                    Text(
                                      item.badge,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: SoriTokens.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (busy)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Text(
                                '${item.pricePoints}E',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFA78BFA),
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
