import 'package:flutter/material.dart';

import '../models/ai_shop_report_mock.dart';
import '../models/shop_tier_badge.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../views/ai_shop_report_page.dart';
import 'affiliate_earnings_card.dart';
import 'point_charging_station_card.dart';
import 'shop_tier_progress_card.dart';

/// My Page · AI Manager 탭 — 모듈형 대시보드.
class MyAiManagerTabBody extends StatelessWidget {
  const MyAiManagerTabBody({
    super.key,
    required this.store,
    required this.isOwner,
  });

  final SoriStore store;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 40, color: SoriTokens.textSecondary),
              SizedBox(height: 12),
              Text(
                '원장 전용',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'AI Manager는 샵 운영 인사이트를 위한\n원장 전용 보드입니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SoriTokens.textSecondary,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final report = AiShopReportMock.demo();
    final shop = store.shop;
    final dormant = store.customers.where((c) {
      final last = c.lastTreatmentDate;
      return DateTime.now().difference(last).inDays >= 90;
    }).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'AI Manager',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AiShopReportPage(data: report),
                  ),
                );
              },
              child: const Text('전체 리포트'),
            ),
          ],
        ),
        Text(
          report.periodLabel,
          style: const TextStyle(
            fontSize: 12.5,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        PointChargingStationCard(store: store),
        const SizedBox(height: 12),
        SettlementWalletCard(store: store),
        const SizedBox(height: 12),
        AffiliateEarningsCard(store: store),
        const SizedBox(height: 12),
        ShopTierProgressCard(shop: shop),
        const SizedBox(height: 12),
        _ModuleCard(
          title: '이번 달 매출 · 소진',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _won(report.revenue.estimatedSalesWon),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: SoriTokens.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '전월 대비 ${report.revenue.salesDeltaPercent >= 0 ? '+' : ''}${report.revenue.salesDeltaPercent}% · 방문 ${report.revenue.visitCount}회',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '회원권 소진 ${_won(report.revenue.membershipBurnValueWon)}'
                ' (${report.revenue.membershipBurnRatePercent}%)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                report.revenue.highlight,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ModuleCard(
          title: '단골 이탈 방지',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dormant > 0 ? '$dormant명' : '0명',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '90일 이상 미방문 · 리마인드 후보',
                style: TextStyle(
                  fontSize: 12.5,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                dormant > 0
                    ? '케어 리마인드·티켓팅 제안 타이밍을 확인해 주세요.'
                    : '현재 이탈 위험 단골이 없어요. 좋은 흐름입니다.',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: SoriTokens.textSecondary,
                ),
              ),
              if (dormant > 0) ...[
                const SizedBox(height: 10),
                ...store.customers
                    .where((c) =>
                        DateTime.now().difference(c.lastTreatmentDate).inDays >=
                        90)
                    .take(3)
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '· ${c.name} · ${DateTime.now().difference(c.lastTreatmentDate).inDays}일 전',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ModuleCard(
          title: '메뉴 포트폴리오',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '화력 집중',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.primary,
                ),
              ),
              const SizedBox(height: 6),
              ...report.portfolio.investMenus.take(2).map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '↑ ${m.name} · ${m.metric}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              const Text(
                '정리 후보',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF87171),
                ),
              ),
              const SizedBox(height: 6),
              ...report.portfolio.cutMenus.take(2).map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '↓ ${m.name} · ${m.metric}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              Text(
                report.portfolio.aiProposal,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: SoriTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '샵 등급 · ${shop.tierBadge == ShopTierBadge.none ? '준비 중' : shop.tierBadge.label}',
                style: const TextStyle(
                  fontSize: 11,
                  color: SoriTokens.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _won(int v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}억';
    if (v >= 10000) return '${(v / 10000).round()}만';
    return '$v';
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
