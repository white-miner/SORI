import 'package:flutter/material.dart';

import '../models/shop_service_item.dart';
import '../services/openai_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'my_app.dart';

/// 서비스 메뉴 관리 — 서비스명 + 고객 안내 설명 + AI 윤문.
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

  Future<void> _polishAt(int index) async {
    final draft = _items[index];
    final name = draft.name.text.trim();
    final desc = draft.description.text.trim();
    if (name.isEmpty && desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서비스명 또는 설명을 먼저 입력해 주세요'),
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
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const Text('서비스 메뉴 관리'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
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
                color: Colors.white,
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: item.description,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '고객 안내용 설명',
                          hintText: '예: 탄력·라인 정리에 도움되는 EMS 케어',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
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
  });

  final TextEditingController name;
  final TextEditingController description;
  bool polishing = false;

  void dispose() {
    name.dispose();
    description.dispose();
  }
}
