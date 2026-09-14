import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/customer_consent_archive.dart';
import '../consent_pdf_preview_sheet.dart';

/// 고객 파일철 전자 동의서 이력 (읽기 전용). 신규 동의 CTA 없음.
Future<void> showCustomerConsentHistorySheet({
  required BuildContext context,
  required SoriStore store,
  required Customer customer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _CustomerConsentHistorySheet(
      store: store,
      customer: customer,
    ),
  );
}

class _CustomerConsentHistorySheet extends StatelessWidget {
  const _CustomerConsentHistorySheet({
    required this.store,
    required this.customer,
  });

  final SoriStore store;
  final Customer customer;

  String _fmt(DateTime? d) {
    if (d == null) return '날짜 미상';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y.$m.$day';
  }

  @override
  Widget build(BuildContext context) {
    final snap = CustomerConsentArchive.snapshot(
      customerId: customer.id,
      charts: store.charts,
    );
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SoriTokens.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '전자 동의서',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${snap.statusLabel} · ${snap.countLabel}',
                key: const Key('customer-consent-history-summary'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: snap.history.isEmpty
                ? const Center(
                    child: Text(
                      '서명된 동의서가 없습니다.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 16 + bottom),
                    itemCount: snap.history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final chart = snap.history[i];
                      return _HistoryTile(
                        chart: chart,
                        createdLabel: _fmt(chart.createdAt),
                        valid: CustomerConsentArchive.isCurrentlyValid(chart),
                        onOpen: () => showConsentPdfPreviewModal(
                          context: context,
                          store: store,
                          customer: customer,
                          chart: chart,
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.chart,
    required this.createdLabel,
    required this.valid,
    required this.onOpen,
  });

  final CustomerChart chart;
  final String createdLabel;
  final bool valid;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final care = chart.careName.trim();
    final hasPdf = CustomerConsentArchive.hasStoredPdf(chart);
    return Material(
      color: SoriTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        key: Key('customer-consent-history-item-${chart.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      createdLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        valid ? '유효' : '만료',
                        hasPdf ? '저장된 PDF' : '서명',
                        if (care.isNotEmpty) care,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.picture_as_pdf_outlined,
                color: SoriTokens.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
