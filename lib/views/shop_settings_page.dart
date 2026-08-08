import 'package:flutter/material.dart';

import '../services/sori_store.dart';
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _store.shop.name);
    _naverController = TextEditingController(text: _store.shop.naverPlaceUrl);
    _addressController = TextEditingController(text: _store.shop.address ?? '');
    _phoneController = TextEditingController(text: _store.shop.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _naverController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
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
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('샵 프로필이 저장되었습니다.'),
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
        title: const Text('샵 프로필 설정'),
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
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: MyApp.soriPurple,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('저장하기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
