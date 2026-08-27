import 'dart:async';

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

/// White minimal splash — off-white canvas + centered brand logo.
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
      if (!mounted) return;
      unawaited(SoriLogo.precache(context));
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
    final logoWidth = SoriLogo.splashWidth(context);

    return Scaffold(
      backgroundColor: SoriTokens.background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: SoriLogo(
                width: logoWidth,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: MediaQuery.paddingOf(context).bottom + 28,
              child: const Text(
                'Copyright © SORI. All Rights Reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: SoriTokens.tabUnselected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
