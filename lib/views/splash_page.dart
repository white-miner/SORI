import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routing/sori_router.dart';
import '../services/pending_review_return.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';

enum _SplashDest {
  app,
  login,
  onboarding,
  review,
}

/// 브랜드 스플래시 — 통합 로고 이미지 + 세션 체크 후 Fade 전환.
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

  static const String _combinedLogo = 'assets/images/sori_logo1.png';

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
      Future<void>.delayed(const Duration(milliseconds: 800)),
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

    // AuthCoordinator가 PKCE/스토리지 세션 복구를 마칠 때까지 대기
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
    final logoWidth = MediaQuery.of(context).size.width * 0.55;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Image.asset(
                  _combinedLogo,
                  width: logoWidth,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 32,
                child: Text(
                  'Copyright © SORI. All Rights Reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
