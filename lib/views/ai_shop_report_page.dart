import 'package:flutter/material.dart';

import '../models/ai_shop_report_mock.dart';
import '../models/kakao_alimtalk.dart';
import '../models/shop_finance_health.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'kakao_alimtalk_actions.dart';

/// AI 샵 경영 리포트 — 재무 Hell-Zone + 5대 모듈.
class AiShopReportPage extends StatefulWidget {
  const AiShopReportPage({super.key, this.data});

  final AiShopReportMock? data;

  @override
  State<AiShopReportPage> createState() => _AiShopReportPageState();
}

class _AiShopReportPageState extends State<AiShopReportPage> {
  final _store = SoriStore.instance;
  final Set<String> _sendingIds = {};

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  ShopFinanceHealth get _finance {
    final live = ShopFinanceAnalyzer.analyze(
      shop: _store.shop,
      customers: _store.customers,
    );
    // 실데이터가 CAPA를 넘지 않으면 기획 데모 Hell-Zone 오버레이
    return ShopFinanceAnalyzer.demoOverlay(live);
  }

  Future<void> _sendUsageRequest(DebtRiskCustomer target) async {
    if (_sendingIds.contains(target.customerId)) return;
    setState(() => _sendingIds.add(target.customerId));
    try {
      final result = await _store.sendMembershipUsageRequest(
        customerId: target.customerId,
      );
      if (!mounted) return;
      if (result.isInsufficientPoints) {
        await showInsufficientKakaoPointDialog(context);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.ok
                ? '${target.name}님께 회원권 사용요청을 발송했습니다.'
                : (result.message ?? '발송 실패'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              result.ok ? SoriTokens.primary : Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingIds.remove(target.customerId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.data ?? AiShopReportMock.demo();
    final finance = _finance;
    final hell = finance.isHellZone;
    final borderColor =
        hell ? const Color(0xFFDC2626) : Colors.transparent;

    return Scaffold(
      backgroundColor:
          hell ? const Color(0xFF1A0A0A) : SoriTokens.background,
      appBar: AppBar(
        title: Text(hell ? '🚨 Hell-Zone · AI 샵 경영 리포트' : 'AI 샵 경영 리포트'),
        backgroundColor: hell ? const Color(0xFF2A1212) : SoriTokens.surface,
        foregroundColor: hell ? const Color(0xFFFCA5A5) : SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: hell ? 3 : 0),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _LaborDebtHero(finance: finance),
            const SizedBox(height: 12),
            _SplitRevenueCard(finance: finance),
            const SizedBox(height: 12),
            _DebtRiskListCard(
              items: finance.debtRiskCustomers,
              sendingIds: _sendingIds,
              onRequest: _sendUsageRequest,
            ),
            const SizedBox(height: 14),
            _ReportHero(periodLabel: report.periodLabel),
            const SizedBox(height: 14),
            _RevenueModuleCard(data: report.revenue),
            const SizedBox(height: 12),
            _PortfolioModuleCard(data: report.portfolio),
            const SizedBox(height: 12),
            _TargetSegmentCard(data: report.targetSegment),
            const SizedBox(height: 12),
            _GoldenTimeCard(data: report.goldenTime),
            const SizedBox(height: 12),
            _CareMessageCard(data: report.careMessage),
          ],
        ),
      ),
    );
  }
}

/// 마이페이지 노출용 요약 진입 카드.
class AiShopReportEntryCard extends StatelessWidget {
  const AiShopReportEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final report = AiShopReportMock.demo();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => AiShopReportPage(data: report),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [SoriTokens.primary, Color(0xFF059669)],
            ),
            boxShadow: [
              BoxShadow(
                color: SoriTokens.primary.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'AI LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      report.periodLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'AI 샵 경영 리포트',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '매출·라인업·타깃·골든타임·카톡 케어까지 한눈에',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniStat(
                      label: '추정 매출',
                      value: _won(report.revenue.estimatedSalesWon),
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      label: '화력 메뉴',
                      value: report.portfolio.investMenus.first.name,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _EntryChip(
                            text: '🔥 ${report.portfolio.investMenus.first.tag}',
                          ),
                          _EntryChip(
                            text: '⚠️ ${report.portfolio.cutMenus.first.tag}',
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryChip extends StatelessWidget {
  const _EntryChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LaborDebtHero extends StatelessWidget {
  const _LaborDebtHero({required this.finance});

  final ShopFinanceHealth finance;

  @override
  Widget build(BuildContext context) {
    final hell = finance.isHellZone;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hell
              ? const [Color(0xFF991B1B), Color(0xFFDC2626)]
              : const [Color(0xFF1E293B), Color(0xFF334155)],
        ),
        boxShadow: [
          BoxShadow(
            color: (hell ? const Color(0xFFDC2626) : Colors.black)
                .withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: hell
            ? Border.all(color: const Color(0xFFFCA5A5), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                hell ? 'HELL-ZONE' : '재무 건전성',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                'CAPA ${finance.monthlyCapa} · 임계 ${finance.hellZoneThreshold}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '현재 갚아야 할 노동 부채(원)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _won(finance.laborDebtWon),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '잔여 ${finance.totalRemainingSessions}회'
            ' · CAPA 대비 ${(finance.capaUtilization * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hell) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '잔여 회차가 CAPA의 120%를 초과했습니다. 신규 회원권 판매를 멈추고 소진 캠페인에 집중하세요.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SplitRevenueCard extends StatelessWidget {
  const _SplitRevenueCard({required this.finance});

  final ShopFinanceHealth finance;

  @override
  Widget build(BuildContext context) {
    final single = finance.singlePayRevenueWon;
    final membership = finance.membershipPayDebtWon;
    final total = (single + membership).clamp(1, 1 << 62);
    final singleW = single / total;
    final hell = finance.isHellZone;

    return _ModuleShell(
      eyebrow: '재무',
      title: '매출 분리 · 단과(순수익) vs 회원권(부채)',
      accent: hell ? const Color(0xFFDC2626) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: '단과 결제 (순수익)',
                  value: _won(single),
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: '회원권 결제 (부채)',
                  value: _won(membership),
                  color: hell ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                    flex: (singleW * 1000).round().clamp(1, 999),
                    child: Container(color: const Color(0xFF059669)),
                  ),
                  Expanded(
                    flex: ((1 - singleW) * 1000).round().clamp(1, 999),
                    child: Container(
                      color: hell
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '초록=현금성 단과 · ${hell ? '빨강' : '주황'}=선수금(노동 부채)',
            style: const TextStyle(
              fontSize: 11,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtRiskListCard extends StatelessWidget {
  const _DebtRiskListCard({
    required this.items,
    required this.sendingIds,
    required this.onRequest,
  });

  final List<DebtRiskCustomer> items;
  final Set<String> sendingIds;
  final Future<void> Function(DebtRiskCustomer) onRequest;

  @override
  Widget build(BuildContext context) {
    return _ModuleShell(
      eyebrow: '부채 소거',
      title: '장기 미방문 · 잔여 부채 트리거',
      accent: const Color(0xFFB45309),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '등록 6개월+ & 잔여≥50% 또는 미방문 60일+',
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text(
              '현재 조건에 해당하는 고객이 없습니다.',
              style: TextStyle(
                fontSize: 13,
                color: SoriTokens.textSecondary,
              ),
            )
          else
            ...items.take(6).map((item) {
              final busy = sendingIds.contains(item.customerId);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SoriTokens.warningBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SoriTokens.warningText.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _won(item.laborDebtWon),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.reason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : () => onRequest(item),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB45309),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          busy ? '발송 중…' : '회원권 사용요청',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.periodLabel});

  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SoriTokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SoriTokens.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_graph_rounded, color: SoriTokens.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '데이터 기반 경영 브리핑',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  '$periodLabel · MOCK 미리보기 (정산 API 연동 예정)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleShell extends StatelessWidget {
  const _ModuleShell({
    required this.eyebrow,
    required this.title,
    required this.child,
    this.accent,
  });

  final String eyebrow;
  final String title;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? SoriTokens.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: accent != null
            ? Border.all(color: accent!.withValues(alpha: 0.35), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: tone,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RevenueModuleCard extends StatelessWidget {
  const _RevenueModuleCard({required this.data});

  final AiRevenueModule data;

  @override
  Widget build(BuildContext context) {
    return _ModuleShell(
      eyebrow: '모듈 1',
      title: '실시간 매출 & 회원권 소진 현황',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: '추정 매출',
                  value: _won(data.estimatedSalesWon),
                  footnote: '전월 대비 +${data.salesDeltaPercent}%',
                  accent: SoriTokens.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: '회원권 소진 가치',
                  value: _won(data.membershipBurnValueWon),
                  footnote: '소진률 ${data.membershipBurnRatePercent}%',
                  accent: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: data.membershipBurnRatePercent / 100,
              minHeight: 8,
              backgroundColor: SoriTokens.border,
              color: const Color(0xFF0F766E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '방문 ${data.visitCount}회 · 티켓 차감 ${data.ticketSessionsUsed}회',
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.highlight,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.footnote,
    required this.accent,
  });

  final String label;
  final String value;
  final String footnote;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            footnote,
            style: const TextStyle(
              fontSize: 11,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioModuleCard extends StatelessWidget {
  const _PortfolioModuleCard({required this.data});

  final AiPortfolioModule data;

  @override
  Widget build(BuildContext context) {
    return _ModuleShell(
      eyebrow: '모듈 2 · Portfolio Optimizer',
      title: '🔥 집중 투자 메뉴 vs ⚠️ 축소/삭제 추천',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '화력 집중',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...data.investMenus.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MenuSignalTile(signal: m),
              )),
          const SizedBox(height: 4),
          const Text(
            '축소 / 삭제 추천',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...data.cutMenus.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MenuSignalTile(signal: m),
              )),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SoriTokens.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '💡 AI 신규 제안  ${data.aiProposal}',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSignalTile extends StatelessWidget {
  const _MenuSignalTile({required this.signal});

  final AiMenuSignal signal;

  @override
  Widget build(BuildContext context) {
    final invest = signal.tone == AiMenuTone.invest;
    final badgeColor =
        invest ? const Color(0xFFFF6B4A) : const Color(0xFF6B7280);
    final badgeBg =
        invest ? const Color(0xFF3A1C16) : SoriTokens.surfaceElevated;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SoriTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  signal.tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SoriTokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SoriTokens.border),
                ),
                child: Text(
                  signal.metric,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            signal.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            signal.reason,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetSegmentCard extends StatelessWidget {
  const _TargetSegmentCard({required this.data});

  final AiTargetSegmentModule data;

  @override
  Widget build(BuildContext context) {
    return _ModuleShell(
      eyebrow: '모듈 3',
      title: '🎯 핵심 타깃 고객층 분석',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.primaryLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${data.sharePercent}%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '주력 구매 비중',
            style: TextStyle(
              fontSize: 11,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.traits
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: SoriTokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            data.summary,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldenTimeCard extends StatelessWidget {
  const _GoldenTimeCard({required this.data});

  final AiGoldenTimeModule data;

  @override
  Widget build(BuildContext context) {
    return _ModuleShell(
      eyebrow: '모듈 4',
      title: '🚨 재방문 골든타임 & 회원권 임박 알림',
      child: Column(
        children: [
          for (final item in data.items) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.urgency == 'imminent'
                    ? SoriTokens.warningBg
                    : SoriTokens.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: item.urgency == 'imminent'
                      ? SoriTokens.warningText.withValues(alpha: 0.35)
                      : SoriTokens.outlinePurple,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: SoriTokens.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.urgency == 'imminent' ? '임박' : '재방문',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: item.urgency == 'imminent'
                                ? SoriTokens.warningText
                                : SoriTokens.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.reason,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SoriTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '→ ${item.action}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CareMessageCard extends StatelessWidget {
  const _CareMessageCard({required this.data});

  final AiCareMessageModule data;

  Future<void> _copy(BuildContext context) =>
      copyKakaoMessage(context, data.preview);

  Future<void> _sendKakao(BuildContext context) async {
    final store = SoriStore.instance;
    final demoPhone = store.customers.isNotEmpty
        ? store.customers.first.phone
        : '01012345678';
    final chartId =
        store.charts.isNotEmpty ? store.charts.first.id : 'chart-1';
    final careUrl = SoriStore.buildCareReportUrl(chartId);
    final body = '${data.preview}\n\n케어 리포트 보기: $careUrl';

    await sendKakaoAlimtalkWithUi(
      context,
      store: store,
      customerPhone: demoPhone,
      content: body,
      templateCode: KakaoAlimtalkPricing.careMessageTemplate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = SoriStore.instance.shop.kakaoPoint;
    return _ModuleShell(
      eyebrow: '모듈 5',
      title: '💬 카카오톡 1:1 자동 케어 메시지',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '잔여 알림톡 ${points}P · 발송 시 ${KakaoAlimtalkPricing.sendCostPoint}P 차감',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: data.chartTags
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: SoriTokens.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$t',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.primary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SoriTokens.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SoriTokens.border),
            ),
            child: Text(
              data.preview,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _sendKakao(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: const Color(0xFF191600),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text(
                    '카카오톡 즉시 발송',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SoriTokens.primary,
                    side: const BorderSide(color: SoriTokens.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    '문구 복사',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


String _won(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    buf.write(s[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
  }
  return '₩${buf.toString()}';
}
