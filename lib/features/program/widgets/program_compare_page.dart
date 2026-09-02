import 'package:flutter/material.dart';

import '../../../models/program_sales.dart';
import '../../../services/sori_store.dart';
import '../../visit/home_visual_tokens.dart';
import '../program_accept.dart';
import 'program_closer_bar.dart';
import 'program_package_summary.dart';
import 'promotion_closer_sheet.dart';

class ProgramComparePage extends StatefulWidget {
  const ProgramComparePage({
    super.key,
    required this.store,
    required this.quoteId,
  });

  final SoriStore store;
  final String quoteId;

  @override
  State<ProgramComparePage> createState() => _ProgramComparePageState();
}

class _ProgramComparePageState extends State<ProgramComparePage> {
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

  Future<void> _choose(String packageId) async {
    final q = _quote;
    if (q == null) return;
    await widget.store.setQuoteChosen(quote: q, packageId: packageId);
  }

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

    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      backgroundColor: HomeVisualTokens.canvasBg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: quote.isCrossCategory ? '다른 카테고리입니다' : '구성 비교',
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: HomeVisualTokens.programExpandDuration,
                switchInCurve: HomeVisualTokens.programExpandCurve,
                child: KeyedSubtree(
                  key: const Key('program-compare-stage'),
                      child: landscape
                      ? _LandscapeStage(
                          quote: quote,
                          onChoose: _choose,
                        )
                      : _PortraitStage(
                          quote: quote,
                          onChoose: _choose,
                        ),
                ),
              ),
            ),
            _DeltaLine(quote: quote),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _LandscapeStage extends StatelessWidget {
  const _LandscapeStage({
    required this.quote,
    required this.onChoose,
  });

  final ProgramQuote quote;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ProgramPackageSummary(
            key: const Key('program-compare-left'),
            side: quote.left,
            selected: quote.chosenPackageId == quote.left.id,
            onChoose: () => onChoose(quote.left.id),
            peer: quote.right,
          ),
        ),
        Container(width: 1, color: HomeVisualTokens.caseCaptionDivider),
        Expanded(
          child: ProgramPackageSummary(
            key: const Key('program-compare-right'),
            side: quote.right!,
            selected: quote.chosenPackageId == quote.right!.id,
            onChoose: () => onChoose(quote.right!.id),
            peer: quote.left,
          ),
        ),
      ],
    );
  }
}

class _PortraitStage extends StatelessWidget {
  const _PortraitStage({
    required this.quote,
    required this.onChoose,
  });

  final ProgramQuote quote;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        ProgramPackageSummary(
          key: const Key('program-compare-left'),
          side: quote.left,
          selected: quote.chosenPackageId == quote.left.id,
          onChoose: () => onChoose(quote.left.id),
          peer: quote.right,
        ),
        const SizedBox(height: 10),
        ProgramPackageSummary(
          key: const Key('program-compare-right'),
          side: quote.right!,
          selected: quote.chosenPackageId == quote.right!.id,
          onChoose: () => onChoose(quote.right!.id),
          peer: quote.left,
        ),
      ],
    );
  }
}

class _DeltaLine extends StatelessWidget {
  const _DeltaLine({required this.quote});

  final ProgramQuote quote;

  @override
  Widget build(BuildContext context) {
    final a = quote.left;
    final b = quote.right;
    if (b == null) return const SizedBox.shrink();
    final cheaper = a.listPriceKrw <= b.listPriceKrw ? a : b;
    final other = cheaper.id == a.id ? b : a;
    final priceGap = other.listPriceKrw - cheaper.listPriceKrw;
    final unitGap = other.unitPriceKrw - cheaper.unitPriceKrw;
    final unitPhrase = unitGap > 0
        ? '회당 ${ProgramPricing.formatKrw(unitGap)}원 이득'
        : unitGap < 0
            ? '회당 ${ProgramPricing.formatKrw(-unitGap)}원 더 높음'
            : '회당 동일';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Text(
        '${cheaper.name}이 ${ProgramPricing.formatKrw(priceGap)}원 낮고, $unitPhrase',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}
