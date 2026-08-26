import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routing/sori_router.dart';
import '../services/pending_review_return.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';
import '../widgets/sori_logo.dart';

enum _SplashDest {
  app,
  login,
  onboarding,
  review,
}

/// 위버스/캔바 스타일 스플래시 — 상단 80% 단색 + 하단 20% 앰비언트 글로우.
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

  /// 위버스형: 바닥 정중앙에서 피어오르는 방사형 발광 (PO 수치 고정).
  RadialGradient _weverseGlow(bool isDark) {
    if (isDark) {
      return const RadialGradient(
        center: Alignment(0.0, 1.1),
        radius: 0.85,
        colors: [
          Color(0xFF00E599),
          Color(0x80047857),
          Color(0x20022C22),
          Color(0xFF000000),
        ],
        stops: [0.0, 0.35, 0.65, 1.0],
      );
    }
    return const RadialGradient(
      center: Alignment(0.0, 1.1),
      radius: 0.85,
      colors: [
        Color(0x5010B981),
        Color(0x2034D399),
        Color(0x08A7F3D0),
        Color(0xFFFFFFFF),
      ],
      stops: [0.0, 0.30, 0.60, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final logoWidth = SoriLogo.responsiveWidth(context);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: _weverseGlow(isDark)),
          ),
          SafeArea(
            child: Center(
              child: SoriLogo(
                width: logoWidth,
                fit: BoxFit.contain,
                usePlatformBrightness: true,
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
                fontWeight: FontWeight.w300,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.34)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
