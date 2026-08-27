import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/ai_case_story_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

enum _SheetPhase { generating, ready, published }

/// Result of [showAiCaseStorySheet].
enum AiCaseStorySheetResult {
  publishedWithAi,
  publishedSkipAi,
  cancelled,
}

/// Option A: 피드 공유 Switch → Bottom Sheet (generate → edit → publish / skip).
Future<AiCaseStorySheetResult> showAiCaseStorySheet({
  required BuildContext context,
  required SoriStore store,
  required CustomerChart chart,
  Customer? customer,
}) async {
  final result = await showModalBottomSheet<AiCaseStorySheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SoriTokens.radiusXl),
      ),
    ),
    builder: (ctx) => AiCaseStorySheet(
      store: store,
      chart: chart,
      customer: customer,
    ),
  );
  return result ?? AiCaseStorySheetResult.cancelled;
}

class AiCaseStorySheet extends StatefulWidget {
  const AiCaseStorySheet({
    super.key,
    required this.store,
    required this.chart,
    this.customer,
  });

  final SoriStore store;
  final CustomerChart chart;
  final Customer? customer;

  @override
  State<AiCaseStorySheet> createState() => _AiCaseStorySheetState();
}

class _AiCaseStorySheetState extends State<AiCaseStorySheet> {
  _SheetPhase _phase = _SheetPhase.generating;
  AiCaseStoryUsage _usage = const AiCaseStoryUsage(used: 0, limit: 3);
  AiCaseStoryDraft? _draft;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  List<String> _hashtags = const [];
  bool _publishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
    _bootstrap();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final usage = await AiCaseStoryService.loadUsage();
    if (!mounted) return;
    setState(() => _usage = usage);

    try {
      final draft = await AiCaseStoryService.generate(
        chart: widget.chart,
        customer: widget.customer,
      );
      if (!mounted) return;
      _titleCtrl.text = draft.title;
      _bodyCtrl.text = draft.body;
      setState(() {
        _draft = draft;
        _hashtags = draft.hashtags;
        _phase = _SheetPhase.ready;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final fallback = AiCaseStoryService.localFallback(
        chart: widget.chart,
        customer: widget.customer,
      );
      _titleCtrl.text = fallback.title;
      _bodyCtrl.text = fallback.body;
      setState(() {
        _draft = fallback;
        _hashtags = fallback.hashtags;
        _phase = _SheetPhase.ready;
        _error = 'AI 연결이 불안정해 기본 초안을 준비했어요.';
      });
    }
  }

  AiCaseStorySheetResult? _publishResult;

  Future<void> _publish({required bool withAi}) async {
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      final post = withAi
          ? await widget.store.publishChartCaseToCommunity(
              widget.chart,
              title: _titleCtrl.text.trim().isEmpty
                  ? null
                  : _titleCtrl.text.trim(),
              body: _bodyCtrl.text.trim().isEmpty
                  ? null
                  : _bodyCtrl.text.trim(),
            )
          : await widget.store.publishChartCaseToCommunity(widget.chart);
      if (!mounted) return;
      if (post == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('피드 발행에 실패했어요. 잠시 후 다시 시도해 주세요.'),
            backgroundColor: SoriTokens.systemRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _publishing = false);
        return;
      }
      if (withAi) {
        final next = await AiCaseStoryService.consumeUsage();
        if (mounted) setState(() => _usage = next);
      } else {
        // Align clipboard with what was actually published (stub path).
        _titleCtrl.text = post.title;
        _bodyCtrl.text = post.body;
        _hashtags = const [];
      }
      setState(() {
        _phase = _SheetPhase.published;
        _publishing = false;
        _publishResult = withAi
            ? AiCaseStorySheetResult.publishedWithAi
            : AiCaseStorySheetResult.publishedSkipAi;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('발행 중 오류: $e'),
          backgroundColor: SoriTokens.systemRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyStory() async {
    final draft = AiCaseStoryDraft(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      hashtags: _hashtags,
    );
    await Clipboard.setData(ClipboardData(text: draft.clipboardPayload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('스토리와 해시태그를 복사했어요. 인스타에 붙여넣기 하세요.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color get _chipBg {
    if (_usage.remaining <= 0) return SoriTokens.systemRed;
    if (_usage.remaining == 1) {
      return SoriTokens.systemRed.withValues(alpha: 0.12);
    }
    return SoriTokens.chipIdleBg;
  }

  Color get _chipFg {
    if (_usage.remaining <= 0) return Colors.white;
    if (_usage.remaining == 1) return SoriTokens.systemRed;
    return SoriTokens.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SoriTokens.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '임상 스토리',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _chipBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _usage.chipLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _chipFg,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(
                      AiCaseStorySheetResult.cancelled,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            _buildBaStrip(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _phase == _SheetPhase.generating
                    ? _buildSkeleton()
                    : _phase == _SheetPhase.published
                        ? _buildSuccess()
                        : _buildEditor(),
              ),
            ),
            if (_phase == _SheetPhase.ready) _buildReadyFooter(),
            if (_phase == _SheetPhase.published) _buildPublishedFooter(),
            if (_phase == _SheetPhase.generating)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    AiCaseStorySheetResult.cancelled,
                  ),
                  child: const Text('취소'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaStrip() {
    final before = (widget.chart.beforeImageUrl ?? '').trim();
    final after = (widget.chart.afterImageUrl ?? '').trim();
    Widget thumb(String? url, String label) {
      return Expanded(
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null && url.startsWith('http'))
                  CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: SoriTokens.chipIdleBg,
                      alignment: Alignment.center,
                      child: Text(label),
                    ),
                  )
                else
                  Container(
                    color: SoriTokens.chipIdleBg,
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textTertiary,
                      ),
                    ),
                  ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          thumb(before.isEmpty ? null : before, 'Before'),
          const SizedBox(width: 8),
          thumb(after.isEmpty ? null : after, 'After'),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    Widget bar({double w = 1}) => Container(
          height: 12,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: SoriTokens.chipIdleBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            widthFactor: w,
            alignment: Alignment.centerLeft,
            child: const SizedBox.expand(),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '임상 스토리 작성 중…',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SoriTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        bar(w: 0.7),
        bar(),
        bar(),
        bar(w: 0.85),
        bar(w: 0.55),
      ],
    );
  }

  Widget _buildEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleCtrl,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: SoriTokens.textPrimary,
          ),
          decoration: const InputDecoration(
            labelText: '제목',
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bodyCtrl,
          minLines: 6,
          maxLines: 12,
          style: const TextStyle(
            height: 1.45,
            color: SoriTokens.textPrimary,
          ),
          decoration: const InputDecoration(
            labelText: '본문',
            alignLabelWithHint: true,
          ),
        ),
        if (_hashtags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _hashtags
                .map(
                  (h) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: SoriTokens.chipIdleBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      h.startsWith('#') ? h : '#$h',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (_draft?.source == 'local_fallback' ||
            _draft?.source == 'fallback' ||
            _draft?.source == 'fallback_openai_error')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '오프라인/폴백 초안입니다. 발행 전 내용을 확인해 주세요.',
              style: TextStyle(fontSize: 11.5, color: SoriTokens.textTertiary),
            ),
          ),
      ],
    );
  }

  Widget _buildSuccess() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '피드에 올렸어요',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: SoriTokens.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '스토리를 복사해 인스타그램 등 외부에 바로 붙여넣을 수 있어요.',
          style: TextStyle(
            fontSize: 13,
            color: SoriTokens.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildReadyFooter() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Text(
              _usage.remaining > 0
                  ? '이번 생성은 무료예요 · ${_usage.chipLabel}'
                  : '무료 횟수를 모두 썼어요 · 다음 달 초기 또는 AI 없이 공유',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _usage.remaining > 0
                    ? SoriTokens.textTertiary
                    : SoriTokens.systemRed,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _publishing
                        ? null
                        : () => _publish(withAi: false),
                    child: const Text('AI 없이 공유'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: FilledButton(
                    onPressed: _publishing
                        ? null
                        : () => _publish(withAi: true),
                    child: _publishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('피드에 올리기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishedFooter() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyStory,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('스토리 복사'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _publishResult ?? AiCaseStorySheetResult.publishedWithAi,
                ),
                child: const Text('완료'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
