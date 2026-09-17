import 'package:flutter/material.dart';

import '../../models/program_sales.dart';
import '../../services/sori_store.dart';
import '../visit/home_visual_tokens.dart';
import 'widgets/program_editor_sheets.dart';

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
            key: const Key('program-edit-save'),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '저장',
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
                key: const Key('program-edit-add-category'),
                onPressed: () => showProgramCategorySheet(context, store: store),
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
              onTap: () => showProgramCategorySheet(
                context,
                store: store,
                existing: cat,
              ),
            ),
            for (final pkg in store.programPackages
                .where((p) => p.categoryId == cat.id))
              ListTile(
                contentPadding: const EdgeInsets.only(left: 8),
                leading: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(ProgramAccent.argbOf(pkg.accentHex)),
                  ),
                ),
                title: Text(
                  '${pkg.name} · ${pkg.visitCount}회 · ${ProgramPricing.formatKrw(pkg.listPriceKrw)}',
                ),
                subtitle: Text(
                  ProgramPricing.packageUnitLine(
                    pkg.unitPriceKrw,
                    pkg.visitCount,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => store.deleteProgramPackage(pkg.id),
                ),
                onTap: () => showProgramPackageSheet(
                  context,
                  store: store,
                  categoryId: cat.id,
                  existing: pkg,
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: Key('program-edit-add-package-${cat.id}'),
                onPressed: () => showProgramPackageSheet(
                  context,
                  store: store,
                  categoryId: cat.id,
                ),
                child: const Text('패키지 추가'),
              ),
            ),
            if (store.programPackages.where((p) => p.categoryId == cat.id).length <
                2)
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '비교하려면 패키지를 하나 더 추가하세요',
                  style: TextStyle(
                    fontSize: 12,
                    color: HomeVisualTokens.dateIconColor,
                  ),
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
                key: const Key('program-edit-add-promo'),
                onPressed: () =>
                    showProgramPromotionSheet(context, store: store),
                child: const Text('추가'),
              ),
            ],
          ),
          for (final p in store.programPromotions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.title),
              subtitle: Text(
                '${p.kind.labelKo} · ${ProgramPricing.formatKrw(p.valueKrw)} 상당',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => store.deleteProgramPromotion(p.id),
              ),
              onTap: () => showProgramPromotionSheet(
                context,
                store: store,
                existing: p,
              ),
            ),
        ],
      ),
    );
  }
}
