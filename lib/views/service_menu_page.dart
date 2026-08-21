import 'package:flutter/material.dart';

import '../models/service_menu_chips.dart';
import '../models/shop_service_item.dart';
import '../services/openai_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'my_app.dart';

/// 서비스 메뉴 관리 — 서비스명 + 키워드 칩 + 자유 코멘트 + AI 윤문.
class ServiceMenuPage extends StatefulWidget {
  const ServiceMenuPage({super.key});

  @override
  State<ServiceMenuPage> createState() => _ServiceMenuPageState();
}

class _ServiceMenuPageState extends State<ServiceMenuPage> {
  final _store = SoriStore.instance;
  final _openai = OpenAiService();
  late List<_ServiceDraft> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = _store.shop.serviceMenu
        .map(
          (e) => _ServiceDraft(
            name: TextEditingController(text: e.name),
            description: TextEditingController(text: e.description),
            device: TextEditingController(text: e.deviceInfo ?? ''),
            initialChips: e.keywords,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items = [
        ..._items,
        _ServiceDraft(
          name: TextEditingController(),
          description: TextEditingController(),
          device: TextEditingController(),
        ),
      ];
    });
  }

  void _removeAt(int index) {
    setState(() {
      _items[index].dispose();
      _items = [..._items]..removeAt(index);
    });
  }

  void _toggleChip(int index, String chip, bool selected) {
    setState(() {
      final selectedChips = _items[index].selectedChips;
      if (selected) {
        selectedChips.add(chip);
      } else {
        selectedChips.remove(chip);
      }
    });
  }

  Future<void> _polishAt(int index) async {
    final draft = _items[index];
    final name = draft.name.text.trim();
    final desc = draft.description.text.trim();
    final chips = draft.selectedChips.toList();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서비스명을 먼저 입력해 주세요 (타겟 부위 추론에 필요해요)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (desc.isEmpty && chips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('키워드 칩 또는 자유 코멘트를 입력해 주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => draft.polishing = true);
    try {
      final polished = await _openai.polishServiceDescription(
        serviceName: name,
        roughDescription: desc,
        selectedChips: chips,
        shopName: _store.shop.name,
      );
      if (!mounted) return;
      draft.description.text = polished;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI가 설명을 다듬었어요'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SoriTokens.primary,
        ),
      );
    } on OpenAiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => draft.polishing = false);
    }
  }

  Future<void> _save() async {
    final menu = <ShopServiceItem>[];
    final seen = <String>{};
    for (final item in _items) {
      final name = item.name.text.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.contains(key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('중복된 서비스명이에요: $name'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      seen.add(key);
      menu.add(
        ShopServiceItem(
          name: name,
          description: item.description.text.trim(),
          keywords: item.selectedChips.toList(),
          deviceInfo: () {
            final d = item.device.text.trim();
            return d.isEmpty ? null : d;
          }(),
        ),
      );
    }

    setState(() => _saving = true);
    _store.updateShopProfile(
      name: _store.shop.name,
      naverPlaceUrl: _store.shop.naverPlaceUrl,
      address: _store.shop.address,
      phone: _store.shop.phone,
      operatingHours: _store.shop.operatingHours,
      snsBlogUrl: _store.shop.snsBlogUrl,
      snsInstagramUrl: _store.shop.snsInstagramUrl,
      serviceMenu: menu,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('서비스 메뉴가 저장되었습니다.'),
        backgroundColor: MyApp.soriPurple,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('서비스 메뉴 관리'),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '차트·회원권 선택과 고객 안내에 사용됩니다',
            style: TextStyle(fontSize: 13, color: SoriTokens.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SoriTokens.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SoriTokens.border),
              ),
              child: const Text(
                '등록된 서비스가 없습니다. 아래에서 추가해 주세요.',
                style: TextStyle(color: SoriTokens.textSecondary),
              ),
            )
          else
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: SoriTokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: SoriTokens.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: item.name,
                              decoration: const InputDecoration(
                                labelText: '서비스명',
                                hintText: '예: EMS 윤곽케어',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '삭제',
                            onPressed: () => _removeAt(index),
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: Colors.redAccent,
                          ),
                        ],
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
                        '시술 수단·체감·효과를 골라 주세요. 성분명은 아래 자유 코멘트에 적어 주세요.',
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
                                      item.selectedChips.contains(chip);
                                  return FilterChip(
                                    label: Text(chip),
                                    selected: selected,
                                    onSelected: (v) =>
                                        _toggleChip(index, chip, v),
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
                      TextField(
                        controller: item.description,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '자유 코멘트 / 고객 안내용 설명',
                          hintText:
                              '예: 아줄렌·비타민C 사용, 민감 피부도 OK 등 구체 메모',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: item.device,
                        decoration: const InputDecoration(
                          labelText: '사용 기기 (선택 사항)',
                          hintText: '예: 테라노바, EMS 리프팅, 셀큐어',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed:
                              item.polishing ? null : () => _polishAt(index),
                          icon: item.polishing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('✨', style: TextStyle(fontSize: 14)),
                          label: Text(
                            item.polishing ? '다듬는 중…' : 'AI 문장 다듬기',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SoriTokens.primary,
                            side: const BorderSide(color: SoriTokens.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              '+ 서비스 추가',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: SoriTokens.primary,
              side: const BorderSide(color: SoriTokens.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: MyApp.soriPurple,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _saving ? '저장 중…' : '저장하기',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceDraft {
  _ServiceDraft({
    required this.name,
    required this.description,
    required this.device,
    List<String> initialChips = const [],
  }) : selectedChips = {...initialChips.where((e) => e.trim().isNotEmpty)};

  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController device;
  final Set<String> selectedChips;
  bool polishing = false;

  void dispose() {
    name.dispose();
    description.dispose();
    device.dispose();
  }
}
