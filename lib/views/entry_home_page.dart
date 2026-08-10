import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routing/app_router.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
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
    // 스플래시에서 세션 라우팅을 담당. 여기서는 OAuth 콜백(signedIn)만 처리해
    // 로그인 화면 깜빡임을 막는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 이미 로그인된 상태로 /login에 직접 진입한 경우만 복구
      final session = _auth.currentSession;
      if (session != null) {
        unawaited(_handleSignedIn(session.user));
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

      // 원장/고객으로 이미 연결된 계정 → 메인 홈
      if (sessionUser.onboardingComplete) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.app,
          (_) => false,
        );
        return;
      }

      if (!mounted) return;
      // 신규: 역할 선택 화면으로 (이름/연락처 사전 입력 없음)
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
