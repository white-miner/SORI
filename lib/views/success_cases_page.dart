import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/sori_card.dart';

/// 성공 사례 — 동의된 차트의 Before/After 비교 + 태그 검색.
class SuccessCasesPage extends StatefulWidget {
  const SuccessCasesPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<SuccessCasesPage> createState() => _SuccessCasesPageState();
}

class _SuccessCasesPageState extends State<SuccessCasesPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _searchController.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  /// 초상권 활용 동의(마케팅 또는 원내 기록)가 있는 차트만.
  bool _hasPortraitConsent(CustomerChart chart) =>
      chart.consentMarketing || chart.consentOfflineOnly;

  bool _hasComparableImages(CustomerChart chart) {
    final b = chart.beforeImageUrl?.trim() ?? '';
    final a = chart.afterImageUrl?.trim() ?? '';
    return b.isNotEmpty || a.isNotEmpty;
  }

  List<String> _searchTokens(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .map((t) => t.replaceFirst(RegExp(r'^#+'), '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  String _haystack(CustomerChart chart, Customer? customer) {
    final parts = <String>[
      chart.careName,
      chart.treatmentSummary,
      chart.directorInsight,
      chart.allergyNotes,
      chart.skinSensitivity,
      chart.sideEffectHistory,
      chart.customerRequests,
      ...chart.concernChips,
      ...chart.firstVisitFearChips,
      ...chart.revisitFeedbackChips,
      if (customer != null) customer.name,
      if (customer != null) customer.treatmentType,
    ];
    return parts.join(' ').toLowerCase();
  }

  List<({CustomerChart chart, Customer? customer})> get _cases {
    final tokens = _searchTokens(_query);
    final out = <({CustomerChart chart, Customer? customer})>[];
    for (final chart in widget.store.charts) {
      if (!_hasPortraitConsent(chart)) continue;
      if (!_hasComparableImages(chart)) continue;
      final customer = widget.store.findCustomer(chart.customerId);
      if (tokens.isNotEmpty) {
        final hay = _haystack(chart, customer);
        final ok = tokens.every((t) => hay.contains(t));
        if (!ok) continue;
      }
      out.add((chart: chart, customer: customer));
    }
    out.sort((a, b) {
      final ad = a.chart.visitCheckedAt ??
          a.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.chart.visitCheckedAt ??
          b.chart.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cases = _cases;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '마케팅·원내 활용 동의를 받은 차트만 표시됩니다',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: '#홍조 #테라노바 증상·시술명 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: cases.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        _query.trim().isEmpty
                            ? '동의된 Before/After 사례가 아직 없습니다.\n차트에 사진과 초상권 동의를 남겨 주세요.'
                            : '검색 조건에 맞는 동의 사례가 없습니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: SoriTokens.textSecondary,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: cases.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cases[index];
                      final chart = item.chart;
                      final customer = item.customer;
                      final title = chart.careName.isNotEmpty
                          ? chart.careName
                          : (chart.treatmentSummary.isNotEmpty
                              ? chart.treatmentSummary
                              : '시술 사례');
                      final tags = <String>[
                        ...chart.concernChips.take(3),
                        if (chart.careName.isNotEmpty) chart.careName,
                      ];
                      return SoriCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (customer != null) customer.name,
                                '${chart.visitNumber}회차',
                                if (chart.consentMarketing) '마케팅 동의',
                                if (chart.consentOfflineOnly) '원내 기록',
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: SoriTokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            BeforeAfterSlider(
                              height: 220,
                              before: ChartImagePane(
                                url: chart.beforeImageUrl,
                                fallbackLabel: 'Before',
                                tone: SoriTokens.primary,
                              ),
                              after: ChartImagePane(
                                url: chart.afterImageUrl,
                                fallbackLabel: 'After',
                                tone: Colors.green.shade700,
                              ),
                            ),
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: tags
                                    .map(
                                      (t) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: SoriTokens.primarySoft,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '#$t',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: SoriTokens.primary,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
