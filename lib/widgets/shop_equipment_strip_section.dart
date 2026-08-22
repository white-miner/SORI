import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/shop_equipment_item.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import 'media_permission_dialogs.dart';

/// Shop 탭 「사용 기기 및 제품」— 3열 가로 스와이프 + 타이포 폴백.
class ShopEquipmentStripSection extends StatelessWidget {
  const ShopEquipmentStripSection({
    super.key,
    required this.store,
    required this.isOwner,
  });

  final SoriStore store;
  final bool isOwner;

  Future<void> _add(BuildContext context) async {
    final nameCtrl = TextEditingController();
    Uint8List? imageBytes;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                16 + soriSheetBottomPadding(ctx),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '기기 · 제품 추가',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      hintText: '예: 테라노바, 셀큐어 프로',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        imageBytes!,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    const Text(
                      '사진은 선택 사항입니다. 없으면 이름만 표시됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () async {
                          final file = await pickImageWithPermissionGuards(
                            context: ctx,
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            imageQuality: 85,
                          );
                          if (file == null) return;
                          final bytes = await file.readAsBytes();
                          setSheet(() => imageBytes = bytes);
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        tooltip: '사진',
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: SoriTokens.primary,
                        ),
                        child: const Text('등록'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok != true || !context.mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    await store.addEquipmentItem(name: name, imageBytes: imageBytes);
  }

  @override
  Widget build(BuildContext context) {
    final items = store.shop.equipmentItems;
    // 메뉴 deviceInfo에서 아직 카드에 없는 이름만 타이포 폴백으로 병합 표시
    final known = {for (final e in items) e.name.trim().toLowerCase()};
    final fromMenu = <ShopEquipmentItem>[];
    for (final m in store.shop.serviceMenu) {
      final d = m.deviceInfo?.trim() ?? '';
      if (d.isEmpty) continue;
      if (known.contains(d.toLowerCase())) continue;
      known.add(d.toLowerCase());
      fromMenu.add(ShopEquipmentItem(id: 'menu-$d', name: d));
    }
    final all = [...items, ...fromMenu];

    final width = MediaQuery.sizeOf(context).width;
    const gap = 8.0;
    const sidePad = 16.0;
    final cardW = (width - sidePad - gap * 2) / 3;
    final cardH = cardW * 1.15;
    final itemCount = all.length + (isOwner ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '사용 기기 및 제품',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: SoriTokens.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: cardH,
          child: itemCount == 0
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '등록된 기기·제품이 없어요',
                      style: TextStyle(
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  itemCount: itemCount,
                  separatorBuilder: (_, _) => const SizedBox(width: gap),
                  itemBuilder: (context, i) {
                    if (isOwner && i == 0) {
                      return _AddEquipTile(
                        width: cardW,
                        height: cardH,
                        onTap: () => _add(context),
                      );
                    }
                    final item = all[isOwner ? i - 1 : i];
                    return _EquipCard(
                      width: cardW,
                      height: cardH,
                      item: item,
                      isOwner: isOwner && items.any((e) => e.id == item.id),
                      onDelete: () {
                        final next = store.shop.equipmentItems
                            .where((e) => e.id != item.id)
                            .toList();
                        store.saveEquipmentItems(next);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AddEquipTile extends StatelessWidget {
  const _AddEquipTile({
    required this.width,
    required this.height,
    required this.onTap,
  });

  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF18181B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: width,
          height: height,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 28, color: SoriTokens.primary),
              SizedBox(height: 6),
              Text(
                '추가',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: SoriTokens.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquipCard extends StatelessWidget {
  const _EquipCard({
    required this.width,
    required this.height,
    required this.item,
    required this.isOwner,
    required this.onDelete,
  });

  final double width;
  final double height;
  final ShopEquipmentItem item;
  final bool isOwner;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.hasImage)
              Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _TypographyFallback(name: item.name),
              )
            else
              _TypographyFallback(name: item.name),
            if (isOwner)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypographyFallback extends StatelessWidget {
  const _TypographyFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF27272A),
            Color(0xFF18181B),
            Color(0xFF1F1830),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: Color(0xFFE4E4E7),
            ),
          ),
        ),
      ),
    );
  }
}
