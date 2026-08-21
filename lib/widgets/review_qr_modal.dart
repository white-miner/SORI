import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/sori_share.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 원장용 — 샵 리뷰 진입 QR 생성/공유 모달.
Future<void> showShopReviewQrModal(
  BuildContext context, {
  required SoriStore store,
  String? reviewUrl,
}) async {
  final url = reviewUrl ?? SoriStore.buildAppEntryUrl();
  final shopName = store.shop.name;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SoriTokens.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'QR 코드 · 고객 리뷰 페이지',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SoriTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              shopName,
              style: const TextStyle(
                fontSize: 13,
                color: SoriTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SoriTokens.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SoriTokens.border),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: SoriTokens.primary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0A0A0C),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              url,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: SoriTokens.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('QR 링크를 복사했어요'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: SoriTokens.primary,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('링크 복사'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await SoriShare.shareShopEntry(
                        shopName: shopName,
                        url: url,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('공유/다운로드'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
