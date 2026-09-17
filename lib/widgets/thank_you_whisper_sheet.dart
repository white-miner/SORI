import 'package:flutter/material.dart';

import '../models/my_boost_gift.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// 원장 — 후원자에게 감사 위스퍼 보내기.
Future<bool> showThankYouWhisperSheet(
  BuildContext context, {
  required SoriStore store,
  required SupporterNotificationItem notification,
}) async {
  final giftId = notification.fanGiftId?.trim() ?? '';
  if (giftId.isEmpty || notification.hasThankYou) return false;

  final name = notification.supporterName.trim().isEmpty
      ? '후원자'
      : notification.supporterName.trim();
  final defaultBody = '$name님, 후원해 주셔서 감사합니다!';
  final ctrl = TextEditingController(text: defaultBody);

  final sent = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      var busy = false;
      return StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              16 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SoriTokens.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '감사 위스퍼',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '$name님에게만 전달됩니다.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SoriTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: '감사 메시지를 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setModal(() => busy = true);
                          try {
                            await store.sendThankYouWhisperForGift(
                              fanGiftId: giftId,
                              body: ctrl.text,
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (_) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('감사 위스퍼 전송에 실패했습니다.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setModal(() => busy = false);
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('보내기'),
                ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx, false),
                  child: const Text('닫기'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  ctrl.dispose();
  return sent == true;
}
