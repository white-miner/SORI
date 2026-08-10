import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_logo.dart';
import 'care_history_detail_page.dart';
import 'ikea_review_composer_page.dart';

/// 고객 모드 전용 케어 탭.
class CustomerCareTab extends StatelessWidget {
  const CustomerCareTab({super.key, required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final session = store.session!;
    final customerId = session.customerId;
    final customer =
        customerId == null ? null : store.findCustomer(customerId);
    final charts = customerId == null
        ? <CustomerChart>[]
        : store.chartsForCustomer(customerId).toList()
      ..sort((a, b) => b.visitNumber.compareTo(a.visitNumber));
    final latest = charts.isEmpty ? null : charts.first;
    final name = session.name.trim().isEmpty
        ? (customer?.name ?? '고객')
        : session.name.trim();
    final shopName = store.shop.name.trim().isEmpty ? 'SORI 샵' : store.shop.name;
    final lastVisit = latest?.visitCheckedAt ??
        latest?.createdAt ??
        customer?.lastTreatmentDate;
    final nextVisit = lastVisit?.add(const Duration(days: 28));
    final careName = latest == null
        ? (customer?.membershipServiceName.isNotEmpty == true
            ? customer!.membershipServiceName
            : '진행 중인 케어')
        : (latest.careName.isNotEmpty
            ? latest.careName
            : (latest.treatmentSummary.isNotEmpty
                ? latest.treatmentSummary
                : '케어'));
    final visitNo = latest?.visitNumber ?? customer?.membershipUsedVisits ?? 0;

    return ColoredBox(
      color: const Color(0xFFF5F6F8),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _ProfileHeaderRow(
              name: name,
              onCalendar: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('예약 캘린더는 준비 중이에요'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _AiReportCard(
              shopName: shopName,
              lastVisit: lastVisit,
              insight: latest?.directorInsight ?? '',
              onDetail: () {
                if (latest == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('아직 AI 리포트가 없어요'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _AiReportDetailPage(
                      shopName: shopName,
                      chart: latest,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _CareSummaryCard(
              careName: careName,
              visitNo: visitNo,
              nextVisit: nextVisit,
              remaining: customer?.membershipRemainingVisits ?? 0,
              onMore: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CareHistoryDetailPage(store: store),
                  ),
                );
              },
            ),
            if (latest != null && latest.hasFeedbackLine) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          backgroundColor: SoriTokens.background,
                          appBar: AppBar(
                            title: const Text('리뷰 작성'),
                            backgroundColor: Colors.white,
                            foregroundColor: SoriTokens.textPrimary,
                            elevation: 0,
                          ),
                          body: IkeaReviewComposerPage(
                            store: store,
                            chart: latest,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text(
                    '리뷰 작성하기',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SoriTokens.primary,
                    side: const BorderSide(color: SoriTokens.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderRow extends StatelessWidget {
  const _ProfileHeaderRow({
    required this.name,
    required this.onCalendar,
  });

  final String name;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _ProfileChip(label: name, selected: true),
                const SizedBox(width: 10),
                const _ProfileChip(label: '가족', selected: false, muted: true),
                const SizedBox(width: 10),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: SoriTokens.border),
                  ),
                  child: Icon(Icons.add, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: '캘린더',
          onPressed: onCalendar,
          icon: const Icon(Icons.calendar_month_outlined),
          color: SoriTokens.textPrimary,
        ),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.label,
    required this.selected,
    this.muted = false,
  });

  final String label;
  final bool selected;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor:
              selected ? SoriTokens.primarySoft : const Color(0xFFEEF0F3),
          child: muted
              ? Icon(Icons.person_outline, color: Colors.grey[500], size: 22)
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Opacity(
                    opacity: 0.9,
                    child: const SoriLogo(width: 28, height: 28),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? SoriTokens.primary : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _AiReportCard extends StatelessWidget {
  const _AiReportCard({
    required this.shopName,
    required this.lastVisit,
    required this.insight,
    required this.onDetail,
  });

  final String shopName;
  final DateTime? lastVisit;
  final String insight;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '홈케어 진행중',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome, color: SoriTokens.primary, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            shopName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lastVisit == null
                ? '최근 방문 기록이 없어요'
                : '최근 방문 ${_fmt(lastVisit!)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
            ),
          ),
          if (insight.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              insight,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDetail,
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'AI 리포트 상세보기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareSummaryCard extends StatelessWidget {
  const _CareSummaryCard({
    required this.careName,
    required this.visitNo,
    required this.nextVisit,
    required this.remaining,
    required this.onMore,
  });

  final String careName;
  final int visitNo;
  final DateTime? nextVisit;
  final int remaining;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '케어 내역 요약',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            careName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            visitNo > 0 ? '$visitNo회차 진행중 · 잔여 $remaining회' : '아직 시술 기록이 없어요',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nextVisit == null
                ? '다음 방문일을 예약해 보세요'
                : '다음 방문 예정 ${_fmt(nextVisit!)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                '케어내역 더보기 >',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiReportDetailPage extends StatelessWidget {
  const _AiReportDetailPage({
    required this.shopName,
    required this.chart,
  });

  final String shopName;
  final CustomerChart chart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('AI 리포트 상세'),
        backgroundColor: Colors.white,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            shopName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            chart.careName.isNotEmpty ? chart.careName : '케어 리포트',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              chart.directorInsight.isNotEmpty
                  ? chart.directorInsight
                  : (chart.treatmentSummary.isNotEmpty
                      ? chart.treatmentSummary
                      : '작성된 AI 리포트가 아직 없어요'),
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
