import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/customer_chart.dart';
import '../services/sori_share.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'my_app.dart';

Future<void> showCustomerLinkPopup(
  BuildContext context, {
  required CustomerChart chart,
  required SoriStore store,
}) async {
  final token = chart.feedbackToken;
  if (token == null) return;
  final url = SoriStore.buildCustomerReviewUrl(token);
  final customer = store.findCustomer(chart.customerId);
  final care = chart.careName.isNotEmpty ? chart.careName : '케어';

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('고객 전용 1:1 링크'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '해시 딥링크 (GitHub Pages 404 방지)\n$url',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F1FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: url,
                  size: 160,
                  backgroundColor: Colors.white,
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
          FilledButton.icon(
            onPressed: () async {
              await SoriShare.shareReviewLink(
                url: url,
                customerName: customer?.name ?? '고객',
                careName: care,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple),
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('링크 공유하기'),
          ),
        ],
      );
    },
  );
}

/// 케어/리뷰 화면용 공유 버튼.
class ShareLinkButton extends StatelessWidget {
  const ShareLinkButton({
    super.key,
    required this.url,
    this.customerName = '고객',
    this.careName,
    this.compact = false,
  });

  final String url;
  final String customerName;
  final String? careName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: '링크 공유하기',
        onPressed: () => SoriShare.shareReviewLink(
          url: url,
          customerName: customerName,
          careName: careName,
        ),
        icon: const Icon(Icons.ios_share_rounded, color: SoriTokens.primary),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => SoriShare.shareReviewLink(
        url: url,
        customerName: customerName,
        careName: careName,
      ),
      icon: const Icon(Icons.ios_share_rounded, size: 18),
      label: const Text(
        '링크 공유하기',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: SoriTokens.primary,
        side: const BorderSide(color: SoriTokens.primary),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
