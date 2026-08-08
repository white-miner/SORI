import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_store.dart';
import 'my_app.dart';
import 'onboarding_page.dart';

/// 공통 랜딩: "소통하는 리뷰, SORI" + 4대 소셜 로그인.
class EntryHomePage extends StatefulWidget {
  const EntryHomePage({super.key, this.initialToken});

  final String? initialToken;

  @override
  State<EntryHomePage> createState() => _EntryHomePageState();
}

class _EntryHomePageState extends State<EntryHomePage>
    with SingleTickerProviderStateMixin {
  final _store = SoriStore.instance;
  late final AnimationController _fade;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    final token = widget.initialToken?.trim();
    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '${AppRouter.review}?token=${Uri.encodeQueryComponent(token)}',
        );
      });
      return;
    }

    final session = _store.session;
    if (session != null && session.onboardingComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRouter.app);
      });
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Future<void> _socialLogin(SocialProvider provider) async {
    if (_busy) return;
    setState(() => _busy = true);

    // 소셜 SDK 연동 전 시뮬레이션 + 필수 프로필 수집.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final profile = await _collectProfile(provider);
    if (!mounted) {
      setState(() => _busy = false);
      return;
    }
    if (profile == null) {
      setState(() => _busy = false);
      return;
    }

    _store.beginSocialLogin(
      provider: provider,
      name: profile.$1,
      phone: profile.$2,
    );

    setState(() => _busy = false);
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const OnboardingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<(String, String)?> _collectProfile(SocialProvider provider) async {
    final nameController = TextEditingController(
      text: switch (provider) {
        SocialProvider.kakao => '김소리',
        SocialProvider.naver => '이소리',
        SocialProvider.google => '박소리',
        SocialProvider.apple => '최소리',
      },
    );
    final phoneController = TextEditingController(text: '010-1234-5678');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${provider == SocialProvider.kakao ? '카카오' : provider == SocialProvider.naver ? '네이버' : provider == SocialProvider.google ? 'Google' : 'Apple'} 로그인',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '소통하는 리뷰를 위해 이름과 전화번호를 확인해 주세요.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '이름 *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '전화번호 *',
                  hintText: '010-0000-0000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty ||
                        SoriStore.normalizePhone(phoneController.text).length <
                            10) {
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MyApp.soriPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('계속하기'),
                ),
              ),
            ],
          ),
        );
      },
    );

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    nameController.dispose();
    phoneController.dispose();
    if (ok == true) return (name, phone);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEDE9FE), Color(0xFFF8F7FC), Colors.white],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '소통하는 리뷰, SORI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '에스테틱 원장과 고객이 시술 차트와 후기로\n1:1 소통하는 CRM',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                  const Spacer(),
                  if (_busy)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: CircularProgressIndicator(color: MyApp.soriPurple),
                      ),
                    ),
                  _SocialButton(
                    label: '카카오로 시작하기',
                    background: const Color(0xFFFEE500),
                    foreground: const Color(0xFF191919),
                    onTap: () => _socialLogin(SocialProvider.kakao),
                  ),
                  const SizedBox(height: 10),
                  _SocialButton(
                    label: '네이버로 시작하기',
                    background: const Color(0xFF03C75A),
                    foreground: Colors.white,
                    onTap: () => _socialLogin(SocialProvider.naver),
                  ),
                  const SizedBox(height: 10),
                  _SocialButton(
                    label: 'Google로 시작하기',
                    background: Colors.white,
                    foreground: const Color(0xFF2D3436),
                    bordered: true,
                    onTap: () => _socialLogin(SocialProvider.google),
                  ),
                  const SizedBox(height: 10),
                  _SocialButton(
                    label: 'Apple로 시작하기',
                    background: Colors.black,
                    foreground: Colors.white,
                    onTap: () => _socialLogin(SocialProvider.apple),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      '로그인 시 이용약관·개인정보 처리에 동의하게 됩니다',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.bordered = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            decoration: bordered
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  )
                : null,
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
