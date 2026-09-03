import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/program_sales.dart';
import '../../../services/sori_store.dart';
import '../../../utils/sori_uuid.dart';
import '../../visit/home_visual_tokens.dart';

Future<void> showProgramCategorySheet(
  BuildContext context, {
  required SoriStore store,
  ProgramCategory? existing,
}) {
  return _showProgramSheet<void>(
    context: context,
    child: _CategorySheet(store: store, existing: existing),
  );
}

Future<void> showProgramPackageSheet(
  BuildContext context, {
  required SoriStore store,
  required String categoryId,
  ProgramPackage? existing,
}) {
  return _showProgramSheet<void>(
    context: context,
    child: _PackageSheet(
      store: store,
      categoryId: categoryId,
      existing: existing,
    ),
  );
}

Future<void> showProgramPromotionSheet(
  BuildContext context, {
  required SoriStore store,
  ProgramPromotion? existing,
}) {
  return _showProgramSheet<void>(
    context: context,
    child: _PromoSheet(store: store, existing: existing),
  );
}

Future<T?> _showProgramSheet<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HomeVisualTokens.heroCardFill,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => child,
  );
}

class _SheetChrome extends StatelessWidget {
  const _SheetChrome({
    required this.title,
    required this.child,
    required this.onSave,
    this.saveEnabled = true,
  });

  final String title;
  final Widget child;
  final VoidCallback onSave;
  final bool saveEnabled;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
        child: SizedBox(
          height: maxH - 26 - bottom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HomeVisualTokens.caseCaptionDivider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(child: child),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: HomeVisualTokens.programDockH,
                child: FilledButton(
                  key: const Key('program-edit-sheet-save'),
                  onPressed: saveEnabled ? onSave : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeVisualTokens.programCloserFill,
                    foregroundColor: HomeVisualTokens.programCloserOn,
                    disabledBackgroundColor:
                        HomeVisualTokens.programCloserFill.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '저장',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.store, this.existing});

  final SoriStore store;
  final ProgramCategory? existing;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _subtitle =
      TextEditingController(text: widget.existing?.subtitle ?? '');

  @override
  void dispose() {
    _name.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmed = _name.text.trim();
    if (trimmed.isEmpty) return;
    final existing = widget.existing;
    final draft = existing == null
        ? ProgramCategory(
            id: '',
            shopId: widget.store.shop.id,
            name: trimmed,
            subtitle: _subtitle.text.trim(),
            sortOrder: widget.store.programCategories.length,
          )
        : existing.copyWith(name: trimmed, subtitle: _subtitle.text.trim());
    await widget.store.upsertProgramCategory(draft);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetChrome(
      title: widget.existing == null ? '카테고리 추가' : '카테고리 수정',
      onSave: _save,
      child: Column(
        children: [
          TextField(
            key: const Key('program-edit-category-name'),
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '윤곽 관리',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subtitle,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '한 줄 화법',
              hintText: '얼굴 작게 만들어요',
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageSheet extends StatefulWidget {
  const _PackageSheet({
    required this.store,
    required this.categoryId,
    this.existing,
  });

  final SoriStore store;
  final String categoryId;
  final ProgramPackage? existing;

  @override
  State<_PackageSheet> createState() => _PackageSheetState();
}

class _PackageSheetState extends State<_PackageSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _visits = TextEditingController(
    text: widget.existing == null ? '6' : '${widget.existing!.visitCount}',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.existing == null ? '1500000' : '${widget.existing!.listPriceKrw}',
  );
  late final TextEditingController _walkIn = TextEditingController(
    text: widget.existing == null || widget.existing!.walkInPriceKrw <= 0
        ? ''
        : '${widget.existing!.walkInPriceKrw}',
  );
  late String _accent = ProgramAccent.normalize(widget.existing?.accentHex);
  late final List<_LineDraft> _lines = [
    if (widget.existing != null && widget.existing!.lines.isNotEmpty)
      for (final line in widget.existing!.lines) _LineDraft.fromLine(line)
    else
      _LineDraft(),
  ];

  @override
  void initState() {
    super.initState();
    _visits.addListener(_onCalc);
    _price.addListener(_onCalc);
    _walkIn.addListener(_onCalc);
  }

  void _onCalc() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _visits.dispose();
    _price.dispose();
    _walkIn.dispose();
    for (final c in _lines) {
      c.dispose();
    }
    super.dispose();
  }

  int get _visitCount {
    final n = int.tryParse(_visits.text) ?? 0;
    return n < 1 ? 1 : n.clamp(1, 999);
  }

  int get _listPrice => int.tryParse(_price.text) ?? 0;

  int get _walkInPrice => int.tryParse(_walkIn.text) ?? 0;

  int get _unit => ProgramPricing.unitPrice(_listPrice, _visitCount);

  void _addLine() {
    setState(() => _lines.add(_LineDraft()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) {
      _lines.first.label.clear();
      _lines.first.minutes.clear();
      _lines.first.kind = ProgramLineKind.step;
      setState(() {});
      return;
    }
    final c = _lines.removeAt(index);
    c.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    final pkgName = _name.text.trim();
    if (pkgName.isEmpty) return;
    final pkgId = widget.existing?.id ?? '';
    final parsedLines = <ProgramPackageLine>[];
    var sort = 0;
    for (final c in _lines) {
      final label = c.label.text.trim();
      if (label.isEmpty) continue;
      final mins = int.tryParse(c.minutes.text);
      parsedLines.add(
        ProgramPackageLine(
          id: newUuidV4(),
          packageId: pkgId,
          kind: c.kind,
          label: label,
          minutes: c.kind == ProgramLineKind.step ? mins : null,
          sortOrder: sort++,
        ),
      );
    }
    final existing = widget.existing;
    final draft = existing == null
        ? ProgramPackage(
            id: '',
            shopId: widget.store.shop.id,
            categoryId: widget.categoryId,
            name: pkgName,
            visitCount: _visitCount,
            listPriceKrw: _listPrice.clamp(0, 999999999),
            sortOrder: widget.store.programPackages
                .where((p) => p.categoryId == widget.categoryId)
                .length,
            lines: parsedLines,
            accentHex: _accent,
            walkInPriceKrw: _walkInPrice.clamp(0, 999999999),
          )
        : existing.copyWith(
            name: pkgName,
            visitCount: _visitCount,
            listPriceKrw: _listPrice.clamp(0, 999999999),
            lines: parsedLines,
            accentHex: _accent,
            walkInPriceKrw: _walkInPrice.clamp(0, 999999999),
          );
    await widget.store.upsertProgramPackage(draft);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetChrome(
      title: widget.existing == null ? '패키지 추가' : '패키지 수정',
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('program-edit-package-name'),
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: 'A코스',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('program-edit-package-price'),
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '총결제액 (원)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('program-edit-package-visits'),
                  controller: _visits,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '횟수'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('program-edit-unit-calc'),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: HomeVisualTokens.canvasBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1회당 비용',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: HomeVisualTokens.dateIconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ProgramPricing.formatKrw(_unit)}원',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ProgramPricing.packageUnitLine(_unit, _visitCount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('program-edit-package-walkin'),
            controller: _walkIn,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '단품 1회 (원)',
              hintText: '비교 앵커. 비우면 숨김',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '구분 색',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in ProgramAccent.swatches)
                _AccentDot(
                  hex: hex,
                  selected: _accent == hex,
                  onTap: () => setState(() => _accent = hex),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '구성',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 128,
                    child: DropdownButtonFormField<ProgramLineKind>(
                      key: Key('program-edit-line-kind-$i'),
                      // ignore: deprecated_member_use
                      value: _lines[i].kind,
                      isExpanded: true,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: '종류',
                        isDense: true,
                      ),
                      items: [
                        for (final k in ProgramLineKind.values)
                          DropdownMenuItem(
                            value: k,
                            child: Text(
                              k.labelKo,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _lines[i].kind = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: Key('program-edit-line-$i'),
                      controller: _lines[i].label,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '내용',
                        hintText: '고주파 온열',
                      ),
                    ),
                  ),
                  if (_lines[i].kind == ProgramLineKind.step) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        key: Key('program-edit-line-minutes-$i'),
                        controller: _lines[i].minutes,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: '분'),
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: '항목 삭제',
                    onPressed: () => _removeLine(i),
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('program-edit-add-line'),
              onPressed: _addLine,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                '항목 추가',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: HomeVisualTokens.programCloserFill,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(ProgramAccent.argbOf(hex));
    return InkWell(
      key: Key('program-accent-$hex'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? HomeVisualTokens.programCloserFill
                : Colors.white,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _PromoSheet extends StatefulWidget {
  const _PromoSheet({required this.store, this.existing});

  final SoriStore store;
  final ProgramPromotion? existing;

  @override
  State<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends State<_PromoSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _value = TextEditingController(
    text: widget.existing == null ? '100000' : '${widget.existing!.valueKrw}',
  );
  late final TextEditingController _extra = TextEditingController(
    text: '${widget.existing?.extraVisits == 0 ? 1 : (widget.existing?.extraVisits ?? 1)}',
  );
  late final TextEditingController _percent = TextEditingController(
    text: widget.existing == null || widget.existing!.percentOff <= 0
        ? '10'
        : '${widget.existing!.percentOff == widget.existing!.percentOff.roundToDouble() ? widget.existing!.percentOff.round() : widget.existing!.percentOff}',
  );
  late final TextEditingController _giftQty = TextEditingController(
    text: '${widget.existing == null || widget.existing!.giftQty <= 0 ? 1 : widget.existing!.giftQty}',
  );
  late ProgramPromoKind _kind = widget.existing?.kind ?? ProgramPromoKind.gift;
  late ProgramPromoScope _scope =
      widget.existing?.scope ?? ProgramPromoScope.global;
  late String? _targetId = widget.existing?.targetId;
  late bool _titleTouched;

  @override
  void initState() {
    super.initState();
    _titleTouched =
        widget.existing != null && widget.existing!.title.trim().isNotEmpty;
    for (final c in [_value, _extra, _percent, _giftQty]) {
      c.addListener(_onValue);
    }
  }

  void _onValue() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_value, _extra, _percent, _giftQty]) {
      c.removeListener(_onValue);
    }
    _title.dispose();
    _value.dispose();
    _extra.dispose();
    _percent.dispose();
    _giftQty.dispose();
    super.dispose();
  }

  String get _targetName {
    if (_scope == ProgramPromoScope.category) {
      return widget.store.programCategories
              .where((c) => c.id == _targetId)
              .map((c) => c.name)
              .firstOrNull ??
          '';
    }
    if (_scope == ProgramPromoScope.package) {
      return widget.store.programPackages
              .where((p) => p.id == _targetId)
              .map((p) => p.name)
              .firstOrNull ??
          '';
    }
    return '';
  }

  String get _preview {
    final extra = int.tryParse(_extra.text) ?? 1;
    final pct = double.tryParse(_percent.text) ?? 0;
    final gift = int.tryParse(_giftQty.text) ?? 1;
    final value = int.tryParse(_value.text) ?? 0;
    return ProgramPromoComposer.preview(
      scope: _scope,
      kind: _kind,
      targetName: _targetName,
      extraVisits: extra,
      discountKrw: _kind == ProgramPromoKind.instantDiscount ? value : 0,
      percentOff: _kind == ProgramPromoKind.percentDiscount ||
              _kind == ProgramPromoKind.nextVisitCredit
          ? pct
          : 0,
      giftQty: gift,
      valueKrw: value,
    );
  }

  void _syncTitle() {
    if (_titleTouched && _title.text.trim().isNotEmpty) return;
    _title.text = _preview;
  }

  Future<void> _save() async {
    _syncTitle();
    final t = _title.text.trim();
    if (t.isEmpty) return;
    final valueKrw = int.tryParse(_value.text) ?? 0;
    final extra = _kind == ProgramPromoKind.extraSession
        ? (int.tryParse(_extra.text) ?? 1).clamp(1, 99)
        : 0;
    final discount = _kind == ProgramPromoKind.instantDiscount ? valueKrw : 0;
    final pct = (_kind == ProgramPromoKind.percentDiscount ||
            _kind == ProgramPromoKind.nextVisitCredit)
        ? (double.tryParse(_percent.text) ?? 0).clamp(0, 100).toDouble()
        : 0.0;
    final gift = _kind == ProgramPromoKind.gift
        ? (int.tryParse(_giftQty.text) ?? 1).clamp(1, 99)
        : 0;
    final existing = widget.existing;
    final draft = existing == null
        ? ProgramPromotion(
            id: '',
            shopId: widget.store.shop.id,
            kind: _kind,
            title: t,
            valueKrw: valueKrw,
            extraVisits: extra,
            discountKrw: discount,
            percentOff: pct,
            giftQty: gift,
            scope: _scope,
            targetId: _scope == ProgramPromoScope.global ? null : _targetId,
            sortOrder: widget.store.programPromotions.length,
          )
        : existing.copyWith(
            kind: _kind,
            title: t,
            valueKrw: valueKrw,
            extraVisits: extra,
            discountKrw: discount,
            percentOff: pct,
            giftQty: gift,
            scope: _scope,
            targetId: _scope == ProgramPromoScope.global ? null : _targetId,
            clearTarget: _scope == ProgramPromoScope.global,
          );
    await widget.store.upsertProgramPromotion(draft);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final cats = [...widget.store.programCategories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final pkgs = [...widget.store.programPackages]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return _SheetChrome(
      title: widget.existing == null ? '프로모션 추가' : '프로모션 수정',
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('program-promo-preview'),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: HomeVisualTokens.canvasBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              preview,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '적용 범위',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in ProgramPromoScope.values)
                ChoiceChip(
                  key: Key('program-promo-scope-${s.dbValue}'),
                  label: Text(s.labelKo),
                  selected: _scope == s,
                  onSelected: (_) => setState(() {
                    _scope = s;
                    if (s == ProgramPromoScope.global) _targetId = null;
                    if (s == ProgramPromoScope.category &&
                        (_targetId == null ||
                            !cats.any((c) => c.id == _targetId))) {
                      _targetId = cats.isEmpty ? null : cats.first.id;
                    }
                    if (s == ProgramPromoScope.package &&
                        (_targetId == null ||
                            !pkgs.any((p) => p.id == _targetId))) {
                      _targetId = pkgs.isEmpty ? null : pkgs.first.id;
                    }
                  }),
                  selectedColor: HomeVisualTokens.canvasBg,
                  showCheckmark: false,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: HomeVisualTokens.programCloserFill,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: _scope == s
                        ? HomeVisualTokens.programCloserFill
                        : HomeVisualTokens.caseCaptionDivider,
                  ),
                ),
            ],
          ),
          if (_scope == ProgramPromoScope.category && cats.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: const Key('program-promo-target-category'),
              // ignore: deprecated_member_use
              value: cats.any((c) => c.id == _targetId)
                  ? _targetId
                  : cats.first.id,
              decoration: const InputDecoration(labelText: '카테고리'),
              items: [
                for (final c in cats)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _targetId = v),
            ),
          ],
          if (_scope == ProgramPromoScope.package && pkgs.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: const Key('program-promo-target-package'),
              // ignore: deprecated_member_use
              value: pkgs.any((p) => p.id == _targetId)
                  ? _targetId
                  : pkgs.first.id,
              decoration: const InputDecoration(labelText: '패키지'),
              items: [
                for (final p in pkgs)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _targetId = v),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            '종류',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in ProgramPromoKind.values)
                ChoiceChip(
                  key: Key('program-promo-kind-${kind.dbValue}'),
                  label: Text(kind.labelKo),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                  selectedColor: HomeVisualTokens.canvasBg,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: HomeVisualTokens.programCloserFill,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: _kind == kind
                        ? HomeVisualTokens.programCloserFill
                        : HomeVisualTokens.caseCaptionDivider,
                  ),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_kind == ProgramPromoKind.extraSession)
            TextField(
              key: const Key('program-edit-promo-extra'),
              controller: _extra,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '추가 횟수'),
              onChanged: (_) => setState(() {}),
            )
          else if (_kind == ProgramPromoKind.percentDiscount ||
              _kind == ProgramPromoKind.nextVisitCredit)
            TextField(
              key: const Key('program-edit-promo-percent'),
              controller: _percent,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '할인 (%)'),
              onChanged: (_) => setState(() {}),
            )
          else if (_kind == ProgramPromoKind.gift)
            TextField(
              key: const Key('program-edit-promo-gift-qty'),
              controller: _giftQty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '증정 갯수'),
              onChanged: (_) => setState(() {}),
            )
          else
            TextField(
              controller: _value,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '정액 할인 (원)'),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _value,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: '혜택 환산 (원)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('program-edit-promo-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: '제목 (미리보기와 같으면 비워도 됩니다)'),
            onChanged: (_) => _titleTouched = true,
          ),
        ],
      ),
    );
  }
}

class _LineDraft {
  _LineDraft({
    this.kind = ProgramLineKind.step,
    String label = '',
    String minutes = '',
  })  : label = TextEditingController(text: label),
        minutes = TextEditingController(text: minutes);

  factory _LineDraft.fromLine(ProgramPackageLine line) {
    return _LineDraft(
      kind: line.kind,
      label: line.label,
      minutes: line.minutes == null ? '' : '${line.minutes}',
    );
  }

  ProgramLineKind kind;
  final TextEditingController label;
  final TextEditingController minutes;

  void dispose() {
    label.dispose();
    minutes.dispose();
  }
}
