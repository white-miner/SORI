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
import '../widgets/sori_logo.dart';

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
        backgroundColor: SoriTokens.primaryDark,
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

  Widget _buildContent(BuildContext context, {required bool isWide}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SoriLogo(
            forceWhite: true,
            width: SoriLogo.loginWidth(context),
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '소통하는 리뷰',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w300,
            color: Color(0xFF94A3B8),
            height: 1.35,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '에스테틱 원장과 고객이 시술 차트와 후기로\n1:1 소통하는 CRM',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        SizedBox(height: isWide ? 36 : 28),
        if (_showLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: SoriTokens.primary,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '연결 중…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        _KakaoLoginButton(
          enabled: !_showLoading,
          onPressed: _kakaoLogin,
        ),
        const SizedBox(height: 14),
        const Text(
          '로그인 시 이용약관·개인정보 처리에 동의하게 됩니다',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w300,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.paddingOf(context);
    final viewportHeight =
        MediaQuery.sizeOf(context).height - viewPadding.vertical;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // 위버스형 하단 방사 발광 (스플래시 다크와 동일)
          gradient: RadialGradient(
            center: Alignment(0.0, 1.1),
            radius: 0.85,
            colors: [
              SoriTokens.primaryLight,
              Color(0x80047857),
              Color(0x20022C22),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final horizontalPad = isWide ? 32.0 : 28.0;
                final verticalPad = isWide ? 40.0 : 24.0;

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      verticalPad,
                      horizontalPad,
                      verticalPad,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 440 : double.infinity,
                        minHeight: viewportHeight - verticalPad * 2,
                      ),
                      child: isWide
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: SoriTokens.surface.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 40,
                                ),
                                child: _buildContent(context, isWide: true),
                              ),
                            )
                          : _buildContent(context, isWide: false),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 카카오 공식 옐로우 — 다크 무드에 맞춘 미니멀 히트 영역.
class _KakaoLoginButton extends StatelessWidget {
  const _KakaoLoginButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  /// Kakao Brand Guide — #FEE500 / label #191919
  static const Color _kakaoYellow = Color(0xFFFEE500);
  static const Color _kakaoLabel = Color(0xFF191919);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '카카오로 시작하기',
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: Material(
              color: enabled
                  ? _kakaoYellow
                  : _kakaoYellow.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onPressed : null,
                borderRadius: BorderRadius.circular(12),
                splashColor: Colors.black.withValues(alpha: 0.06),
                highlightColor: Colors.black.withValues(alpha: 0.03),
                child: const SizedBox.expand(
                  child: Center(
                    child: Text(
                      '카카오로 시작하기',
                      style: TextStyle(
                        color: _kakaoLabel,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
