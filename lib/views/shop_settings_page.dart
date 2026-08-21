import 'package:flutter/material.dart';

import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'my_app.dart';

/// 샵 기본 정보 · 운영시간 · SNS 관리 (서비스 메뉴는 별도 페이지).
class ShopSettingsPage extends StatefulWidget {
  const ShopSettingsPage({super.key, this.requireNaver = false});

  final bool requireNaver;

  @override
  State<ShopSettingsPage> createState() => _ShopSettingsPageState();
}

class _ShopSettingsPageState extends State<ShopSettingsPage> {
  final _store = SoriStore.instance;
  late final TextEditingController _nameController;
  late final TextEditingController _ownerController;
  late final TextEditingController _naverController;
  late final TextEditingController _naverBookingController;
  late final TextEditingController _naverReviewWriteController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _hoursController;
  late final TextEditingController _blogController;
  late final TextEditingController _instagramController;
  late final TextEditingController _capaController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final shop = _store.shop;
    _nameController = TextEditingController(text: shop.name);
    _ownerController = TextEditingController(text: shop.ownerName ?? '');
    _naverController = TextEditingController(text: shop.naverPlaceUrl);
    _naverBookingController = TextEditingController(text: shop.naverBookingUrl);
    _naverReviewWriteController =
        TextEditingController(text: shop.naverReviewWriteUrl);
    _addressController = TextEditingController(text: shop.address ?? '');
    _phoneController = TextEditingController(text: shop.phone ?? '');
    _hoursController = TextEditingController(text: shop.operatingHours);
    _blogController = TextEditingController(text: shop.snsBlogUrl);
    _instagramController = TextEditingController(text: shop.snsInstagramUrl);
    _capaController =
        TextEditingController(text: '${shop.monthlyCapa <= 0 ? 100 : shop.monthlyCapa}');
    _bioController = TextEditingController(text: shop.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _naverController.dispose();
    _naverBookingController.dispose();
    _naverReviewWriteController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _hoursController.dispose();
    _blogController.dispose();
    _instagramController.dispose();
    _capaController.dispose();
    _bioController.dispose();
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
      ownerName: _ownerController.text,
      naverPlaceUrl: naver,
      naverBookingUrl: _naverBookingController.text,
      naverReviewWriteUrl: _naverReviewWriteController.text,
      address: _addressController.text,
      phone: _phoneController.text,
      operatingHours: _hoursController.text,
      snsBlogUrl: _blogController.text,
      snsInstagramUrl: _instagramController.text,
      bio: _bioController.text,
      monthlyCapa: int.tryParse(_capaController.text.trim()) ?? 100,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('샵 정보가 저장되었습니다.'),
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
        title: const Text('샵 정보 관리'),
        backgroundColor: SoriTokens.background,
        foregroundColor: SoriTokens.textPrimary,
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
            controller: _ownerController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '대표 원장명',
              hintText: '예: 박종환',
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
            controller: _naverBookingController,
            decoration: const InputDecoration(
              labelText: '네이버 예약 URL',
              hintText: '예약 직행 링크 (피드 CTA)',
              border: OutlineInputBorder(),
              helperText: '비어 있으면 플레이스 URL로 열고, 그것도 없으면 샵 프로필로 이동합니다',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _naverReviewWriteController,
            decoration: const InputDecoration(
              labelText: '네이버 플레이스 리뷰 작성 URL (직행 링크)',
              hintText: '리뷰 작성창으로 바로 열리는 URL',
              border: OutlineInputBorder(),
              helperText: '계산대 후기 CTA가 이 링크로 외부 브라우저를 엽니다',
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
            controller: _capaController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '월간 소화 CAPA (회)',
              hintText: '기본 100 · 잔여 > CAPA×1.2 시 Hell-Zone',
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
            '샵 소개말 (Bio)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            '마이페이지·팬덤 프로필에 노출되는 소개 문구입니다',
            style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '샵 소개말',
              hintText: '예: 피부 장벽과 라인 케어를 섬세하게 다루는 아티스트 샵입니다.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '휴무일 및 운영시간',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            '고객에게 안내할 운영 스케줄을 적어 주세요',
            style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hoursController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '휴무일 및 운영시간',
              hintText: '예: 화–일 10:00–20:00 / 매주 월요일 휴무',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'SNS 채널',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            '블로그·인스타그램 링크를 등록해 주세요',
            style: TextStyle(fontSize: 12, color: SoriTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _blogController,
            decoration: const InputDecoration(
              labelText: '블로그 링크',
              hintText: 'https://blog.naver.com/...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.rss_feed_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instagramController,
            decoration: const InputDecoration(
              labelText: '인스타그램 링크',
              hintText: 'https://www.instagram.com/...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.camera_alt_outlined),
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
