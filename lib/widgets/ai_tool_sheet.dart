import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/ai_tool.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../routing/sori_router.dart';
import '../widgets/case_kakao_share_button.dart';
import '../services/ai_tool_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/consent_publish_gate.dart';
import 'boost_bump_sheet.dart';

enum AiToolSheetResult {
  published,
  cancelled,
}

/// Split & Micro — AI copy generation (2~4E), separate from boost.
Future<AiToolSheetResult> showAiToolSheet({
  required BuildContext context,
  required SoriStore store,
  required CustomerChart chart,
  Customer? customer,
}) async {
  final result = await showModalBottomSheet<AiToolSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(SoriTokens.radiusXl)),
    ),
    builder: (ctx) => AiToolSheet(
      store: store,
      chart: chart,
      customer: customer,
    ),
  );
  return result ?? AiToolSheetResult.cancelled;
}

class AiToolSheet extends StatefulWidget {
  const AiToolSheet({
    super.key,
    required this.store,
    required this.chart,
    this.customer,
  });

  final SoriStore store;
  final CustomerChart chart;
  final Customer? customer;

  @override
  State<AiToolSheet> createState() => _AiToolSheetState();
}

class _AiToolSheetState extends State<AiToolSheet>
    with SingleTickerProviderStateMixin {
  AiToolQuota _quota = const AiToolQuota();
  AiToolMode _selectedMode = AiToolMode.marketing;
  AiToolDraft? _draft;
  bool _generating = false;
  bool _publishing = false;
  String? _error;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadQuota();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuota() async {
    final q = await AiToolService.loadQuota(widget.store.shop.id);
    if (mounted) setState(() => _quota = q);
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final draft = await AiToolService.generate(
        shopId: widget.store.shop.id,
        chartId: widget.chart.id,
        mode: _selectedMode,
        customer: widget.customer,
        chart: widget.chart,
      );
      if (!mounted) return;
      await _loadQuota();
      await widget.store.refreshPointWallet();
      setState(() {
        _draft = draft;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = '$e';
      });
    }
  }

  Future<void> _copyMarketing() async {
    final d = _draft;
    if (d == null) return;
    await Clipboard.setData(ClipboardData(text: d.clipboardPayload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('마케팅 카피를 복사했어요.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _publish() async {
    if (_publishing || _draft == null) return;
    final gate = canPublishBa(widget.chart);
    if (!gate.allowsPublish) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SoriTokens.surface,
          title: const Text('SNS 공유 동의 필요'),
          content: Text(gate.alertMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('고객 동의 확인'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.of(context).pop(AiToolSheetResult.cancelled);
        final cid = widget.chart.customerId.trim();
        if (cid.isNotEmpty) {
          context.go('${AppPaths.appCustomers}/$cid');
        }
      }
      return;
    }
    setState(() => _publishing = true);
    try {
      final d = _draft!;
      final post = await widget.store.publishChartCaseToCommunity(
        widget.chart,
        title: d.title.isEmpty ? null : d.title,
        body: d.marketingBody.isEmpty ? null : d.marketingBody,
      );
      if (!mounted) return;
      if (post == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('피드 발행에 실패했어요.'),
            backgroundColor: SoriTokens.systemRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _publishing = false);
        return;
      }
      setState(() => _publishing = false);
      if (!mounted) return;
      Navigator.of(context).pop(AiToolSheetResult.published);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('피드에 발행했어요. 끌어올리기는 별도 메뉴에서!'),
          action: SnackBarAction(
            label: '끌어올리기',
            onPressed: () {
              showBoostBumpSheet(
                context,
                store: widget.store,
                chartId: widget.chart.id,
                caseTitle: d.title,
              );
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('발행 오류: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  String _priceHint(AiToolMode mode) {
    if (_quota.hasFree && mode != AiToolMode.regenerate) {
      return '무료 (월 ${_quota.freeRemaining}회 남음)';
    }
    return mode.priceLabel;
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
                      'AI 카피 쓰기',
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
                      color: SoriTokens.chipIdleBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _quota.chipLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).pop(AiToolSheetResult.cancelled),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (_draft == null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '노출 부스터와 별도 · 200~400원 마이크로 과금',
                  style: TextStyle(
                    fontSize: 13,
                    color: SoriTokens.textSecondary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AiToolMode.marketing,
                    AiToolMode.clinical,
                    AiToolMode.dual,
                  ].map((mode) {
                    final selected = _selectedMode == mode;
                    return ChoiceChip(
                      label: Text('${mode.label}\n${_priceHint(mode)}'),
                      selected: selected,
                      onSelected: _generating
                          ? null
                          : (_) => setState(() => _selectedMode = mode),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? SoriTokens.primary
                            : SoriTokens.textSecondary,
                        height: 1.3,
                      ),
                      selectedColor: SoriTokens.primary.withValues(alpha: 0.12),
                    );
                  }).toList(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: SoriTokens.systemRed,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: FilledButton(
                  onPressed: _generating ? null : _generate,
                  child: _generating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '생성하기 · ${_priceHint(_selectedMode)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ] else ...[
              TabBar(
                controller: _tabCtrl,
                labelColor: SoriTokens.primary,
                tabs: const [
                  Tab(text: '마케팅 카피'),
                  Tab(text: '임상 요약'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _textPane(_draft!.marketingBody),
                    _textPane(
                      _draft!.clinicalReport.isEmpty
                          ? '임상 요약이 없습니다.'
                          : _draft!.clinicalReport,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _copyMarketing,
                      child: const Text('복사'),
                    ),
                    const SizedBox(width: 8),
                    CaseKakaoShareButton(
                      title: _draft!.title,
                      body: _draft!.marketingBody,
                      shopName: widget.store.shop.name,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _generating
                          ? null
                          : () async {
                              setState(() => _selectedMode = AiToolMode.regenerate);
                              await _generate();
                            },
                      child: const Text('재생성 1E'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _publishing ? null : _publish,
                      child: _publishing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('피드 발행'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _textPane(String text) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.55,
          color: SoriTokens.textPrimary,
        ),
      ),
    );
  }
}
