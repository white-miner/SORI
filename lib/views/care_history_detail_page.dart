import 'package:flutter/material.dart';

import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 고객 케어 내역 상세 — 간단히/자세히 토글.
class CareHistoryDetailPage extends StatefulWidget {
  const CareHistoryDetailPage({
    super.key,
    required this.store,
    this.customerId,
  });

  final SoriStore store;
  final String? customerId;

  @override
  State<CareHistoryDetailPage> createState() => _CareHistoryDetailPageState();
}

class _CareHistoryDetailPageState extends State<CareHistoryDetailPage> {
  bool _detailed = false;

  @override
  Widget build(BuildContext context) {
    final customerId =
        widget.customerId ?? widget.store.session?.customerId;
    final charts = customerId == null
        ? <CustomerChart>[]
        : widget.store.chartsForCustomer(customerId).toList()
      ..sort((a, b) => b.visitNumber.compareTo(a.visitNumber));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('케어 내역'),
        backgroundColor: Colors.white,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => setState(() => _detailed = !_detailed),
            child: Text(
              _detailed ? '자세히 ∧' : '간단히 ∨',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: SoriTokens.primary,
              ),
            ),
          ),
        ],
      ),
      body: charts.isEmpty
          ? Center(
              child: Text(
                '아직 케어 내역이 없어요',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                if (!_detailed) ...[
                  _SimpleStepper(charts: charts),
                  const SizedBox(height: 16),
                ],
                ...charts.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VisitCard(chart: c, detailed: _detailed),
                  );
                }),
              ],
            ),
    );
  }
}

class _SimpleStepper extends StatelessWidget {
  const _SimpleStepper({required this.charts});

  final List<CustomerChart> charts;

  @override
  Widget build(BuildContext context) {
    // 예정 → 최신회차 → … → 1회차 순으로 표시
    final steps = <({String label, bool upcoming})>[
      (label: '예정', upcoming: true),
      ...charts.map((c) => (label: '${c.visitNumber}회차', upcoming: false)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Container(
                  width: 28,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: SoriTokens.border,
                ),
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: steps[i].upcoming
                          ? const Color(0xFFEEF2FF)
                          : SoriTokens.primarySoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: steps[i].upcoming
                            ? const Color(0xFFA5B4FC)
                            : SoriTokens.primary,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      steps[i].upcoming ? '·' : '${charts[i - 1].visitNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: steps[i].upcoming
                            ? const Color(0xFF6366F1)
                            : SoriTokens.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i].label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.chart, required this.detailed});

  final CustomerChart chart;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final title =
        chart.careName.isNotEmpty ? chart.careName : chart.treatmentSummary;
    final date = chart.visitCheckedAt ?? chart.createdAt;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
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
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: SoriTokens.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${chart.visitNumber}회차',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title.isEmpty ? '케어 기록' : title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            if (date != null) ...[
              const SizedBox(height: 6),
              Text(
                _fmt(date),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (detailed) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _DetailLine(
                label: '사용 제품 / 시술 요약',
                value: chart.treatmentSummary.isNotEmpty
                    ? chart.treatmentSummary
                    : (chart.careName.isNotEmpty
                        ? chart.careName
                        : '기록 없음'),
              ),
              const SizedBox(height: 10),
              _DetailLine(
                label: '원장 인사이트',
                value: chart.directorInsight.isNotEmpty
                    ? chart.directorInsight
                    : '작성된 코멘트가 없어요',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BaThumb(
                      label: 'Before',
                      url: chart.beforeImageUrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BaThumb(
                      label: 'After',
                      url: chart.afterImageUrl,
                    ),
                  ),
                ],
              ),
              if (chart.concernChips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chart.concernChips
                      .map(
                        (c) => Chip(
                          label: Text(c, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: SoriTokens.primarySoft,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, height: 1.45),
        ),
      ],
    );
  }
}

class _BaThumb extends StatelessWidget {
  const _BaThumb({required this.label, required this.url});

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final has = url != null && url!.trim().isNotEmpty;
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: SoriTokens.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoriTokens.border),
        image: has
            ? DecorationImage(
                image: NetworkImage(url!),
                fit: BoxFit.cover,
                onError: (_, _) {},
              )
            : null,
      ),
      child: has
          ? Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hide_image_outlined, color: SoriTokens.primary),
                const SizedBox(height: 6),
                Text(
                  '$label 없음',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.primary,
                  ),
                ),
              ],
            ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
