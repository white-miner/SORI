import 'package:flutter/material.dart';

import '../models/my_boost_gift.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'thank_you_whisper_sheet.dart';

/// 원장 — 후원 알림 인박스 + 감사 위스퍼 숏컷.
Future<void> showSupporterNotificationsSheet(
  BuildContext context, {
  required SoriStore store,
}) async {
  await store.refreshShopNotifications();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return _SupporterNotificationsSheet(store: store);
    },
  );
}

class _SupporterNotificationsSheet extends StatefulWidget {
  const _SupporterNotificationsSheet({required this.store});

  final SoriStore store;

  @override
  State<_SupporterNotificationsSheet> createState() =>
      _SupporterNotificationsSheetState();
}

class _SupporterNotificationsSheetState
    extends State<_SupporterNotificationsSheet> {
  SoriStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final items = store.supporterNotifications;
    final pending = items.where((e) => e.canThank).length;
    final h = MediaQuery.sizeOf(context).height * 0.65;

    return SafeArea(
      child: SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '후원 알림',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (pending > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x22F472B6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '감사 대기 $pending',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: SoriTokens.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '후원자에게 감사 위스퍼를 내면 1:1로 전달됩니다.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        '아직 후원 알림이 없어요.',
                        style: TextStyle(color: SoriTokens.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final n = items[i];
                        return Material(
                          color: SoriTokens.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.body.trim().isEmpty ? n.title : n.body,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (n.hasThankYou)
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: SoriTokens.textSecondary,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '감사 위스퍼 전송 완료',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: SoriTokens.textSecondary,
                                        ),
                                      ),
                                    ],
                                  )
                                else if (n.canThank)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        final ok =
                                            await showThankYouWhisperSheet(
                                          context,
                                          store: store,
                                          notification: n,
                                        );
                                        if (ok && mounted) {
                                          await store
                                              .refreshShopNotifications();
                                          setState(() {});
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.mail_outline_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('감사 위스퍼'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
