import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import 'my_app.dart';

/// 소셜 로그인 직후 저마찰 온보딩 스텝 (역할 → 샵 설정).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _store = SoriStore.instance;
  final _pageController = PageController();
  int _step = 0;

  final _shopName = TextEditingController();
  final _shopPhone = TextEditingController();
  final _naverUrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shopName.text = '나의 에스테틱';
    _shopPhone.text = _store.session?.phone ?? '';
    _naverUrl.text = 'https://m.place.naver.com/place/';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _shopName.dispose();
    _shopPhone.dispose();
    _naverUrl.dispose();
    super.dispose();
  }

  void _goApp() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.app,
      (_) => false,
    );
  }

  void _selectRole(UserRole role) {
    final session = _store.completeRoleSelection(role);
    if (role == UserRole.customer) {
      _goApp();
      return;
    }
    if (!session.shopSetupComplete) {
      setState(() => _step = 1);
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goApp();
    }
  }

  void _submitShop() {
    if (_shopName.text.trim().isEmpty ||
        SoriStore.normalizePhone(_shopPhone.text).length < 9 ||
        !_naverUrl.text.trim().startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('상호명·대표 전화·네이버 플레이스 URL을 모두 입력해 주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    _store.completeShopSetup(
      shopName: _shopName.text,
      shopPhone: _shopPhone.text,
      naverPlaceUrl: _naverUrl.text,
    );
    _goApp();
  }

  @override
  Widget build(BuildContext context) {
    final session = _store.session;
    if (session == null) {
      return const Scaffold(body: Center(child: Text('세션이 없습니다')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2D3436),
        title: Text(_step == 0 ? '프로필 설정' : '샵 등록'),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _RoleStep(
            name: session.name,
            provider: session.providerLabel,
            onDirector: () => _selectRole(UserRole.director),
            onCustomer: () => _selectRole(UserRole.customer),
          ),
          _ShopStep(
            shopName: _shopName,
            shopPhone: _shopPhone,
            naverUrl: _naverUrl,
            onSubmit: _submitShop,
          ),
        ],
      ),
    );
  }
}

class _RoleStep extends StatelessWidget {
  const _RoleStep({
    required this.name,
    required this.provider,
    required this.onDirector,
    required this.onCustomer,
  });

  final String name;
  final String provider;
  final VoidCallback onDirector;
  final VoidCallback onCustomer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name님, 어떻게 시작할까요?',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$provider 계정으로 로그인되었습니다. 역할을 선택하면 바로 홈으로 이동합니다.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 28),
          _RoleCard(
            title: '원장님으로 시작',
            subtitle: '차트 작성 · QR/링크 발송 · 샵 관리',
            icon: Icons.spa_outlined,
            onTap: onDirector,
          ),
          const SizedBox(height: 12),
          _RoleCard(
            title: '고객님으로 시작',
            subtitle: '내 시술 리포트 · 소통하는 리뷰 타임라인',
            icon: Icons.favorite_outline,
            onTap: onCustomer,
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: MyApp.soriPurple.withValues(alpha: 0.12),
                child: Icon(icon, color: MyApp.soriPurple),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopStep extends StatelessWidget {
  const _ShopStep({
    required this.shopName,
    required this.shopPhone,
    required this.naverUrl,
    required this.onSubmit,
  });

  final TextEditingController shopName;
  final TextEditingController shopPhone;
  final TextEditingController naverUrl;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        const Text(
          '샵 프로필을 등록해 주세요',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '네이버 플레이스 URL은 첫 방문 고객의 [네이버에 등록하기] 딥링크에 사용됩니다.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: shopName,
          decoration: const InputDecoration(
            labelText: '에스테틱 샵 상호명 *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: shopPhone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: '샵 대표 전화번호 *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: naverUrl,
          decoration: const InputDecoration(
            labelText: '네이버 플레이스 URL *',
            hintText: 'https://m.place.naver.com/...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: MyApp.soriPurple,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('등록하고 홈으로', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
