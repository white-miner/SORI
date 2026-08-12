import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer_chart.dart';
import '../models/kakao_alimtalk.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 포인트 검사 → 차감/로그 → Toast. 부족 시 AlertDialog.
Future<bool> sendKakaoAlimtalkWithUi(
  BuildContext context, {
  required SoriStore store,
  required String customerPhone,
  required String content,
  String templateCode = KakaoAlimtalkPricing.careReportTemplate,
}) async {
  final result = await store.sendKakaoAlimtalk(
    customerPhone: customerPhone,
    content: content,
    templateCode: templateCode,
  );

  if (!context.mounted) return false;

  if (result.isInsufficientPoints) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('알림톡 포인트 부족'),
        content: const Text('알림톡 포인트가 부족합니다. 충전 후 이용해 주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return false;
  }

  if (!result.ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? '알림톡 발송에 실패했습니다.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
    return false;
  }

  final remain = result.remainingPoints ?? store.shop.kakaoPoint;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('카카오톡 케어 메시지를 발송했습니다. (잔여 ${remain}P)'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: SoriTokens.primary,
    ),
  );
  return true;
}

/// 차트 저장 후 / 리포트용 케어 리포트 알림톡 본문.
String buildCareReportAlimtalkBody({
  required CustomerChart chart,
  required String customerName,
  required String shopName,
}) {
  final care = chart.careName.trim().isEmpty ? '오늘의 케어' : chart.careName.trim();
  final url = SoriStore.buildCareReportUrl(chart.id);
  return '$customerName 고객님, 오늘 $care 잘 받으셨죠?\n'
      '$shopName에서 준비한 케어 리포트를 확인해 주세요.\n'
      '· 오늘의 케어 내용 / B·A 사진\n'
      '· 3일 홈케어 미션\n'
      '$url';
}

Future<void> showInsufficientKakaoPointDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('알림톡 포인트 부족'),
      content: const Text('알림톡 포인트가 부족합니다. 충전 후 이용해 주세요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

Future<void> copyKakaoMessage(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('케어 메시지 문구를 복사했어요'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: SoriTokens.primary,
    ),
  );
}
