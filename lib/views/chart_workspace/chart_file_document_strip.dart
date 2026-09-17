import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../customer_chart/customer_chart_page.dart';
import '../customer_chart/customer_consent_history_sheet.dart';
import 'chart_workspace_state.dart';

/// 고객 파일철 고정 문서. 방문 rail이 아님. 기존 기능 진입만.
class ChartFileDocumentStrip extends StatelessWidget {
  const ChartFileDocumentStrip({
    super.key,
    required this.store,
    required this.customer,
    required this.fileNumber,
  });

  final SoriStore store;
  final Customer customer;

  /// 파일 rail과 동일한 No.N. 헤더 "No.N · 이름"에 쓰인다.
  final int fileNumber;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileHeaderLabel(fileNumber, customer),
            key: Key('chart-file-title-${customer.id}'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SoriTokens.textCharcoal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _DocIndexEntry(
                key: const Key('chart-doc-consent'),
                label: '전자 동의서',
                onTap: () => _openConsent(context),
              ),
              const _DocIndexDot(),
              _DocIndexEntry(
                key: const Key('chart-doc-photo'),
                label: '사진',
                onTap: () => _openCustomerFile(context),
              ),
              const _DocIndexDot(),
              _DocIndexEntry(
                key: const Key('chart-doc-payment'),
                label: '결제',
                onTap: () => _openCustomerFile(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 파일철에 붙은 고정 문서 인덱스 항목. 액션칩(테두리/채움 박스) 금지 —
/// 밑줄 없는 조용한 텍스트 링크로만 존재한다.
class _DocIndexEntry extends StatelessWidget {
  const _DocIndexEntry({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
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

class _DocIndexDot extends StatelessWidget {
  const _DocIndexDot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: SoriTokens.textQuaternary,
        ),
      ),
    );
  }
}
