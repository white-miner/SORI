import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/session_user.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'my_app.dart';

/// 카카오 로그인 직후 온보딩: 역할 선택 → (고객)연락처 / (원장)샵 등록.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

enum _OnboardStep { role, customerContact, shop }

class _OnboardingPageState extends State<OnboardingPage> {
  final _store = SoriStore.instance;
  _OnboardStep _step = _OnboardStep.role;

  final _shopName = TextEditingController();
  final _shopPhone = TextEditingController();
  final _naverUrl = TextEditingController();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shopName.text = '나의 에스테틱';
    _shopPhone.text = '';
    _naverUrl.text = 'https://m.place.naver.com/place/';
    // 카카오 닉네임이 있으면 고객 폼 초깃값으로만 힌트 (필수는 역할 선택 후)
    final hintName = _store.session?.name.trim() ?? '';
    if (hintName.isNotEmpty && hintName != '카카오 회원' && hintName != '소리 회원') {
      _customerName.text = hintName;
    }
  }

  @override
  void dispose() {
    _shopName.dispose();
    _shopPhone.dispose();
    _naverUrl.dispose();
    _customerName.dispose();
    _customerPhone.dispose();
    super.dispose();
  }

  void _goApp() {
    context.go(AppPaths.appHome);
  }

  void _selectDirector() {
    _store.completeRoleSelection(UserRole.director);
    setState(() => _step = _OnboardStep.shop);
  }

  void _selectCustomer() {
    setState(() => _step = _OnboardStep.customerContact);
  }

  Future<void> _submitCustomerContact() async {
    final name = _customerName.text.trim();
    final phone = _customerPhone.text.trim();
    if (name.isEmpty || SoriStore.normalizePhone(phone).length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이름과 연락처를 정확히 입력해 주세요.'),
          backgroundColor: SoriTokens.systemRed,
        ),
      );
      return;
    }
    _store.updateSessionProfile(name: name, phone: phone);
    await _store.completeCustomerOnboarding(name: name, phone: phone);
    if (!mounted) return;
    _goApp();
  }

  void _submitShop() {
    if (_shopName.text.trim().isEmpty ||
        SoriStore.normalizePhone(_shopPhone.text).length < 9 ||
        !_naverUrl.text.trim().startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('상호명·대표 전화·네이버 플레이스 URL을 모두 입력해 주세요.'),
          backgroundColor: SoriTokens.systemRed,
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

  String get _appBarTitle => switch (_step) {
        _OnboardStep.role => '역할 선택',
        _OnboardStep.customerContact => '고객 정보',
        _OnboardStep.shop => '샵 등록',
      };

  @override
  Widget build(BuildContext context) {
    final session = _store.session;
    if (session == null) {
      return const Scaffold(body: Center(child: Text('세션이 없습니다')));
    }

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: SoriTokens.textPrimary,
        title: Text(_appBarTitle),
        leading: _step == _OnboardStep.role
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = _OnboardStep.role),
              ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: switch (_step) {
          _OnboardStep.role => _RoleStep(
              key: const ValueKey('role'),
              provider: session.providerLabel,
              onDirector: _selectDirector,
              onCustomer: _selectCustomer,
            ),
          _OnboardStep.customerContact => _CustomerContactStep(
              key: const ValueKey('customer'),
              name: _customerName,
              phone: _customerPhone,
              onSubmit: _submitCustomerContact,
            ),
          _OnboardStep.shop => _ShopStep(
              key: const ValueKey('shop'),
              shopName: _shopName,
              shopPhone: _shopPhone,
              naverUrl: _naverUrl,
              onSubmit: _submitShop,
            ),
        },
      ),
    );
  }
}

class _RoleStep extends StatelessWidget {
  const _RoleStep({
    super.key,
    required this.provider,
    required this.onDirector,
    required this.onCustomer,
  });

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
          const Text(
            '어떻게 시작할까요?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$provider 계정으로 로그인되었습니다. 역할을 먼저 선택해 주세요.',
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
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SoriTokens.border),
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
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

class _CustomerContactStep extends StatelessWidget {
  const _CustomerContactStep({
    super.key,
    required this.name,
    required this.phone,
    required this.onSubmit,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        const Text(
          '후기 차트 매칭을 위해\n이름과 연락처가 필요해요',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.35),
        ),
        const SizedBox(height: 8),
        Text(
          '샵에서 작성한 차트와 연결하려면 실제 성함·전화번호를 입력해 주세요.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '이름 *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            labelText: '연락처 *',
            hintText: '010-0000-0000',
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
          child: const Text(
            '저장하고 홈으로',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _ShopStep extends StatelessWidget {
  const _ShopStep({
    super.key,
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
          '원장님 개인 이름·연락처는 나중에 샵 관리에서 입력할 수 있어요.',
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
          child: const Text(
            '등록하고 홈으로',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
