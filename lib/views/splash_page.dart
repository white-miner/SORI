import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/sori_router.dart';
import '../services/pending_review_return.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';
import 'onboarding_page.dart';

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
        context.go(PendingReviewReturn.reviewLocation(reviewToken));
        return;
      }
    }

    if (dest == _SplashDest.onboarding) {
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 480),
        ),
      );
      return;
    }

    context.go(
      dest == _SplashDest.app ? AppPaths.appHome : AppPaths.login,
    );
  }

  Future<_SplashDest> _resolveDestination() async {
    if ((PendingReviewReturn.peek() ?? '').isNotEmpty) {
      return _SplashDest.review;
    }
    try {
      final supabaseSession = _auth.currentSession;
      if (supabaseSession != null) {
        final sessionUser =
            await _store.hydrateSessionFromAuth(supabaseSession.user);
        if (sessionUser.onboardingComplete) return _SplashDest.app;
        return _SplashDest.onboarding;
      }
    } catch (e) {
      debugPrint('splash auth hydrate skipped: $e');
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
