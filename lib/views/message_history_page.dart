import 'package:flutter/material.dart';

import '../models/my_boost_gift.dart';
import '../models/session_user.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sponsorship_impact_summary_card.dart';
import '../widgets/thank_you_whisper_sheet.dart';

/// 통합 알림 인박스 — 종 아이콘 (S-C). Supporter 알림 흡수.
class MessageHistoryPage extends StatefulWidget {
  const MessageHistoryPage({
    super.key,
    this.embedded = false,
    this.store,
  });

  /// AppBar가 이미 있는 라우트에 임베드할 때 SafeArea/타이틀 중복 방지.
  final bool embedded;
  final SoriStore? store;

  @override
  State<MessageHistoryPage> createState() => _MessageHistoryPageState();
}

class _MessageHistoryPageState extends State<MessageHistoryPage> {
  SoriStore get store => widget.store ?? SoriStore.instance;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final session = store.session;
    if (session?.activeMode == UserRole.director) {
      await store.refreshShopNotifications();
      await store.refreshShopSponsorshipImpact();
    } else if (session?.customerId != null) {
      await store.refreshMyBoostGifts();
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  SupporterNotificationItem? _supporterFor(String id) {
    for (final n in store.supporterNotifications) {
      if (n.id == id) return n;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = store.session;
    final isDirector = session?.activeMode == UserRole.director;

    final body = RefreshIndicator(
      onRefresh: _reload,
      color: SoriTokens.primary,
      child: _loading
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            )
          : isDirector
              ? _DirectorInbox(
                  store: store,
                  supporterFor: _supporterFor,
                  onThankSent: _reload,
                )
              : _CustomerInbox(store: store),
    );

    if (widget.embedded) return body;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '알림',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '새로고침',
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _DirectorInbox extends StatelessWidget {
  const _DirectorInbox({
    required this.store,
    required this.supporterFor,
    required this.onThankSent,
  });

  final SoriStore store;
  final SupporterNotificationItem? Function(String id) supporterFor;
  final Future<void> Function() onThankSent;

  @override
  Widget build(BuildContext context) {
    final rows = store.shopNotifications;
    final pending = store.supporterNotifications.where((e) => e.canThank).length;

    if (rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (store.shopSponsorshipImpact.echoTotal > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SponsorshipImpactSummaryCard(
                impact: store.shopSponsorshipImpact,
              ),
            ),
          const SizedBox(height: 48),
          const Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: SoriTokens.textSecondary,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              '새 알림이 없어요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, widgetPaddingTop(context), 16, 32),
      children: [
        if (pending > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x22F472B6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SoriTokens.border),
              ),
              child: Text(
                'Supporter 감사 Whisper 대기 $pending건',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ),
          ),
        if (store.shopSponsorshipImpact.echoTotal > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SponsorshipImpactSummaryCard(
              impact: store.shopSponsorshipImpact,
            ),
          ),
        ...rows.map((raw) {
          final id = raw['id']?.toString() ?? '';
          final kind = raw['kind']?.toString() ?? 'system';
          final title = raw['title']?.toString().trim() ?? '';
          final body = raw['body']?.toString().trim() ?? '';
          final created = DateTime.tryParse(
            raw['created_at']?.toString() ?? '',
          );
          final supporter = _isSupporterKind(kind) ? supporterFor(id) : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NotificationTile(
              icon: _iconForKind(kind),
              iconColor: _colorForKind(kind),
              title: title.isNotEmpty ? title : _defaultTitle(kind),
              body: body,
              time: created,
              trailing: supporter != null && supporter.canThank
                  ? TextButton.icon(
                      onPressed: () async {
                        final ok = await showThankYouWhisperSheet(
                          context,
                          store: store,
                          notification: supporter,
                        );
                        if (ok) await onThankSent();
                      },
                      icon: const Icon(Icons.mail_outline_rounded, size: 18),
                      label: const Text('Thank Whisper'),
                    )
                  : supporter != null && supporter.hasThankYou
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: SoriTokens.textSecondary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Sent',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: SoriTokens.textSecondary,
                              ),
                            ),
                          ],
                        )
                      : null,
            ),
          );
        }),
      ],
    );
  }

  double widgetPaddingTop(BuildContext context) => 8;

  bool _isSupporterKind(String kind) =>
      kind == 'fan_boost' || kind == 'special_supporter';

  IconData _iconForKind(String kind) => switch (kind) {
        'fan_boost' || 'special_supporter' => Icons.volunteer_activism_outlined,
        'whisper' => Icons.lock_outline_rounded,
        'case_bookmark' => Icons.bookmark_outline_rounded,
        'market_inquiry' => Icons.storefront_outlined,
        'like' => Icons.favorite_outline_rounded,
        'comment' => Icons.chat_bubble_outline_rounded,
        'tip' => Icons.payments_outlined,
        _ => Icons.notifications_none_rounded,
      };

  Color _colorForKind(String kind) => switch (kind) {
        'fan_boost' || 'special_supporter' => const Color(0xFFF472B6),
        'whisper' => SoriTokens.primary,
        'market_inquiry' => SoriTokens.warningText,
        _ => SoriTokens.textSecondary,
      };

  String _defaultTitle(String kind) => switch (kind) {
        'fan_boost' => 'Supporter Boost',
        'special_supporter' => 'Special Supporter',
        'whisper' => 'Whisper',
        'case_bookmark' => 'Case Bookmark',
        'market_inquiry' => 'Market Inquiry',
        _ => '알림',
      };
}

class _CustomerInbox extends StatelessWidget {
  const _CustomerInbox({required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final cid = store.session?.customerId;
    final reviewPending =
        cid != null && store.isReviewRequested(cid);
    final gifts = store.myBoostGifts;

    if (!reviewPending && gifts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 48),
          Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: SoriTokens.textSecondary,
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              '새 알림이 없어요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (reviewPending)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _NotificationTile(
              icon: Icons.rate_review_outlined,
              iconColor: SoriTokens.primary,
              title: '리뷰 작성 요청',
              body: '방문하신 샵에서 리뷰를 요청했어요.',
            ),
          ),
        ...gifts.take(20).map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotificationTile(
                  icon: Icons.volunteer_activism_outlined,
                  iconColor: Color(0xFFF472B6),
                  title: g.hasThankYou
                      ? 'Thank Whisper 도착'
                      : 'My Supporter · ${g.caseTitle}',
                  body: g.hasThankYou
                      ? '${g.shopName}에서 감사 Whisper를 보냈어요.'
                      : '${g.echoSpent}E · ${g.shopName}',
                  time: g.createdAt,
                ),
              ),
            ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.body = '',
    this.time,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final DateTime? time;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SoriTokens.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (time != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(time!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${t.month}/${t.day}';
  }
}
