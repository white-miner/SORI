import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routing/app_router.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'my_app.dart';
import 'onboarding_page.dart';

/// 공통 랜딩: 카카오 OAuth 단일 로그인.
class EntryHomePage extends StatefulWidget {
  const EntryHomePage({super.key, this.initialToken});

  final String? initialToken;

  @override
  State<EntryHomePage> createState() => _EntryHomePageState();
}

class _EntryHomePageState extends State<EntryHomePage>
    with SingleTickerProviderStateMixin {
  final _store = SoriStore.instance;
  final _auth = SoriAuthService.instance;
  late final AnimationController _fade;
  StreamSubscription<AuthState>? _authSub;
  bool _busy = false;
  bool _handlingAuth = false;

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

    _authSub = _auth.onAuthStateChange.listen(_onAuthState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = _auth.currentSession;
      if (session != null) {
        unawaited(_handleSignedIn(session.user));
        return;
      }
      final local = _store.session;
      if (local != null && local.onboardingComplete) {
        Navigator.of(context).pushReplacementNamed(AppRouter.app);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _fade.dispose();
    super.dispose();
  }

  void _onAuthState(AuthState data) {
    final event = data.event;
    final session = data.session;
    if (session == null) return;
    if (event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.initialSession) {
      unawaited(_handleSignedIn(session.user));
    }
  }

  Future<void> _handleSignedIn(User user) async {
    if (_handlingAuth || !mounted) return;
    _handlingAuth = true;
    try {
      // email null이어도 provider_id 기준으로 세션 구성
      final sessionUser = await _store.hydrateSessionFromAuth(user);
      if (!mounted) return;

      // 원장(shops) / 고객(customers) → 메인 홈
      if (sessionUser.onboardingComplete) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.app,
          (_) => false,
        );
        return;
      }

      if (sessionUser.needsProfileCompletion) {
        final profile = await _collectProfile();
        if (!mounted) return;
        if (profile == null) {
          if (_store.session?.name.trim().isEmpty == true) {
            _store.updateSessionProfile(
              name: SoriAuthService.displayNameFromUser(user),
              phone: _store.session?.phone ?? '',
            );
          }
        } else {
          _store.updateSessionProfile(name: profile.$1, phone: profile.$2);
        }
      }

      if (!mounted) return;
      // 신규 계정 → 원장/고객 선택 온보딩
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } finally {
      _handlingAuth = false;
    }
  }

  Future<void> _kakaoLogin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _auth.signInWithKakao();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('카카오 로그인에 실패했어요: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(String, String)?> _collectProfile() async {
    final nameController = TextEditingController(
      text: _store.session?.name ?? '',
    );
    final phoneController = TextEditingController(
      text: _store.session?.phone.isNotEmpty == true
          ? _store.session!.phone
          : '',
    );

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
              const Text(
                '카카오 로그인',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            colors: [
              SoriTokens.primarySoft,
              Color(0xFFF8F7FC),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: SoriTokens.primary,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: SoriTokens.primary.withValues(alpha: 0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '소통하는 리뷰, SORI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: SoriTokens.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '에스테틱 원장과 고객이 시술 차트와 후기로\n1:1 소통하는 CRM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: CircularProgressIndicator(
                        color: SoriTokens.primary,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: Material(
                      color: const Color(0xFFFEE500),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _busy ? null : _kakaoLogin,
                        borderRadius: BorderRadius.circular(14),
                        child: const Center(
                          child: Text(
                            '카카오로 시작하기',
                            style: TextStyle(
                              color: Color(0xFF191919),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '로그인 시 이용약관·개인정보 처리에 동의하게 됩니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
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
