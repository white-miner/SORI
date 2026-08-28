import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/community_post.dart';
import '../models/customer_chart.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/consent_publish_gate.dart';
import 'ai_tool_sheet.dart';

/// 마이페이지 게시물 지표 — B/A · Whisper · Review 허브.
Future<void> showShopPostsHubSheet(
  BuildContext context, {
  required SoriStore store,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ShopPostsHubSheet(store: store),
  );
}

class _ShopPostsHubSheet extends StatefulWidget {
  const _ShopPostsHubSheet({required this.store});

  final SoriStore store;

  @override
  State<_ShopPostsHubSheet> createState() => _ShopPostsHubSheetState();
}

class _ShopPostsHubSheetState extends State<_ShopPostsHubSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.78;
    return SafeArea(
      child: SizedBox(
        height: h,
        child: Column(
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '게시물',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: SoriTokens.primary,
              unselectedLabelColor: SoriTokens.textSecondary,
              indicatorColor: SoriTokens.primary,
              tabs: const [
                Tab(text: 'B/A'),
                Tab(text: 'Whisper'),
                Tab(text: 'Review'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _BaPostsPane(store: widget.store),
                  _WhisperPostsPane(store: widget.store),
                  _ReviewPostsPane(store: widget.store),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BaPostsPane extends StatelessWidget {
  const _BaPostsPane({required this.store});

  final SoriStore store;

  List<CustomerChart> get _published {
    return store.charts
        .where(
          (c) =>
              c.caseShared &&
              canPublishBa(c).allowsPublish &&
              ((c.beforeImageUrl?.trim().isNotEmpty ?? false) ||
                  (c.afterImageUrl?.trim().isNotEmpty ?? false)),
        )
        .toList();
  }

  List<CustomerChart> get _drafts {
    return store.charts
        .where(
          (c) =>
              !c.caseShared &&
              ((c.beforeImageUrl?.trim().isNotEmpty ?? false) ||
                  (c.afterImageUrl?.trim().isNotEmpty ?? false)),
        )
        .toList();
  }

  Future<void> _tryPublish(BuildContext context, CustomerChart chart) async {
    final gate = canPublishBa(chart);
    if (!gate.allowsPublish) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SoriTokens.surface,
          title: const Text('SNS consent required'),
          content: Text(gate.alertMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (go == true && context.mounted) {
        Navigator.pop(context); // close hub
        final cid = chart.customerId.trim();
        if (cid.isNotEmpty) {
          context.go('${AppPaths.appCustomers}/$cid');
        }
      }
      return;
    }

    final customer = store.findCustomer(chart.customerId);
    if (!context.mounted) return;
    await showAiToolSheet(
      context: context,
      store: store,
      chart: chart,
      customer: customer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final published = _published;
    final drafts = _drafts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          '발행됨',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (published.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '발행된 B/A 게시물이 없어요.',
              style: TextStyle(
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...published.map(
            (c) => _ChartRow(
              chart: c,
              trailing: const PillBadge(
                label: '발행됨',
                tone: PillTone.ok,
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          '발행 준비',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (drafts.isEmpty)
          const Text(
            '발행 준비 중인 차트가 없어요.',
            style: TextStyle(
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          ...drafts.map((c) {
            final gate = canPublishBa(c);
            return _ChartRow(
              chart: c,
              trailing: PillBadge(
                label: gate.badgeLabel,
                tone: gate.allowsPublish ? PillTone.ok : PillTone.warn,
              ),
              onTap: () => _tryPublish(context, c),
            );
          }),
      ],
    );
  }
}

class _WhisperPostsPane extends StatelessWidget {
  const _WhisperPostsPane({required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final posts = store.communityPosts
        .where((p) => p.isWhisper && p.shopId == store.shop.id)
        .toList();
    if (posts.isEmpty) {
      return const Center(
        child: Text(
          'Whisper가 없어요.',
          style: TextStyle(
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: posts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = posts[i];
        return ListTile(
          tileColor: SoriTokens.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: SoriTokens.border),
          ),
          title: Text(
            p.title.trim().isEmpty ? 'Whisper' : p.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            p.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

class _ReviewPostsPane extends StatelessWidget {
  const _ReviewPostsPane({required this.store});

  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final posts = store.communityPosts.where((p) {
      if (p.shopId != store.shop.id) return false;
      if (p.isWhisper) return false;
      return p.postType == CommunityPostType.deviceReview ||
          p.postType == CommunityPostType.interior ||
          p.postType == CommunityPostType.marketplace;
    }).toList();

    if (posts.isEmpty) {
      return const Center(
        child: Text(
          '원장 Review 게시물이 없어요.',
          style: TextStyle(
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: posts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = posts[i];
        return ListTile(
          tileColor: SoriTokens.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: SoriTokens.border),
          ),
          title: Text(
            p.title.trim().isEmpty ? p.postType.name : p.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            p.postType.label,
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

class _ChartRow extends StatelessWidget {
  const _ChartRow({
    required this.chart,
    required this.trailing,
    this.onTap,
  });

  final CustomerChart chart;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = chart.careName.trim().isEmpty ? '관리 케이스' : chart.careName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: SoriTokens.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SoriTokens.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                trailing,
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: SoriTokens.textSecondary,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum PillTone { ok, warn }

class PillBadge extends StatelessWidget {
  const PillBadge({super.key, required this.label, required this.tone});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final color =
        tone == PillTone.ok ? const Color(0xFF059669) : SoriTokens.warningText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
