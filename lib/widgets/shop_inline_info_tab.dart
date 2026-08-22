import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../models/shop_business_hours.dart';
import '../models/shop_service_item.dart';
import '../models/service_menu_chips.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';

/// Shop 탭 — Owner 인라인 편집 (소개·영업시간·메뉴·키워드).
class ShopInlineInfoTab extends StatefulWidget {
  const ShopInlineInfoTab({
    super.key,
    required this.store,
    required this.isOwner,
  });

  final SoriStore store;
  final bool isOwner;

  @override
  State<ShopInlineInfoTab> createState() => _ShopInlineInfoTabState();
}

class _ShopInlineInfoTabState extends State<ShopInlineInfoTab> {
  SoriStore get store => widget.store;
  Shop get shop => store.shop;

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

  Future<void> _editIdentity() => showShopIdentityEditSheet(context, store);

  Future<void> _addOrEditMenu({ShopServiceItem? existing, int? index}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final deviceCtrl =
        TextEditingController(text: existing?.deviceInfo ?? '');
    final selectedChips = <String>{
      ...(existing?.keywords ?? const []).where((e) => e.trim().isNotEmpty),
    };

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? '메뉴 추가' : '메뉴 수정',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: '시술명'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration:
                          const InputDecoration(labelText: '설명 / 가격'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deviceCtrl,
                      decoration:
                          const InputDecoration(labelText: '사용 기기 (선택)'),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '키워드 칩 (다중 선택)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '시술 수단·체감·효과를 골라 주세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: SoriTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...ServiceMenuChips.categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SoriTokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: category.chips.map((chip) {
                                final selected =
                                    selectedChips.contains(chip);
                                return FilterChip(
                                  label: Text(chip),
                                  selected: selected,
                                  onSelected: (v) {
                                    setSheet(() {
                                      if (v) {
                                        selectedChips.add(chip);
                                      } else {
                                        selectedChips.remove(chip);
                                      }
                                    });
                                  },
                                  selectedColor: SoriTokens.primarySoft,
                                  checkmarkColor: SoriTokens.primary,
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: selected
                                        ? SoriTokens.primary
                                        : SoriTokens.textPrimary,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: SoriTokens.primary,
                      ),
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final next = List<ShopServiceItem>.of(shop.serviceMenu);
    final item = ShopServiceItem(
      name: name,
      description: descCtrl.text.trim(),
      deviceInfo:
          deviceCtrl.text.trim().isEmpty ? null : deviceCtrl.text.trim(),
      keywords: selectedChips.toList(),
    );
    if (index != null && index >= 0 && index < next.length) {
      next[index] = item;
    } else {
      next.add(item);
    }
    store.updateShopProfile(
      name: shop.name,
      naverPlaceUrl: shop.naverPlaceUrl,
      serviceMenu: next,
    );
  }

  void _removeMenu(int index) {
    final next = List<ShopServiceItem>.of(shop.serviceMenu)..removeAt(index);
    store.updateShopProfile(
      name: shop.name,
      naverPlaceUrl: shop.naverPlaceUrl,
      serviceMenu: next,
    );
  }

  static String _priceLabel(ShopServiceItem item) {
    final d = item.description.trim();
    if (d.isEmpty) return '문의';
    if (RegExp(r'\d').hasMatch(d) &&
        (d.contains('원') || d.contains('만') || d.contains('₩'))) {
      return d;
    }
    if (RegExp(r'^[\d,]+원?$').hasMatch(d.replaceAll(' ', ''))) {
      return d.endsWith('원') ? d : '$d원';
    }
    return '문의';
  }

  @override
  Widget build(BuildContext context) {
    final menu = shop.serviceMenu;
    final devices = <String>{};
    for (final item in menu) {
      final d = item.deviceInfo?.trim() ?? '';
      if (d.isNotEmpty) devices.add(d);
    }
    final hoursLabel = shop.hoursDisplayLabel;
    final address = (shop.address ?? '').trim();
    final bio = shop.bio.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '샵 정보',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.isOwner)
                    IconButton(
                      tooltip: '수정',
                      onPressed: _editIdentity,
                      icon: const Icon(Icons.edit_outlined),
                      color: SoriTokens.primary,
                    ),
                ],
              ),
              Text(
                shop.name.trim().isEmpty ? 'SORI' : shop.name.trim(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bio,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: SoriTokens.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Line(
                icon: Icons.place_outlined,
                label: address.isEmpty ? '주소 미등록' : address,
              ),
              const SizedBox(height: 10),
              _Line(
                icon: Icons.schedule_rounded,
                label: hoursLabel.isEmpty ? '운영시간 미등록' : hoursLabel,
              ),
              if ((shop.phone ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _Line(
                  icon: Icons.phone_outlined,
                  label: shop.phone!.trim(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '대표 시술 메뉴',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.isOwner)
                    TextButton.icon(
                      onPressed: () => _addOrEditMenu(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        '메뉴 추가',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: SoriTokens.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (menu.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    '등록된 시술 메뉴가 없어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ...List.generate(menu.length, (i) {
                  final item = menu[i];
                  final priceLabel = _priceLabel(item);
                  final keywords = item.keywords
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(height: 20, color: SoriTokens.border),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name.trim().isEmpty
                                      ? '시술'
                                      : item.name.trim(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (keywords.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: keywords
                                        .map(
                                          (k) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF27272A),
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                              border: Border.all(
                                                color: const Color(0xFF3F3F46),
                                              ),
                                            ),
                                            child: Text(
                                              k,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFD4D4D8),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                if (item.description.trim().isNotEmpty &&
                                    priceLabel == '문의') ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.description.trim(),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: SoriTokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            priceLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: priceLabel == '문의'
                                  ? SoriTokens.textSecondary
                                  : SoriTokens.primary,
                            ),
                          ),
                          if (widget.isOwner) ...[
                            IconButton(
                              onPressed: () =>
                                  _addOrEditMenu(existing: item, index: i),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              color: SoriTokens.textSecondary,
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              onPressed: () => _removeMenu(i),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              color: SoriTokens.textSecondary,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '사용 기기 및 제품',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (devices.isEmpty)
                const Text(
                  '등록된 기기 정보가 없어요',
                  style: TextStyle(
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: devices
                      .map(
                        (d) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: SoriTokens.primarySoft,
                            borderRadius: BorderRadius.circular(99),
                            border:
                                Border.all(color: SoriTokens.outlinePurple),
                          ),
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC4B5FD),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: child,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: SoriTokens.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Home/Shop 공용 — 샵·원장 프로필 + 영업시간 편집 시트.
Future<void> showShopIdentityEditSheet(
  BuildContext context,
  SoriStore store,
) async {
  final shop = store.shop;
  final nameCtrl = TextEditingController(text: shop.name);
  final ownerCtrl = TextEditingController(text: shop.ownerName ?? '');
  final bioCtrl = TextEditingController(text: shop.bio);
  final addressCtrl = TextEditingController(text: shop.address ?? '');
  final phoneCtrl = TextEditingController(text: shop.phone ?? '');

  var hours = shop.businessHours.isEmpty
      ? const ShopBusinessHours()
      : shop.businessHours;
  final selectedDays = {...hours.openDays};

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
          Future<void> pickTime({required bool isOpen}) async {
            final initial =
                isOpen ? hours.openTimeOfDay : hours.closeTimeOfDay;
            final picked = await showTimePicker(
              context: ctx,
              initialTime: initial,
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: SoriTokens.primary,
                    surface: SoriTokens.surface,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked == null) return;
            setSheet(() {
              hours = isOpen
                  ? hours.copyWith(
                      openHour: picked.hour,
                      openMinute: picked.minute,
                    )
                  : hours.copyWith(
                      closeHour: picked.hour,
                      closeMinute: picked.minute,
                    );
            });
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              16 + soriSheetBottomPadding(ctx),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '샵 · 원장 프로필',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: '샵 이름'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ownerCtrl,
                    decoration: const InputDecoration(labelText: '원장 이름'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bioCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '소개'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: '주소'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: '전화'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '운영 요일',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '선택하지 않은 요일은 자동으로 휴무로 표시됩니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final selected = selectedDays.contains(day);
                      return FilterChip(
                        label: Text(ShopBusinessHours.dayLabel(day)),
                        selected: selected,
                        onSelected: (v) {
                          setSheet(() {
                            if (v) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                        selectedColor: SoriTokens.primarySoft,
                        checkmarkColor: SoriTokens.primary,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? SoriTokens.primary
                              : SoriTokens.textPrimary,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '오픈 / 마감 시간',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickTime(isOpen: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SoriTokens.primary,
                            side: const BorderSide(
                              color: SoriTokens.outlinePurple,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            '오픈 ${hours.openTimeLabel}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickTime(isOpen: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SoriTokens.primary,
                            side: const BorderSide(
                              color: SoriTokens.outlinePurple,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            '마감 ${hours.closeTimeLabel}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ShopBusinessHours(
                      openDays: selectedDays,
                      openHour: hours.openHour,
                      openMinute: hours.openMinute,
                      closeHour: hours.closeHour,
                      closeMinute: hours.closeMinute,
                    ).formatDisplay(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: SoriTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: SoriTokens.primary,
                    ),
                    child: const Text('저장'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (ok != true) return;
  final saved = ShopBusinessHours(
    openDays: selectedDays,
    openHour: hours.openHour,
    openMinute: hours.openMinute,
    closeHour: hours.closeHour,
    closeMinute: hours.closeMinute,
  );
  store.updateShopProfile(
    name: nameCtrl.text,
    naverPlaceUrl: shop.naverPlaceUrl,
    bio: bioCtrl.text,
    address: addressCtrl.text,
    phone: phoneCtrl.text,
    businessHours: saved,
    operatingHours: saved.isEmpty ? '' : saved.formatDisplay(),
    ownerName: ownerCtrl.text,
  );
}

