import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../content_atomizer/models/post_draft.dart';
import '../../models/customer_chart.dart';
import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../visit_kernel/models/visit_session.dart';
import '../../visit_kernel/theme/visit_glass_tokens.dart';
import '../../visit_kernel/widgets/visit_glass_widgets.dart';
import 'publish_rail_service.dart';

/// Phase 2 Publish Rail — Social Glass carousel + 전부 발행.
Future<PublishRailResult?> showPublishRailSheet(
  BuildContext context, {
  required SoriStore store,
  required VisitSession session,
  required CustomerChart chart,
  required List<PostDraft> initialDrafts,
}) async {
  return showModalBottomSheet<PublishRailResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141018),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _PublishRailBody(
      store: store,
      session: session,
      chart: chart,
      initialDrafts: initialDrafts,
    ),
  );
}

class _PublishRailBody extends StatefulWidget {
  const _PublishRailBody({
    required this.store,
    required this.session,
    required this.chart,
    required this.initialDrafts,
  });

  final SoriStore store;
  final VisitSession session;
  final CustomerChart chart;
  final List<PostDraft> initialDrafts;

  @override
  State<_PublishRailBody> createState() => _PublishRailBodyState();
}

class _PublishRailBodyState extends State<_PublishRailBody> {
  late List<PostDraft> _drafts;
  late final PageController _pageCtrl;
  int _page = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.initialDrafts
        .map((d) => d.copyWith(selected: d.enabled ? d.selected : false))
        .toList();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  int get _selectedCount => _drafts.where((d) => d.enabled && d.selected).length;

  Future<void> _publishAll() async {
    if (_busy || _selectedCount == 0) return;
    setState(() => _busy = true);
    try {
      final result = await PublishRailService.publishAll(
        store: widget.store,
        chart: widget.chart,
        drafts: _drafts,
      );
      if (!mounted) return;
      if (result.ok) {
        Navigator.pop(context, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errors.isNotEmpty
                  ? result.errors.first
                  : '발행할 콘텐츠가 없습니다.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(int index) {
    final d = _drafts[index];
    if (!d.enabled) return;
    setState(() {
      _drafts[index] = d.copyWith(selected: !d.selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final enabledDrafts = _drafts.where((d) => d.enabled).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 12, 0, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 콘텐츠 ${_drafts.where((d) => d.enabled).length}개',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '손님만 받았을 뿐인데, 브랜딩이 자연스럽게 완성돼요',
                        style: VisitGlassTokens.captionCalm.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                VisitProgressRing(
                  ratio: enabledDrafts.isEmpty
                      ? 0
                      : _selectedCount / enabledDrafts.length,
                  size: 44,
                  label: '$_selectedCount',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _drafts.length,
              itemBuilder: (context, i) {
                final draft = _drafts[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DraftCarouselCard(
                    draft: draft,
                    onToggle: () => _toggle(i),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _drafts.length,
              (i) => AnimatedContainer(
                duration: VisitGlassTokens.calmMotion,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: _page == i
                      ? VisitGlassTokens.care
                      : Colors.white24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy || _selectedCount == 0 ? null : _publishAll,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _selectedCount == 0
                      ? '발행할 항목을 선택해 주세요'
                      : '전부 발행 ($_selectedCount)',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: VisitGlassTokens.care,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(
              '나중에',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftCarouselCard extends StatelessWidget {
  const _DraftCarouselCard({
    required this.draft,
    required this.onToggle,
  });

  final PostDraft draft;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final disabled = !draft.enabled;

    return VisitGlassCard(
      socialGlow: draft.selected && !disabled,
      tint: VisitGlassTokens.care,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VisitGlassTokens.care.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: VisitGlassTokens.care.withValues(
                      alpha: VisitGlassTokens.edgeGlowMin,
                    ),
                  ),
                ),
                child: Text(
                  draft.kind.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (disabled)
                Tooltip(
                  message: draft.dropReason ?? '동의 필요',
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: VisitGlassTokens.alert.withValues(alpha: 0.8),
                    size: 20,
                  ),
                )
              else
                Switch.adaptive(
                  value: draft.selected,
                  onChanged: (_) => onToggle(),
                  activeTrackColor: VisitGlassTokens.care,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            draft.kind.subtitle,
            style: VisitGlassTokens.captionCalm.copyWith(color: Colors.white54),
          ),
          if (disabled && draft.dropReason != null) ...[
            const SizedBox(height: 6),
            Text(
              draft.dropReason!,
              style: VisitGlassTokens.captionCalm.copyWith(
                color: VisitGlassTokens.alert,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (draft.imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: draft.imageUrls.length >= 2
                    ? Row(
                        children: draft.imageUrls.take(2).map((url) {
                          return Expanded(
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              height: double.infinity,
                            ),
                          );
                        }).toList(),
                      )
                    : CachedNetworkImage(
                        imageUrl: draft.imageUrls.first,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          if (draft.imageUrls.isNotEmpty) const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                draft.body,
                style: VisitGlassTokens.bodyCalm.copyWith(
                  color: disabled
                      ? Colors.white38
                      : Colors.white.withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
