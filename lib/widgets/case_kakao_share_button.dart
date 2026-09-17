import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/sori_tokens.dart';

/// E4-lite — AI 마케팅 카피를 카카오톡 등으로 원탭 공유.
Future<void> shareMarketingCopyToKakao(
  BuildContext context, {
  required String title,
  required String body,
  String? shopName,
}) async {
  final shop = (shopName ?? '').trim();
  final header = shop.isEmpty ? title.trim() : '$shop · ${title.trim()}';
  final text = [
    if (header.isNotEmpty) header,
    if (body.trim().isNotEmpty) body.trim(),
    '',
    '#SORI #피부관리 #BeforeAfter',
  ].join('\n');

  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;

  try {
    await Share.share(
      text,
      subject: header.isEmpty ? '케이스 마케팅 카피' : header,
    );
  } catch (_) {
    // Clipboard fallback is enough on web.
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('카피를 복사했어요. 카카오톡에 붙여넣어 보내세요.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: SoriTokens.primary,
    ),
  );
}

/// AI 툴 시트용 카톡 공유 버튼.
class CaseKakaoShareButton extends StatelessWidget {
  const CaseKakaoShareButton({
    super.key,
    required this.title,
    required this.body,
    this.shopName,
  });

  final String title;
  final String body;
  final String? shopName;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: body.trim().isEmpty
          ? null
          : () => shareMarketingCopyToKakao(
                context,
                title: title,
                body: body,
                shopName: shopName,
              ),
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: const Text('카톡 공유'),
    );
  }
}
