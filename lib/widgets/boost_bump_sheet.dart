import 'package:flutter/material.dart';

import '../models/ai_tool.dart';
import '../models/point_shop.dart';
import '../services/ai_tool_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'insufficient_points_sheet.dart';

/// Split & Micro — feed bump only (5E default), separate from AI.
Future<bool> showBoostBumpSheet(
  BuildContext context, {
  required SoriStore store,
  required String chartId,
  String caseTitle = '',
}) async {
  await store.refreshPointShopItems();
  await store.refreshPointWallet();
  final promoCredits = await AiToolService.loadPromoCredits(store.shop.id);
  if (!context.mounted) return false;

  final purchased = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => BoostBumpSheet(
      store: store,
      chartId: chartId,
      caseTitle: caseTitle,
      promoCredits: promoCredits,
    ),
  );
  return purchased ?? false;
}

class BoostBumpSheet extends StatefulWidget {
  const BoostBumpSheet({
    super.key,
    required this.store,
    required this.chartId,
    required this.caseTitle,
    required this.promoCredits,
  });

  final SoriStore store;
  final String chartId;
  final String caseTitle;
  final List<ShopPromoCredit> promoCredits;

  @override
  State<BoostBumpSheet> createState() => _BoostBumpSheetState();
}

class _BoostBumpSheetState extends State<BoostBumpSheet> {
  var _busySku = '';

  int _promoBalanceFor(String sku) {
    return widget.promoCredits
        .where((c) => c.creditSku == sku)
        .fold<int>(0, (sum, c) => sum + c.balance);
  }

  Future<void> _buy(PointShopItem item) async {
    if (_busySku.isNotEmpty) return;
    setState(() => _busySku = item.sku);
    try {
      var result = await widget.store.purchaseBoostForChart(
        chartId: widget.chartId,
        sku: item.sku,
      );
      if (!mounted) return;

      if (result.insufficient) {
        final charged = await showInsufficientPointsSheet(
          context,
          store: widget.store,
          need: result.need > 0 ? result.need : item.pricePoints,
          have: result.have,
          productLabel: item.title,
        );
        if (!charged || !mounted) {
          setState(() => _busySku = '');
          return;
        }
        result = await widget.store.purchaseBoostForChart(
          chartId: widget.chartId,
          sku: item.sku,
        );
        if (!mounted) return;
      }

      if (result.ok) {
        Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty ? '적용에 실패했습니다.' : result.message,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('적용에 실패했습니다. 마이그레이션 075를 확인해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busySku = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bump = PointShopItem.catalogBump;
    final spotlight = PointShopItem.catalogSpotlight12h;
    final promoBump = _promoBalanceFor(spotlight.sku);

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
              '피드 끌어올리기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              widget.caseTitle.trim().isEmpty
                  ? 'AI 카피와 별도 · 500원부터 · Echo만 사용'
                  : '「${widget.caseTitle}」 노출을 올립니다.',
              style: const TextStyle(
                fontSize: 13,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '보유 ${widget.store.pointWallet.pointTotal}E',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: SoriTokens.premium,
              ),
            ),
            if (promoBump > 0) ...[
              const SizedBox(height: 8),
              Text(
                '스포트라이트 쿠폰 $promoBump장 (기존 부스터 보상)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.primary.withValues(alpha: 0.9),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _skuTile(
              item: bump,
              subtitle: '카테고리 피드 4시간 상단 · 500원',
              highlight: true,
            ),
            const SizedBox(height: 8),
            _skuTile(
              item: spotlight,
              subtitle: promoBump > 0
                  ? 'Home+커뮤니티 12h · 쿠폰 우선 ($promoBump장)'
                  : 'Home+커뮤니티 12h · 900원',
            ),
          ],
        ),
      ),
    );
  }

  Widget _skuTile({
    required PointShopItem item,
    required String subtitle,
    bool highlight = false,
  }) {
    final busy = _busySku == item.sku;
    return Material(
      color: highlight
          ? SoriTokens.primary.withValues(alpha: 0.08)
          : SoriTokens.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : () => _buy(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '${item.pricePoints}E',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: SoriTokens.premium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
