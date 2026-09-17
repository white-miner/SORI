import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/customer_chart.dart';
import '../models/kakao_alimtalk.dart';
import '../services/sori_share.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'kakao_alimtalk_actions.dart';
import 'my_app.dart';

Future<void> showCustomerLinkPopup(
  BuildContext context, {
  required CustomerChart chart,
  required SoriStore store,
}) async {
  final token = chart.feedbackToken;
  if (token == null) return;
  final url = SoriStore.buildCustomerReviewUrl(token);
  final careUrl = SoriStore.buildCareReportUrl(chart.id);
  final customer = store.findCustomer(chart.customerId);
  final care = chart.careName.isNotEmpty ? chart.careName : '케어';
  final customerName = customer?.name ?? '고객';
  final phone = customer?.phone ?? '';

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('후기 요청 QR'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '고객 휴대폰으로 스캔하면 카카오 로그인 후 후기 작성으로 이동합니다\n$url',
                style: const TextStyle(
                  fontSize: 12,
                  color: SoriTokens.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SoriTokens.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SoriTokens.outlinePurple),
                ),
                child: QrImageView(
                  data: url,
                  size: 160,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '잔여 알림톡 포인트 ${store.shop.kakaoPoint}P · 발송 ${KakaoAlimtalkPricing.sendCostPoint}P',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textSecondary,
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
          TextButton(
            onPressed: () async {
              final body = buildCareReportAlimtalkBody(
                chart: chart,
                customerName: customerName,
                shopName: store.shop.name,
              );
              final ok = await sendKakaoAlimtalkWithUi(
                ctx,
                store: store,
                customerPhone: phone,
                content: '$body\n(케어 리포트: $careUrl)',
                templateCode: KakaoAlimtalkPricing.careReportTemplate,
              );
              if (ok && ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('카카오톡 발송'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await SoriShare.shareReviewLink(
                url: url,
                customerName: customerName,
                careName: care,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple, foregroundColor: SoriTokens.onPrimary),
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
