import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sori_auth_service.dart';
import 'sori_store.dart';

/// 앱 전역 Supabase Auth 세션 동기화 — 로그인/복구/만료를 한곳에서 처리.
class SoriAuthCoordinator {
  SoriAuthCoordinator._();
  static final SoriAuthCoordinator instance = SoriAuthCoordinator._();

  final _auth = SoriAuthService.instance;
  final _store = SoriStore.instance;
  StreamSubscription<AuthState>? _sub;
  bool _started = false;
  bool _hydrating = false;

  bool get isStarted => _started;

  /// [main]에서 Supabase 초기화 직후 1회 호출.
  Future<void> start() async {
    if (_started || !_auth.isAvailable) return;
    _started = true;
    debugPrint('[Auth] coordinator start');

    _sub = _auth.onAuthStateChange.listen(
      _onAuthState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[Auth] onAuthStateChange error: $error\n$stackTrace');
        unawaited(_recoverStaleOAuth(error));
      },
    );

    await _waitForInitialSession();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _waitForInitialSession() async {
    debugPrint('[Auth] waiting for initial session (PKCE deeplink / storage)');
    try {
      final state = await _auth.onAuthStateChange
          .firstWhere(
            (s) =>
                s.event == AuthChangeEvent.initialSession ||
                s.event == AuthChangeEvent.signedIn ||
                s.event == AuthChangeEvent.signedOut,
          )
          .timeout(const Duration(seconds: 6));
      debugPrint('[Auth] initial auth event: ${state.event.name}');
      await _applyAuthState(state.event, state.session, reason: 'initial');
    } on TimeoutException {
      debugPrint('[Auth] initial session wait timed out — checking cache');
      final cached = _auth.currentSession;
      if (cached != null) {
        await _hydrate(cached.user, reason: 'cachedSession');
      }
    } catch (e, st) {
      debugPrint('[Auth] initial session wait failed: $e\n$st');
      await _recoverStaleOAuth(e);
      final cached = _auth.currentSession;
      if (cached != null && !SoriAuthService.isStaleOAuthError(e)) {
        await _hydrate(cached.user, reason: 'cachedSessionFallback');
      }
    }
  }

  Future<void> _recoverStaleOAuth(Object error) async {
    if (!SoriAuthService.isStaleOAuthError(error)) {
      final msg = SoriAuthService.userMessage(error);
      if (msg.isNotEmpty) _store.setAuthError(msg);
      return;
    }
    debugPrint('[Auth] stale OAuth — silent signOut + clear');
    _store.clearAuthSession(localOnly: false);
    _store.clearAuthError();
  }

  void _onAuthState(AuthState state) {
    unawaited(_applyAuthState(state.event, state.session, reason: state.event.name));
  }

  Future<void> _applyAuthState(
    AuthChangeEvent event,
    Session? session, {
    required String reason,
  }) async {
    debugPrint('[Auth] apply event=$reason session=${session != null}');

    if (event == AuthChangeEvent.signedOut) {
      _store.clearAuthSession(localOnly: true);
      return;
    }

    if (session == null) return;

    if (event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.initialSession ||
        event == AuthChangeEvent.tokenRefreshed ||
        event == AuthChangeEvent.userUpdated) {
      await _hydrate(session.user, reason: reason);
    }
  }

  /// 로그인/복구 후 Store 세션 구성 — UI 라우팅은 각 페이지에서 처리.
  Future<void> _hydrate(User user, {required String reason}) async {
    if (_hydrating) {
      debugPrint('[Auth] hydrate skipped — already in progress ($reason)');
      return;
    }
    _hydrating = true;
    _store.setAuthHydrating(true);
    try {
      debugPrint('[Auth] hydrate start ($reason) uid=${user.id}');
      await _store.hydrateSessionFromAuth(user).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('프로필 동기화 시간이 초과되었어요.');
        },
      );
      debugPrint(
        '[Auth] hydrate done onboarding=${_store.session?.onboardingComplete}',
      );
    } on TimeoutException catch (e) {
      debugPrint('[Auth] hydrate timeout: $e');
      _store.setAuthError(SoriAuthService.userMessage(e));
    } catch (e, st) {
      debugPrint('[Auth] hydrate failed: $e\n$st');
      await _recoverStaleOAuth(e);
    } finally {
      _hydrating = false;
      _store.setAuthHydrating(false);
    }
  }

  /// 로그인 페이지 등에서 OAuth 직후 세션을 즉시 동기화.
  Future<bool> ensureHydratedFromCurrentSession() async {
    final session = _auth.currentSession;
    if (session == null) return false;
    await _hydrate(session.user, reason: 'ensureHydrated');
    return _store.session != null;
  }
}
