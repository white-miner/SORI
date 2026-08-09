import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'my_app.dart';

class ShopSettingsPage extends StatefulWidget {
  const ShopSettingsPage({super.key, this.requireNaver = false});

  final bool requireNaver;

  @override
  State<ShopSettingsPage> createState() => _ShopSettingsPageState();
}

class _ShopSettingsPageState extends State<ShopSettingsPage> {
  final _store = SoriStore.instance;
  late final TextEditingController _nameController;
  late final TextEditingController _naverController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _menuInputController;
  late List<String> _serviceMenu;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _store.shop.name);
    _naverController = TextEditingController(text: _store.shop.naverPlaceUrl);
    _addressController = TextEditingController(text: _store.shop.address ?? '');
    _phoneController = TextEditingController(text: _store.shop.phone ?? '');
    _menuInputController = TextEditingController();
    _serviceMenu = List<String>.from(_store.shop.serviceMenu);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _naverController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _menuInputController.dispose();
    super.dispose();
  }

  void _addMenuItem() {
    final name = _menuInputController.text.trim();
    if (name.isEmpty) return;
    if (_serviceMenu.any((e) => e.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 등록된 서비스명이에요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _serviceMenu = [..._serviceMenu, name];
      _menuInputController.clear();
    });
  }

  void _removeMenuItem(String name) {
    setState(() => _serviceMenu = _serviceMenu.where((e) => e != name).toList());
  }

  void _save() {
    final naver = _naverController.text.trim();
    if (naver.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 플레이스 URL은 필수입니다.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      return;
    }

    _store.updateShopProfile(
      name: _nameController.text,
      naverPlaceUrl: naver,
      address: _addressController.text,
      phone: _phoneController.text,
      serviceMenu: _serviceMenu,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('샵 프로필·서비스 메뉴가 저장되었습니다.'),
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
        title: const Text('샵 관리'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.requireNaver)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: MyApp.soriPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '첫 방문 고객의 [네이버에 등록하기] 딥링크에 사용됩니다. 반드시 등록해 주세요.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '샵 이름 *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _naverController,
            decoration: const InputDecoration(
              labelText: '네이버 플레이스 URL *',
              hintText: 'https://m.place.naver.com/...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '샵 연락처',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: '주소',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '서비스 메뉴 관리',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '차트·회원권 드롭다운에 노출됩니다 (예: EMS 윤곽케어, 테라노바 복부관리)',
            style: TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _menuInputController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addMenuItem(),
                  decoration: const InputDecoration(
                    labelText: '서비스명 추가',
                    hintText: '예: EMS 윤곽케어',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addMenuItem,
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                ),
                child: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_serviceMenu.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SoriTokens.border),
              ),
              child: const Text(
                '등록된 서비스가 없습니다. 위에서 추가해 주세요.',
                style: TextStyle(color: SoriTokens.textSecondary),
              ),
            )
          else
            ..._serviceMenu.map(
              (name) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: IconButton(
                    tooltip: '삭제',
                    onPressed: () => _removeMenuItem(name),
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: MyApp.soriPurple,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              '저장하기',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
