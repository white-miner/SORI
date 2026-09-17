import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import '../views/message_history_page.dart';

/// Supporter 알림 — S-C 이후 통합 종 인박스로 위임.
Future<void> showSupporterNotificationsSheet(
  BuildContext context, {
  required SoriStore store,
}) async {
  await store.refreshShopNotifications();
  await store.refreshShopSponsorshipImpact();
  if (!context.mounted) return;

  await pushRootPage<void>(
    context,
    Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('알림'),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: MessageHistoryPage(embedded: true, store: store),
    ),
  );
}
