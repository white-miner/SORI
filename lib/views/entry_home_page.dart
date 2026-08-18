import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routing/sori_router.dart';
import '../services/pending_review_return.dart';
import '../services/sori_auth_coordinator.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

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
  final _coordinator = SoriAuthCoordinator.instance;
  late final AnimationController _fade;
  StreamSubscription<AuthState>? _authSub;
  bool _busy = false;
  bool _routing = false;
  String? _shownAuthError;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _store.addListener(_onStoreChanged);

    final token = widget.initialToken?.trim();
    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(
          '${AppPaths.review}?token=${Uri.encodeQueryComponent(token)}',
        );
      });
      return;
    }

    _authSub = _auth.onAuthStateChange.listen(_onAuthState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_postLoginRouteIfReady(reason: 'postFrame'));
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _store.removeListener(_onStoreChanged);
    _fade.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    final err = _store.authError;
    if (err != null && err != _shownAuthError) {
      _shownAuthError = err;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showAuthError(err);
        _store.clearAuthError();
      });
    }
    setState(() {});
    if (_auth.currentSession != null || _store.session != null) {
      unawaited(_postLoginRouteIfReady(reason: 'storeChanged'));
    }
  }

  void _onAuthState(AuthState data) {
    debugPrint('[Auth] EntryHome event=${data.event.name}');
    if (data.event == AuthChangeEvent.signedOut) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (data.session == null) return;
    if (data.event == AuthChangeEvent.signedIn ||
        data.event == AuthChangeEvent.initialSession ||
        data.event == AuthChangeEvent.tokenRefreshed) {
      unawaited(_postLoginRouteIfReady(reason: data.event.name));
    }
  }

  Future<void> _postLoginRouteIfReady({required String reason}) async {
    if (_routing || !mounted) return;

    final supabaseSession = _auth.currentSession;
    if (supabaseSession == null && _store.session == null) return;

    _routing = true;
    debugPrint('[Auth] EntryHome route check ($reason)');
    try {
      if (supabaseSession != null && !_store.authHydrating) {
        await _coordinator.ensureHydratedFromCurrentSession();
      }

      while (_store.authHydrating && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      if (!mounted) return;

      final sessionUser = _store.session;
      if (sessionUser == null) return;

      final pendingReview = PendingReviewReturn.take();
      if (pendingReview != null && pendingReview.isNotEmpty) {
        debugPrint('[Auth] EntryHome → review');
        context.go(PendingReviewReturn.reviewLocation(pendingReview));
        return;
      }

      if (sessionUser.onboardingComplete) {
        debugPrint('[Auth] EntryHome → appHome');
        context.go(AppPaths.appHome);
        return;
      }

      debugPrint('[Auth] EntryHome → onboarding');
      context.go(AppPaths.onboarding);
    } catch (e, st) {
      debugPrint('[Auth] EntryHome route failed: $e\n$st');
      if (mounted) _showAuthError(SoriAuthService.userMessage(e));
    } finally {
      _routing = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAuthError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _kakaoLogin() async {
    if (_busy || _store.authHydrating) return;
    setState(() {
      _busy = true;
      _shownAuthError = null;
    });
    _store.clearAuthError();
    debugPrint('[Auth] EntryHome kakao tap');
    try {
      final launched = await _auth.signInWithKakao();
      if (!launched && mounted) {
        _showAuthError('카카오 로그인 창을 열지 못했어요. 팝업 차단을 확인해 주세요.');
      }
      // 웹 OAuth는 리다이렉트되므로 _busy는 복귀 시 splash/login에서 해제됨.
      if (!mounted) return;
      if (!launched) setState(() => _busy = false);
    } on AuthException catch (e) {
      debugPrint('[Auth] EntryHome AuthException: ${e.message}');
      if (!mounted) return;
      _showAuthError(SoriAuthService.userMessage(e));
      setState(() => _busy = false);
    } catch (e, st) {
      debugPrint('[Auth] EntryHome login error: $e\n$st');
      if (!mounted) return;
      _showAuthError(SoriAuthService.userMessage(e));
      setState(() => _busy = false);
    }
  }

  bool get _showLoading => _busy || _store.authHydrating || _routing;

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
                  Image.asset(
                    'assets/images/sori_logo.png',
                    width: MediaQuery.of(context).size.width * 0.38,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '소통하는 리뷰',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6C5CE7),
                      height: 1.3,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '에스테틱 원장과 고객이 시술 차트와 후기로\n1:1 소통하는 CRM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                      height: 1.45,
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (_showLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            color: SoriTokens.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _store.authHydrating
                                ? '프로필을 불러오는 중…'
                                : '카카오 로그인 연결 중…',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: Material(
                      color: const Color(0xFFFEE500),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _showLoading ? null : _kakaoLogin,
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
