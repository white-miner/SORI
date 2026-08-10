import 'dart:async';

import 'package:flutter/material.dart';

import '../routing/app_router.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';
import '../widgets/sori_logo.dart';
import 'entry_home_page.dart';
import 'onboarding_page.dart';
import 'app_shell_page.dart';

enum _SplashDest {
  app,
  login,
  onboarding,
  review,
}

/// 브랜드 스플래시 — 세션 체크 후 Fade로 다음 화면 전환 (로그인 깜빡임 방지).
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
    final token = widget.initialToken?.trim() ?? '';

    // 최소 1.5초 노출 + 백그라운드 세션 체크를 병렬 수행
    late final _SplashDest dest;
    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: 1500)),
      () async {
        dest = token.isNotEmpty
            ? _SplashDest.review
            : await _resolveDestination();
      }(),
    ]);

    if (!mounted || _navigated) return;
    _navigated = true;

    if (dest == _SplashDest.review) {
      Navigator.of(context).pushReplacementNamed(
        '${AppRouter.review}?token=${Uri.encodeQueryComponent(token)}',
      );
      return;
    }

    final Widget next = switch (dest) {
      _SplashDest.app => const AppShellPage(),
      _SplashDest.onboarding => const OnboardingPage(),
      _SplashDest.login => const EntryHomePage(),
      _SplashDest.review => const EntryHomePage(),
    };

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => next,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 480),
      ),
    );
  }

  Future<_SplashDest> _resolveDestination() async {
    try {
      final supabaseSession = _auth.currentSession;
      if (supabaseSession != null) {
        final sessionUser =
            await _store.hydrateSessionFromAuth(supabaseSession.user);
        if (sessionUser.onboardingComplete) {
          return _SplashDest.app;
        }
        return _SplashDest.onboarding;
      }
    } catch (e) {
      debugPrint('Splash session hydrate failed: $e');
    }

    final local = _store.session;
    if (local != null && local.onboardingComplete) {
      return _SplashDest.app;
    }
    return _SplashDest.login;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    // 슬로건 시각적 폭과 균형 — 좁은 화면에서도 중앙 정렬 유지
    final logoWidth = (screenW * 0.36).clamp(120.0, 220.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // 정중앙 그룹: 슬로건 + 로고
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '소통하는 리뷰',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6C5CE7),
                      height: 1.2,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SoriLogo(width: logoWidth),
                ],
              ),
              const Spacer(),
              Text(
                'Copyright © SORI. All Rights Reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
