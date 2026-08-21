import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../models/shop_service_item.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

/// Shop 탭 — Owner 인라인 편집 (소개·주소·메뉴).
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

  Future<void> _editIdentity() async {
    final nameCtrl = TextEditingController(text: shop.name);
    final bioCtrl = TextEditingController(text: shop.bio);
    final addressCtrl = TextEditingController(text: shop.address ?? '');
    final phoneCtrl = TextEditingController(text: shop.phone ?? '');
    final hoursCtrl = TextEditingController(text: shop.operatingHours);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final inset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + inset),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '샵 정보 수정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '샵 이름'),
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
                const SizedBox(height: 8),
                TextField(
                  controller: hoursCtrl,
                  decoration: const InputDecoration(labelText: '운영시간'),
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

    if (ok != true || !mounted) return;
    store.updateShopProfile(
      name: nameCtrl.text,
      naverPlaceUrl: shop.naverPlaceUrl,
      bio: bioCtrl.text,
      address: addressCtrl.text,
      phone: phoneCtrl.text,
      operatingHours: hoursCtrl.text,
      ownerName: shop.ownerName,
    );
  }

  Future<void> _addOrEditMenu({ShopServiceItem? existing, int? index}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final deviceCtrl =
        TextEditingController(text: existing?.deviceInfo ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final inset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + inset),
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
                decoration: const InputDecoration(labelText: '설명 / 가격'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deviceCtrl,
                decoration: const InputDecoration(labelText: '사용 기기 (선택)'),
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
      deviceInfo: deviceCtrl.text.trim().isEmpty ? null : deviceCtrl.text.trim(),
      keywords: existing?.keywords ?? const [],
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
    final hours = shop.operatingHours.trim();
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
                label: hours.isEmpty ? '운영시간 미등록' : hours,
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
                                if (item.description.trim().isNotEmpty &&
                                    priceLabel == '문의') ...[
                                  const SizedBox(height: 4),
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
                            border: Border.all(color: SoriTokens.outlinePurple),
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
