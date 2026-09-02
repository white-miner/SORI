import 'package:flutter/material.dart';

import '../../../models/program_sales.dart';
import '../../../services/sori_store.dart';
import '../../visit/home_visual_tokens.dart';
import '../program_accept.dart';
import 'program_closer_bar.dart';
import 'program_package_summary.dart';
import 'promotion_closer_sheet.dart';

/// Q1(a) — 패키지 1택 단건 요약. 비교 화면과 클로징 UI 만 공유한다.
class ProgramQuotePage extends StatefulWidget {
  const ProgramQuotePage({
    super.key,
    required this.store,
    required this.quoteId,
  });

  final SoriStore store;
  final String quoteId;

  @override
  State<ProgramQuotePage> createState() => _ProgramQuotePageState();
}

class _ProgramQuotePageState extends State<ProgramQuotePage> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  ProgramQuote? get _quote => widget.store.findProgramQuote(widget.quoteId);

  Future<void> _openPromos() async {
    final q = _quote;
    if (q == null) return;
    final picked = await showPromotionCloserSheet(
      context: context,
      promotions: widget.store.promotionsForPackage(q.chosen),
      selectedIds: q.promotionIds,
    );
    if (picked == null || !mounted) return;
    await widget.store.setQuotePromotions(quote: q, promotionIds: picked);
  }

  Future<void> _accept() async {
    final q = _quote;
    if (q == null) return;
    final done = await acceptProgramQuoteWithCustomer(
      context: context,
      store: widget.store,
      quote: q,
    );
    if (done && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    if (quote == null) {
      return const Scaffold(
        body: Center(child: Text('견적을 찾을 수 없습니다')),
      );
    }

    return Scaffold(
      key: const Key('program-quote-page'),
      backgroundColor: HomeVisualTokens.canvasBg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      '구성 확인',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const Key('program-quote-stage'),
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  ProgramPackageSummary(side: quote.chosen),
                ],
              ),
            ),
            ProgramAvailablePromos(
              promotions: widget.store.promotionsForPackage(quote.chosen),
            ),
            ProgramBenefitBar(
              quote: quote,
              catalog: widget.store.programPromotions,
            ),
            ProgramCloserActions(
              quote: quote,
              onOpenPromos: _openPromos,
              onAccept: _accept,
            ),
          ],
        ),
      ),
    );
  }
}
