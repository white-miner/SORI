import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/whisper.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_nav.dart';
import 'whisper_composer_sheet.dart';

/// Immersive Whisper Inbox — root push (hides FloatingPillNav).
class WhisperInboxPage extends StatefulWidget {
  const WhisperInboxPage({super.key, required this.store});

  final SoriStore store;

  static Future<void> open(BuildContext context, {required SoriStore store}) {
    return pushRootPage<void>(
      context,
      WhisperInboxPage(store: store),
      fullscreenDialog: true,
    );
  }

  @override
  State<WhisperInboxPage> createState() => _WhisperInboxPageState();
}

class _WhisperInboxPageState extends State<WhisperInboxPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshWhisperInbox(box: 'inbox');
      store.refreshWhisperInbox(box: 'sent');
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _tabs.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _compose() async {
    await showWhisperComposer(context, store: store);
    await store.refreshWhisperInbox(box: 'sent');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: SoriTokens.background,
      ),
      child: Scaffold(
        backgroundColor: SoriTokens.background,
        appBar: AppBar(
          backgroundColor: SoriTokens.background,
          foregroundColor: SoriTokens.textPrimary,
          elevation: 0,
          title: const Text(
            '위스퍼',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          actions: [
            TextButton(
              onPressed: _compose,
              child: const Text(
                '속삭이기',
                style: TextStyle(
                  color: SoriTokens.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            labelColor: SoriTokens.textPrimary,
            unselectedLabelColor: SoriTokens.textTertiary,
            indicatorColor: SoriTokens.primary,
            indicatorWeight: 2,
            tabs: [
              Tab(
                text: store.whisperUnreadCount > 0
                    ? '받은 편지 (${store.whisperUnreadCount})'
                    : '받은 편지',
              ),
              const Tab(text: '보낸 편지'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _WhisperList(
              loading: store.whisperLoading && store.whisperInbox.isEmpty,
              items: store.whisperInbox,
              emptyLabel: '아직 도착한 속삭임이 없어요',
              onOpen: (w) async {
                await store.markWhisperRead(w.id);
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => _WhisperOpenDialog(message: w),
                );
              },
              onRefresh: () => store.refreshWhisperInbox(box: 'inbox'),
            ),
            _WhisperList(
              loading: store.whisperLoading && store.whisperSent.isEmpty,
              items: store.whisperSent,
              emptyLabel: '보낸 속삭임이 없어요\n대상을 고르고 마음 편하게 보내보세요',
              onOpen: (w) async {
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => _WhisperOpenDialog(message: w, sent: true),
                );
              },
              onRefresh: () => store.refreshWhisperInbox(box: 'sent'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhisperList extends StatelessWidget {
  const _WhisperList({
    required this.items,
    required this.emptyLabel,
    required this.onOpen,
    required this.onRefresh,
    this.loading = false,
  });

  final List<WhisperMessage> items;
  final String emptyLabel;
  final ValueChanged<WhisperMessage> onOpen;
  final Future<void> Function() onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }
    return RefreshIndicator(
      color: SoriTokens.primary,
      onRefresh: onRefresh,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 64, 28, 40),
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  size: 40,
                  color: SoriTokens.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  emptyLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final w = items[i];
                return _SealedRow(message: w, onTap: () => onOpen(w));
              },
            ),
    );
  }
}

class _SealedRow extends StatelessWidget {
  const _SealedRow({required this.message, required this.onTap});

  final WhisperMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sealed = message.isUnread;
    return Material(
      color: sealed ? const Color(0xFF121214) : SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Icon(
                sealed
                    ? Icons.mail_rounded
                    : Icons.mark_email_read_outlined,
                color: sealed ? SoriTokens.primary : SoriTokens.textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.box == 'sent'
                          ? '${message.recipientCount}명에게 속삭임'
                          : message.senderNickname,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: sealed
                            ? SoriTokens.textPrimary
                            : SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sealed && message.box == 'inbox'
                          ? '봉인된 속삭임 · 탭하여 열기'
                          : message.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: sealed
                            ? SoriTokens.textTertiary
                            : SoriTokens.textSecondary,
                        fontWeight:
                            sealed ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhisperOpenDialog extends StatelessWidget {
  const _WhisperOpenDialog({required this.message, this.sent = false});

  final WhisperMessage message;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SoriTokens.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sent ? '보낸 속삭임' : '${message.senderNickname}의 속삭임',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: SoriTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message.body,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: SoriTokens.textPrimary,
              ),
            ),
            if (sent) ...[
              const SizedBox(height: 12),
              Text(
                '수신 ${message.recipientCount}명'
                '${message.truncated ? ' · 상한 적용' : ''}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: SoriTokens.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '닫기',
                  style: TextStyle(
                    color: SoriTokens.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
