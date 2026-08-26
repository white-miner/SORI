import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routing/sori_router.dart';
import '../services/pending_review_return.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_brand_assets.dart';
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

  /// 다단계 stops로 밴딩 없는 글래스 광원 확산.
  LinearGradient _glassGradient(bool isDark) {
    if (isDark) {
      // 하단 네온 에메랄드(글래스) → 딥 에메랄드/차콜 → 순수 블랙
      return const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Color(0x4010B981), // #10B981 @ 25%
          Color(0x2E10B981), // ~18%
          Color(0x1A0F766E), // deep teal wash
          Color(0xFF0A0A0A), // near-black charcoal
          Color(0xFF000000),
        ],
        stops: [0.0, 0.28, 0.52, 0.78, 1.0],
      );
    }
    // 하단 소프트 에메랄드 → 밀키 민트 → 순수 화이트
    return const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Color(0x3334D399), // #34D399 @ 20%
        Color(0x2634D399), // ~15%
        Color(0x0D6EE7B7), // milky mint ~5%
        Color(0xFFF8FFFB),
        Color(0xFFFFFFFF),
      ],
      stops: [0.0, 0.30, 0.55, 0.82, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(gradient: _glassGradient(isDark))),
          // 하단 soft glow — 그라데이션 밴딩을 추가로 완화
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 56, sigmaY: 56),
                child: Container(
                  width: size.width * 1.2,
                  height: size.height * 0.48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark
                                ? const Color(0xFF10B981)
                                : const Color(0xFF34D399))
                            .withValues(alpha: isDark ? 0.28 : 0.20),
                        (isDark
                                ? const Color(0xFF10B981)
                                : const Color(0xFF34D399))
                            .withValues(alpha: isDark ? 0.10 : 0.07),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    if (isDark)
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        blurRadius: 32,
                      ),
                  ],
                ),
                child: const SoriLogo(
                  height: SoriBrandAssets.logoHeightHero,
                  usePlatformBrightness: true,
                ),
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
