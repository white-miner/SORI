import 'package:flutter/material.dart';

import '../../../models/program_sales.dart';
import '../../../services/sori_store.dart';
import '../../visit/home_visual_tokens.dart';
import '../program_accept.dart';
import 'program_unit_price.dart';
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
      promotions: widget.store.liveProgramPromotions,
      selectedIds: q.promotionIds,
    );
    if (picked == null || !mounted) return;
    await widget.store.setQuotePromotions(quote: q, promotionIds: picked);
  }

  Future<void> _accept() async {
    final q = _quote;
    if (q == null) return;
    await acceptProgramQuoteWithCustomer(
      context: context,
      store: widget.store,
      quote: q,
    );
    if (mounted) Navigator.of(context).pop();
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
            _AvailablePromos(promotions: widget.store.liveProgramPromotions),
            _BenefitBar(
              quote: quote,
              catalog: widget.store.programPromotions,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: HomeVisualTokens.programDockH,
                      child: OutlinedButton.icon(
                        key: const Key('program-closer-chip'),
                        onPressed: _openPromos,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HomeVisualTokens.programCloserFill,
                          side: const BorderSide(
                            color: HomeVisualTokens.programCloserFill,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.card_giftcard_outlined, size: 20),
                        label: Text(
                          quote.promotionIds.isEmpty
                              ? '프로모션 적용'
                              : '프로모션 ${quote.promotionIds.length}건',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: HomeVisualTokens.programDockH,
                      child: FilledButton(
                        onPressed: _accept,
                        style: FilledButton.styleFrom(
                          backgroundColor: HomeVisualTokens.programCloserFill,
                          foregroundColor: HomeVisualTokens.programCloserOn,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          '이 구성으로 등록',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
          child: _CompareColumn(
            key: const Key('program-compare-left'),
            side: quote.left,
            selected: quote.chosenPackageId == quote.left.id,
            onChoose: () => onChoose(quote.left.id),
            peer: quote.right,
          ),
        ),
        Container(width: 1, color: HomeVisualTokens.caseCaptionDivider),
        Expanded(
          child: _CompareColumn(
            key: const Key('program-compare-right'),
            side: quote.right,
            selected: quote.chosenPackageId == quote.right.id,
            onChoose: () => onChoose(quote.right.id),
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
        _CompareColumn(
          key: const Key('program-compare-left'),
          side: quote.left,
          selected: quote.chosenPackageId == quote.left.id,
          onChoose: () => onChoose(quote.left.id),
          peer: quote.right,
        ),
        const SizedBox(height: 10),
        _CompareColumn(
          key: const Key('program-compare-right'),
          side: quote.right,
          selected: quote.chosenPackageId == quote.right.id,
          onChoose: () => onChoose(quote.right.id),
          peer: quote.left,
        ),
      ],
    );
  }
}

class _CompareColumn extends StatelessWidget {
  const _CompareColumn({
    super.key,
    required this.side,
    required this.selected,
    required this.onChoose,
    required this.peer,
  });

  final ProgramPackageSnapshot side;
  final ProgramPackageSnapshot peer;
  final bool selected;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final unitWins = side.unitPriceKrw < peer.unitPriceKrw;
    final steps = side.lines.where((l) => l.kind == ProgramLineKind.step);
    final devices = side.lines.where((l) => l.kind == ProgramLineKind.device);
    final ampoules = side.lines.where((l) => l.kind == ProgramLineKind.ampoule);
    final accent = Color(ProgramAccent.argbOf(side.accentHex));
    final perks = side.lines.where((l) => l.kind == ProgramLineKind.perk);

    return Material(
      color: selected ? HomeVisualTokens.canvasBg : Colors.transparent,
      child: InkWell(
        onTap: onChoose,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      side.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              if (side.categoryName.trim().isNotEmpty)
                Text(
                  side.categoryName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: HomeVisualTokens.dateIconColor,
                  ),
                ),
              const SizedBox(height: 10),
              _kv('횟수', '${side.visitCount}회'),
              _kv(
                '회당 단가',
                ProgramPricing.formatKrw(side.unitPriceKrw),
                emphasize: unitWins,
              ),
              ProgramUnitPriceBlock(
                unitPriceKrw: side.unitPriceKrw,
                visitCount: side.visitCount,
                walkInPriceKrw: side.walkInPriceKrw,
              ),
              const SizedBox(height: 6),
              _kv(
                '정가',
                ProgramPricing.formatKrw(side.listPriceKrw),
                large: true,
              ),
              const SizedBox(height: 8),
              const Text(
                '구성',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: HomeVisualTokens.dateIconColor,
                ),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < steps.length; i++)
                Text(
                  '${i + 1}. ${steps.elementAt(i).label}'
                  '${steps.elementAt(i).minutes == null ? '' : ' ${steps.elementAt(i).minutes}분'}',
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              for (final perk in perks)
                Text(
                  '· ${perk.label}',
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              if (devices.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in devices) _chip(d.label),
                  ],
                ),
              ],
              if (ampoules.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in ampoules) _chip(a.label),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              _kv('시간 합', '${side.stepMinutes}분'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String label, String value, {bool emphasize = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: HomeVisualTokens.dateIconColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: large ? 22 : 14,
                fontWeight: emphasize || large ? FontWeight.w700 : FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HomeVisualTokens.canvasBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
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

class _AvailablePromos extends StatelessWidget {
  const _AvailablePromos({required this.promotions});

  final List<ProgramPromotion> promotions;

  @override
  Widget build(BuildContext context) {
    if (promotions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Column(
        children: [
          const Text(
            '적용 가능 프로모션',
            key: Key('program-available-promos'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: HomeVisualTokens.dateIconColor,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final p in promotions)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: HomeVisualTokens.canvasBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${p.kind.labelKo} · ${p.title}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenefitBar extends StatelessWidget {
  const _BenefitBar({required this.quote, required this.catalog});

  final ProgramQuote quote;
  final List<ProgramPromotion> catalog;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = quote.payableKrw < quote.listPriceKrw;
    final qty = quote.promotionQty;
    final order = quote.uniquePromotionIds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          Text(
            ProgramPricing.formatKrw(quote.listPriceKrw),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              decoration:
                  hasDiscount ? TextDecoration.lineThrough : TextDecoration.none,
              color: hasDiscount
                  ? HomeVisualTokens.programStrike
                  : HomeVisualTokens.dateTextColor,
            ),
          ),
          if (order.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final id in order)
                    _AppliedPromoChip(
                      key: Key('program-applied-promo-$id'),
                      title: catalog
                              .where((p) => p.id == id)
                              .map((p) => p.title)
                              .firstOrNull ??
                          id,
                      qty: qty[id] ?? 1,
                    ),
                ],
              ),
            ),
          if (quote.benefitValueKrw > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '총 ${ProgramPricing.formatKrw(quote.benefitValueKrw)}원 추가 혜택 적용됨',
                key: const Key('program-benefit-line'),
                style: const TextStyle(
                  fontSize: HomeVisualTokens.programBenefitSize,
                  fontWeight: FontWeight.w700,
                  color: HomeVisualTokens.dateTextColor,
                ),
              ),
            ),
          if (hasDiscount)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '오늘 결제  ${ProgramPricing.formatKrw(quote.payableKrw)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppliedPromoChip extends StatelessWidget {
  const _AppliedPromoChip({
    super.key,
    required this.title,
    required this.qty,
  });

  final String title;
  final int qty;

  @override
  Widget build(BuildContext context) {
    final label = qty > 1 ? '$title ×$qty' : title;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: HomeVisualTokens.canvasBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HomeVisualTokens.programCloserFill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HomeVisualTokens.programCloserFill,
        ),
      ),
    );
  }
}
