import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routing/sori_router.dart';
import '../services/pending_review_return.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_logo.dart';

enum _SplashDest {
  app,
  login,
  onboarding,
  review,
}

/// 위버스/캔바 스타일 글래스모피즘 스플래시 — 시스템 Brightness 반응형.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.initialToken});

  final String? initialToken;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _store = SoriStore.instance;
  final _auth = SoriAuthService.instance;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapAndRoute());
    });
  }

  Future<void> _bootstrapAndRoute() async {
    final tokenFromQuery = PendingReviewReturn.peek() ?? '';
    final token = widget.initialToken?.trim().isNotEmpty == true
        ? widget.initialToken!.trim()
        : tokenFromQuery;

    late final _SplashDest dest;
    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: 900)),
      () async {
        dest = token.isNotEmpty
            ? _SplashDest.review
            : await _resolveDestination();
      }(),
    ]);

    if (!mounted || _navigated) return;
    _navigated = true;

    if (dest == _SplashDest.review) {
      final reviewToken = token.isNotEmpty
          ? token
          : (PendingReviewReturn.take() ?? '');
      if (reviewToken.isNotEmpty) {
        PendingReviewReturn.save(reviewToken);
        debugPrint('[Auth] Splash → review');
        context.go(PendingReviewReturn.reviewLocation(reviewToken));
        return;
      }
    }

    final target = switch (dest) {
      _SplashDest.app => AppPaths.appHome,
      _SplashDest.onboarding => AppPaths.onboarding,
      _ => AppPaths.login,
    };
    debugPrint('[Auth] Splash → $target');
    context.go(target);
  }

  Future<_SplashDest> _resolveDestination() async {
    if ((PendingReviewReturn.peek() ?? '').isNotEmpty) {
      return _SplashDest.review;
    }

    var waited = 0;
    while (_store.authHydrating && waited < 60) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waited++;
    }

    try {
      final supabaseSession = _auth.currentSession;
      if (supabaseSession != null) {
        debugPrint('[Auth] Splash found supabase session');
        if (_store.session?.onboardingComplete == true) {
          return _SplashDest.app;
        }
        final sessionUser = _store.session ??
            await _store.hydrateSessionFromAuth(supabaseSession.user);
        if (sessionUser.onboardingComplete) return _SplashDest.app;
        return _SplashDest.onboarding;
      }
    } on AuthException catch (e) {
      debugPrint('[Auth] Splash auth expired: ${e.message}');
      _store.clearAuthSession(localOnly: true);
    } catch (e) {
      debugPrint('[Auth] Splash auth hydrate skipped: $e');
    }

    final local = _store.session;
    if (local != null && local.onboardingComplete) return _SplashDest.app;
    if (local != null && !local.onboardingComplete) {
      return _SplashDest.onboarding;
    }
    return _SplashDest.login;
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final logoWidth = (size.width * 0.48).clamp(148.0, 280.0);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isDark
                    ? const [
                        Color(0xE600D289), // glass emerald (strong)
                        Color(0x9900D289),
                        Color(0x3300D289),
                        Color(0x0A00D289),
                        Color(0xFF000000),
                      ]
                    : const [
                        Color(0xCC00D289),
                        Color(0x6600D289),
                        Color(0x2800D289),
                        Color(0x0D00D289),
                        Color(0xFFFFFFFF),
                      ],
                stops: const [0.0, 0.18, 0.38, 0.58, 0.88],
              ),
            ),
          ),
          // 하단 발광 보케 — 글래스 심도
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                child: Container(
                  width: size.width * 1.15,
                  height: size.height * 0.42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        SoriTokens.primaryLight.withValues(
                          alpha: isDark ? 0.55 : 0.42,
                        ),
                        SoriTokens.primary.withValues(
                          alpha: isDark ? 0.22 : 0.16,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 떠 있는 느낌 — 소프트 그림자
                  DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.black : Colors.black)
                              .withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                        if (isDark)
                          BoxShadow(
                            color: SoriTokens.primary.withValues(alpha: 0.18),
                            blurRadius: 36,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: SoriLogo(
                      width: logoWidth,
                      usePlatformBrightness: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.paddingOf(context).bottom + 28,
            child: Text(
              'Copyright © SORI. All Rights Reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.38)
                    : Colors.black.withValues(alpha: 0.38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
