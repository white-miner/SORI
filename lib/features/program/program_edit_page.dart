import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/program_sales.dart';
import '../../services/sori_store.dart';
import '../../utils/sori_uuid.dart';
import '../visit/home_visual_tokens.dart';

/// 고객이 보면 안 되는 뒷무대. Presentation 의 톱니에서만 연다.
class ProgramEditPage extends StatefulWidget {
  const ProgramEditPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<ProgramEditPage> createState() => _ProgramEditPageState();
}

class _ProgramEditPageState extends State<ProgramEditPage> {
  SoriStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _editCategory(ProgramCategory? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final subtitle = TextEditingController(text: existing?.subtitle ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '카테고리 추가' : '카테고리 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              controller: subtitle,
              decoration: const InputDecoration(labelText: '한 줄 화법'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) return;
    final draft = existing == null
        ? ProgramCategory(
            id: '',
            shopId: store.shop.id,
            name: trimmed,
            subtitle: subtitle.text.trim(),
            sortOrder: store.programCategories.length,
          )
        : existing.copyWith(name: trimmed, subtitle: subtitle.text.trim());
    await store.upsertProgramCategory(draft);
  }

  Future<void> _editPackage(ProgramPackage? existing, String categoryId) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final visits = TextEditingController(
      text: existing == null ? '6' : '${existing.visitCount}',
    );
    final price = TextEditingController(
      text: existing == null ? '1500000' : '${existing.listPriceKrw}',
    );
    final lines = TextEditingController(
      text: existing?.lines.map((l) => l.label).join('\n') ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '패키지 추가' : '패키지 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              TextField(
                controller: visits,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '횟수'),
              ),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '정가 (원)'),
              ),
              TextField(
                controller: lines,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '구성 (줄마다 한 항목)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final pkgName = name.text.trim();
    if (pkgName.isEmpty) return;
    final visitCount = int.tryParse(visits.text) ?? 1;
    final listPrice = int.tryParse(price.text) ?? 0;
    final pkgId = existing?.id ?? '';
    final parsedLines = <ProgramPackageLine>[];
    var sort = 0;
    for (final raw in lines.text.split('\n')) {
      final label = raw.trim();
      if (label.isEmpty) continue;
      parsedLines.add(
        ProgramPackageLine(
          id: newUuidV4(),
          packageId: pkgId,
          kind: ProgramLineKind.perk,
          label: label,
          sortOrder: sort++,
        ),
      );
    }
    final draft = existing == null
        ? ProgramPackage(
            id: '',
            shopId: store.shop.id,
            categoryId: categoryId,
            name: pkgName,
            visitCount: visitCount.clamp(1, 999),
            listPriceKrw: listPrice.clamp(0, 999999999),
            sortOrder: store.programPackages
                .where((p) => p.categoryId == categoryId)
                .length,
            lines: parsedLines,
          )
        : existing.copyWith(
            name: pkgName,
            visitCount: visitCount.clamp(1, 999),
            listPriceKrw: listPrice.clamp(0, 999999999),
            lines: parsedLines,
          );
    await store.upsertProgramPackage(draft);
  }

  Future<void> _editPromo(ProgramPromotion? existing) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final value = TextEditingController(
      text: existing == null ? '100000' : '${existing.valueKrw}',
    );
    var kind = existing?.kind ?? ProgramPromoKind.gift;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(existing == null ? '프로모션 추가' : '프로모션 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                DropdownButton<ProgramPromoKind>(
                  value: kind,
                  isExpanded: true,
                  items: ProgramPromoKind.values
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(k.dbValue),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => kind = v ?? kind),
                ),
                TextField(
                  controller: value,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '혜택 환산 (원)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('저장'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    final t = title.text.trim();
    if (t.isEmpty) return;
    final valueKrw = int.tryParse(value.text) ?? 0;
    final extra = kind == ProgramPromoKind.extraSession ? 1 : 0;
    final discount = kind == ProgramPromoKind.instantDiscount ? valueKrw : 0;
    final draft = existing == null
        ? ProgramPromotion(
            id: '',
            shopId: store.shop.id,
            kind: kind,
            title: t,
            valueKrw: valueKrw,
            extraVisits: extra,
            discountKrw: discount,
            sortOrder: store.programPromotions.length,
          )
        : existing.copyWith(
            kind: kind,
            title: t,
            valueKrw: valueKrw,
            extraVisits: extra,
            discountKrw: discount,
          );
    await store.upsertProgramPromotion(draft);
  }

  @override
  Widget build(BuildContext context) {
    final cats = [...store.programCategories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Scaffold(
      backgroundColor: HomeVisualTokens.canvasBg,
      appBar: AppBar(
        title: const Text('메뉴 보드 편집'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '고객에게 보이기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '카테고리',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => _editCategory(null),
                child: const Text('추가'),
              ),
            ],
          ),
          for (final cat in cats) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(cat.name),
              subtitle: Text(cat.subtitle),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => store.deleteProgramCategory(cat.id),
              ),
              onTap: () => _editCategory(cat),
            ),
            for (final pkg in store.programPackages
                .where((p) => p.categoryId == cat.id))
              ListTile(
                contentPadding: const EdgeInsets.only(left: 16),
                title: Text(
                  '${pkg.name} · ${pkg.visitCount}회 · ${ProgramPricing.formatKrw(pkg.listPriceKrw)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => store.deleteProgramPackage(pkg.id),
                ),
                onTap: () => _editPackage(pkg, cat.id),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _editPackage(null, cat.id),
                child: const Text('패키지 추가'),
              ),
            ),
            const Divider(),
          ],
          Row(
            children: [
              const Expanded(
                child: Text(
                  '프로모션',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => _editPromo(null),
                child: const Text('추가'),
              ),
            ],
          ),
          for (final p in store.programPromotions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.title),
              subtitle: Text(
                '${p.kind.dbValue} · ${ProgramPricing.formatKrw(p.valueKrw)} 상당',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => store.deleteProgramPromotion(p.id),
              ),
              onTap: () => _editPromo(p),
            ),
        ],
      ),
    );
  }
}
