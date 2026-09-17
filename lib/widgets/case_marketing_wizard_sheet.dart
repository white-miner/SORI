import 'package:flutter/material.dart';

import '../models/ai_tool.dart';
import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/ai_tool_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'case_kakao_share_button.dart';

/// E4 — 케이스 → AI 카피 → 카톡 원탭 마케팅 위저드.
Future<void> showCaseMarketingWizard(
  BuildContext context, {
  required SoriStore store,
  required CustomerChart chart,
  Customer? customer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CaseMarketingWizardSheet(
      store: store,
      chart: chart,
      customer: customer,
    ),
  );
}

class _CaseMarketingWizardSheet extends StatefulWidget {
  const _CaseMarketingWizardSheet({
    required this.store,
    required this.chart,
    this.customer,
  });

  final SoriStore store;
  final CustomerChart chart;
  final Customer? customer;

  @override
  State<_CaseMarketingWizardSheet> createState() =>
      _CaseMarketingWizardSheetState();
}

class _CaseMarketingWizardSheetState extends State<_CaseMarketingWizardSheet> {
  int _step = 0;
  bool _loading = false;
  AiToolDraft? _draft;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final draft = await AiToolService.generate(
        shopId: widget.store.shop.id,
        chartId: widget.chart.id,
        mode: AiToolMode.marketing,
        customer: widget.customer,
        chart: widget.chart,
      );
      await widget.store.refreshPointWallet();
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _step = 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _shareKakao() async {
    final d = _draft;
    if (d == null) return;
    await shareMarketingCopyToKakao(
      context,
      title: d.title,
      body: d.marketingBody,
      shopName: widget.store.shop.name,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _publish() async {
    final d = _draft;
    if (d == null) return;
    setState(() => _loading = true);
    try {
      await widget.store.publishChartCaseToCommunity(
        widget.chart,
        title: d.title.isEmpty ? null : d.title,
        body: d.marketingBody.isEmpty ? null : d.marketingBody,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('피드에 발행했어요. 카톡 공유도 이어서 해보세요!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final care = widget.chart.careName.trim().isEmpty
        ? '관리 케이스'
        : widget.chart.careName.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SoriTokens.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _step == 0 ? '마케팅 원탭' : '카톡으로 보내기',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _step == 0
                    ? '$care 케이스로 AI 마케팅 카피를 만들고 카카오톡으로 바로 보냅니다.'
                    : '카피를 확인한 뒤 카톡 공유 또는 피드 발행을 선택하세요.',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: SoriTokens.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: SoriTokens.systemRed,
                    fontSize: 12.5,
                  ),
                ),
              ),
            if (_step == 0) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: FilledButton(
                  onPressed: _loading ? null : _generate,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'AI 카피 생성 후 카톡 단계로',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ] else ...[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SelectableText(
                    _draft?.marketingBody ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.55),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : _publish,
                        child: const Text('피드 발행'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _shareKakao,
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('카톡 공유'),
                      ),
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
}
