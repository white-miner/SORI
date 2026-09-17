import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/sori_store.dart';
import 'customer_link_popup.dart';

/// 후기 요청 = 이벤트 기록 + feedbackToken QR 팝업 원클릭.
Future<void> requestCustomerReviewWithQr(
  BuildContext context, {
  required SoriStore store,
  required Customer customer,
  String channel = 'qr',
}) async {
  final chart = store.latestChart(customer.id);
  final token = chart?.feedbackToken?.trim() ?? '';
  if (chart == null || token.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('리뷰 링크가 아직 없어요. 방문 확인(차트) 후 다시 시도해 주세요.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  await store.recordReviewRequest(
    customerId: customer.id,
    chartId: chart.id,
    channel: channel,
  );
  if (!context.mounted) return;
  await showCustomerLinkPopup(
    context,
    chart: chart,
    store: store,
  );
}
