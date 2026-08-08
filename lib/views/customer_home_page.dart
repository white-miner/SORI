import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_chart.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_card.dart';

/// 고객 홈 — 인투펫 스타일 1:1 케어 타임라인.
class CustomerHomePage extends StatelessWidget {
  const CustomerHomePage({super.key, required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final session = store.session!;
    final customerId = session.customerId;
    final charts = customerId == null
        ? <CustomerChart>[]
        : store.chartsForCustomer(customerId);
    final latest = charts.isEmpty ? null : charts.first;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                '소통하는 리뷰, SORI',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _ShopSelector(store: store),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _AiReportCard(
                chart: latest,
                onDetail: latest == null
                    ? null
                    : () => _openChart(context, latest),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Text(
                '시술 히스토리',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
            ),
          ),
          if (charts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SoriCard(
                  child: Column(
                    children: [
                      Icon(Icons.spa_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      const Text(
                        '아직 케어 기록이 없어요',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '방문 후 원장님이 차트를 열어 주시면\n여기에 1:1 케어 타임라인이 쌓여요',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: charts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final chart = charts[index];
                  return _TimelineCard(
                    chart: chart,
                    onTap: () => _openChart(context, chart),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _openChart(BuildContext context, CustomerChart chart) {
    if (!chart.hasFeedbackLine || chart.feedbackToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ 원장님 확인 대기 중입니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pushNamed(
      '${AppRouter.review}?token=${Uri.encodeQueryComponent(chart.feedbackToken!)}',
    );
  }
}

/// 케어 탭 — 타임라인 전체.
class CustomerCareTab extends StatelessWidget {
  const CustomerCareTab({super.key, required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    return CustomerHomePage(store: store);
  }
}

class _ShopSelector extends StatelessWidget {
  const _ShopSelector({required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final shop = store.shop;
    final owner = shop.ownerName ?? '원장';

    return SoriCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: SoriTokens.primarySoft,
            child: Text(
              owner.characters.first,
              style: const TextStyle(
                color: SoriTokens.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$owner 원장님과 1:1 케어',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () async {
              final uri = Uri.tryParse(shop.naverPlaceUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place, size: 14, color: SoriTokens.success),
                  SizedBox(width: 4),
                  Text(
                    '네이버',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SoriTokens.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiReportCard extends StatelessWidget {
  const _AiReportCard({required this.chart, this.onDetail});

  final CustomerChart? chart;
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B4CDB), Color(0xFF7C6FF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(SoriTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: SoriTokens.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI 케어 리포트',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            chart == null
                ? '아직 생성된 리포트가 없어요'
                : (chart!.directorInsight.isNotEmpty
                    ? chart!.directorInsight
                    : chart!.treatmentSummary),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          if (chart != null) ...[
            const SizedBox(height: 6),
            Text(
              '${chart!.visitNumber}회차 · ${chart!.careName.isNotEmpty ? chart!.careName : '케어'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDetail,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: SoriTokens.primary,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white70,
              ),
              child: const Text(
                'AI 리포트 상세보기',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.chart, required this.onTap});

  final CustomerChart chart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visitDate = chart.visitCheckedAt ?? DateTime.now();
    final next = visitDate.add(const Duration(days: 28));
    final open = chart.hasFeedbackLine;

    return SoriCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: SoriTokens.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${chart.visitNumber}회차',
              style: const TextStyle(
                color: SoriTokens.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chart.careName.isNotEmpty ? chart.careName : chart.treatmentSummary,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: SoriTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '방문 ${_fmt(visitDate)} · 다음 권장 ${_fmt(next)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!open)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: SoriTokens.warningBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '⏳ 확인 대기',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.warningText,
                ),
              ),
            )
          else
            const Icon(Icons.chevron_right, color: SoriTokens.textSecondary),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
