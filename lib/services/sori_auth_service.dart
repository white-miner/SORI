import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/session_user.dart';
import 'supabase_client.dart';

/// Supabase Auth — 이메일 매직 링크 + 카카오 OAuth.
class SoriAuthService {
  SoriAuthService._();
  static final SoriAuthService instance = SoriAuthService._();

  bool get isAvailable => SoriSupabase.isInitialized;

  SupabaseClient get _client => SoriSupabase.client;

  User? get currentUser => SoriSupabase.clientOrNull?.auth.currentUser;

  Session? get currentSession =>
      SoriSupabase.clientOrNull?.auth.currentSession;

  Stream<AuthState> get onAuthStateChange {
    final client = SoriSupabase.clientOrNull;
    if (client == null) return const Stream.empty();
    return client.auth.onAuthStateChange;
  }

  /// GitHub Pages / 로컬 웹 리다이렉트 URL.
  String get redirectTo {
    if (kIsWeb) {
      final base = Uri.base;
      var path = base.path;
      if (path.endsWith('index.html')) {
        path = path.substring(0, path.length - 'index.html'.length);
      }
      if (!path.endsWith('/')) path = '$path/';
      return '${base.origin}$path';
    }
    return 'io.supabase.sori://login-callback/';
  }

  Future<void> signInWithEmailOtp(String email) async {
    if (!isAvailable) {
      throw const AuthException(
        'Supabase가 설정되지 않았어요. 환경 변수를 확인해 주세요.',
      );
    }
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw const AuthException('올바른 이메일 주소를 입력해 주세요.');
    }
    await _client.auth.signInWithOtp(
      email: trimmed,
      emailRedirectTo: redirectTo,
    );
  }

  Future<bool> signInWithKakao() async {
    if (!isAvailable) {
      throw const AuthException(
        'Supabase가 설정되지 않았어요. 환경 변수를 확인해 주세요.',
      );
    }
    return _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: redirectTo,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() async {
    final client = SoriSupabase.clientOrNull;
    if (client == null) return;
    await client.auth.signOut();
  }

  static SocialProvider providerFromUser(User user) {
    final identities = user.identities;
    if (identities != null) {
      for (final id in identities) {
        final p = id.provider.toLowerCase();
        if (p == 'kakao') return SocialProvider.kakao;
        if (p == 'email') return SocialProvider.email;
      }
    }
    final appProvider =
        (user.appMetadata['provider'] as String?)?.toLowerCase() ?? '';
    if (appProvider == 'kakao') return SocialProvider.kakao;
    return SocialProvider.email;
  }

  static String displayNameFromUser(User user) {
    final meta = user.userMetadata ?? {};
    for (final key in ['full_name', 'name', 'preferred_username']) {
      final v = meta[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final email = user.email?.trim() ?? '';
    if (email.contains('@')) return email.split('@').first;
    return '';
  }

  static String phoneFromUser(User user) {
    final meta = user.userMetadata ?? {};
    final phone = meta['phone'] ?? meta['phone_number'] ?? user.phone;
    if (phone is String) return phone.trim();
    return '';
  }
}
