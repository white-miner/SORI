import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../customer_chart/customer_chart_page.dart';
import '../customer_chart/customer_consent_history_sheet.dart';

/// 고객 파일철 고정 문서. 방문 rail이 아님. 기존 기능 진입만.
class ChartFileDocumentStrip extends StatelessWidget {
  const ChartFileDocumentStrip({
    super.key,
    required this.store,
    required this.customer,
  });

  final SoriStore store;
  final Customer customer;

  Future<void> _openConsent(BuildContext context) async {
    await showCustomerConsentHistorySheet(
      context: context,
      store: store,
      customer: customer,
    );
  }

  Future<void> _openCustomerFile(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            CustomerChartPage(store: store, customerId: customer.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              customer.name,
              key: Key('chart-file-title-${customer.id}'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textCharcoal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _DocChip(
            key: const Key('chart-doc-consent'),
            label: '동의서',
            onTap: () => _openConsent(context),
          ),
          const SizedBox(width: 6),
          _DocChip(
            key: const Key('chart-doc-photo'),
            label: '사진',
            onTap: () => _openCustomerFile(context),
          ),
          const SizedBox(width: 6),
          _DocChip(
            key: const Key('chart-doc-payment'),
            label: '결제',
            onTap: () => _openCustomerFile(context),
          ),
        ],
      ),
    );
  }
}

class _DocChip extends StatelessWidget {
  const _DocChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: SoriTokens.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD6D3D1)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: SoriTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
