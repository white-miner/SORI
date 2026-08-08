import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import 'my_app.dart';

Future<void> showCustomerLinkPopup(
  BuildContext context, {
  required CustomerChart chart,
  required SoriStore store,
}) async {
  final token = chart.feedbackToken;
  if (token == null) return;
  final url = SoriStore.buildCustomerReviewUrl(token);

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('고객 전용 1:1 링크 생성'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '해시 딥링크 (GitHub Pages 404 방지)\n$url',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${Uri.encodeComponent(url)}',
                  width: 140,
                  height: 140,
                  errorBuilder: (_, _, _) => Container(
                    width: 140,
                    height: 140,
                    color: const Color(0xFFF3F1FB),
                    alignment: Alignment.center,
                    child: const Text('QR', style: TextStyle(color: MyApp.soriPurple, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('링크가 복사되었습니다.'),
                    backgroundColor: MyApp.soriPurple,
                  ),
                );
              }
            },
            child: const Text('링크 복사'),
          ),
          FilledButton(
            onPressed: () async {
              final customer = store.findCustomer(chart.customerId);
              final body =
                  '${customer?.name ?? '고객'}님, 오늘 시술 리포트입니다.\n$url';
              await Clipboard.setData(ClipboardData(text: body));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('문자 초안을 복사했습니다.'),
                    backgroundColor: MyApp.soriPurple,
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple),
            child: const Text('문자 발송'),
          ),
        ],
      );
    },
  );
}
