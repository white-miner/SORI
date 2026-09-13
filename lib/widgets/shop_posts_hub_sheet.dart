import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/content_candidate/content_candidate_inbox.dart';
import '../models/customer_chart.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/category_presentation_map.dart';
import '../utils/consent_publish_gate.dart';
import 'ai_tool_sheet.dart';
import 'sori_network_image.dart';

/// 마이페이지 게시물 지표 — B/A · 조용한 이야기 허브.
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
    _tabs = TabController(length: 2, vsync: this);
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
              tabs: [
                const Tab(text: 'B/A'),
                Tab(text: CategoryPresentationMap.whisper.label),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _BaPostsPane(store: widget.store),
                  _WhisperPostsPane(store: widget.store),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BaPostsPane extends StatefulWidget {
  const _BaPostsPane({required this.store});

  final SoriStore store;

  @override
  State<_BaPostsPane> createState() => _BaPostsPaneState();
}

class _BaPostsPaneState extends State<_BaPostsPane> {
  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    ContentCandidateInbox.instance.addListener(_onInbox);
    unawaited(ContentCandidateInbox.instance.hydrate());
  }

  @override
  void dispose() {
    ContentCandidateInbox.instance.removeListener(_onInbox);
    super.dispose();
  }

  void _onInbox() {
    if (mounted) setState(() {});
  }

  List<ContentCandidateCard> get _candidateCards {
    final inbox = ContentCandidateInbox.instance;
    final cards = <ContentCandidateCard>[];
    for (final e in inbox.entries.entries) {
      final chart = store.findChartById(e.key);
      if (chart == null) continue;
      cards.add(ContentCandidateInbox.cardFor(chart, e.value));
    }
    return cards;
  }

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

  Future<void> _unpublish(BuildContext context, CustomerChart chart) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SoriTokens.surface,
        title: const Text('피드에서 내리기'),
        content: const Text(
          '이 사례를 커뮤니티 피드에서 내릴까요? 차트와 사진은 그대로 보관됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('내리기'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final ok = await store.unpublishBaFromCommunity(chart.id);
    if (!mounted) return;
    setState(() {});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '피드에서 내렸어요. 차트와 사진은 유지됩니다.'
              : (store.lastError ?? '내리기에 실패했어요'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _tryPublish(BuildContext context, CustomerChart chart) async {
    final gate = canPublishBa(chart);
    if (!gate.allowsPublish) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SoriTokens.surface,
          title: const Text('SNS 공개 동의가 필요해요'),
          content: Text(gate.alertMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('확인'),
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

  Future<void> _openCandidateDetail(ContentCandidateCard card) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ContentCandidateDetailSheet(
        chartId: card.chartId,
        store: store,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final published = _published;
    final drafts = _drafts;
    final candidates = _candidateCards;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          '콘텐츠 후보함',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '아직 콘텐츠 후보가 없어요.',
              style: TextStyle(
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...candidates.map(
            (card) => _ContentCandidateCardTile(
              card: card,
              onTap: () => _openCandidateDetail(card),
            ),
          ),
        const SizedBox(height: 12),
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _unpublish(context, c),
                    style: TextButton.styleFrom(
                      foregroundColor: SoriTokens.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      '피드에서 내리기',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const PillBadge(
                    label: '발행됨',
                    tone: PillTone.ok,
                  ),
                ],
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
      return Center(
        child: Text(
          '${CategoryPresentationMap.whisper.label}가 없어요.',
          style: const TextStyle(
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
            p.title.trim().isEmpty
                ? CategoryPresentationMap.whisper.label
                : p.title,
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

class _ContentCandidateCardTile extends StatelessWidget {
  const _ContentCandidateCardTile({
    required this.card,
    required this.onTap,
  });

  final ContentCandidateCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = card.imageUrl?.trim() ?? '';
    return Padding(
      key: Key('content-candidate-card-${card.chartId}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: SoriTokens.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SoriTokens.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: url.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFF3F4F6),
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 20,
                              color: Color(0xFF9CA3AF),
                            ),
                          )
                        : SoriNetworkImage(url: url, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.serviceSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _candidateDateLabel(card.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: SoriTokens.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PillBadge(
                  label: card.statusLabel,
                  tone: card.status == ContentCandidateStatus.ready
                      ? PillTone.ok
                      : PillTone.warn,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _candidateDateLabel(DateTime? date) {
  if (date == null) return '날짜 없음';
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

class _ContentCandidateDetailSheet extends StatefulWidget {
  const _ContentCandidateDetailSheet({
    required this.chartId,
    required this.store,
  });

  final String chartId;
  final SoriStore store;

  @override
  State<_ContentCandidateDetailSheet> createState() =>
      _ContentCandidateDetailSheetState();
}

class _ContentCandidateDetailSheetState
    extends State<_ContentCandidateDetailSheet> {
  @override
  void initState() {
    super.initState();
    ContentCandidateInbox.instance.addListener(_onInbox);
  }

  @override
  void dispose() {
    ContentCandidateInbox.instance.removeListener(_onInbox);
    super.dispose();
  }

  void _onInbox() {
    if (mounted) setState(() {});
  }

  ContentCandidateCard? get _card {
    final status = ContentCandidateInbox.instance.entries[widget.chartId];
    if (status == null) return null;
    final chart = widget.store.findChartById(widget.chartId);
    if (chart == null) return null;
    return ContentCandidateInbox.cardFor(chart, status);
  }

  Future<void> _markReady() async {
    await ContentCandidateInbox.instance.markReady(widget.chartId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('발행 준비 완료로 바꿨어요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    if (card == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('후보를 찾을 수 없어요.'),
        ),
      );
    }
    final url = card.imageUrl?.trim() ?? '';
    return SafeArea(
      child: Padding(
        key: Key('content-candidate-detail-${card.chartId}'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: url.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFF3F4F6),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF9CA3AF),
                        ),
                      )
                    : SoriNetworkImage(url: url, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              card.serviceSummary,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _candidateDateLabel(card.createdAt),
              style: const TextStyle(
                fontSize: 13,
                color: SoriTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: PillBadge(
                label: card.statusLabel,
                tone: card.status == ContentCandidateStatus.ready
                    ? PillTone.ok
                    : PillTone.warn,
              ),
            ),
            if (card.status == ContentCandidateStatus.queued) ...[
              const SizedBox(height: 20),
              FilledButton(
                key: Key('content-candidate-mark-ready-${card.chartId}'),
                onPressed: _markReady,
                child: const Text('발행 준비 완료'),
              ),
            ],
          ],
        ),
      ),
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
