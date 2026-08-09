import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../models/session_user.dart';
import 'supabase_client.dart';

/// Supabase Auth — 이메일 매직 링크 + 카카오 OAuth.
class SoriAuthService {
  SoriAuthService._();
  static final SoriAuthService instance = SoriAuthService._();

  /// 모바일 네이티브 OAuth 콜백 스키마.
  static const String nativeRedirectTo = 'sori://login-callback';

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

  /// 웹: SITE_URL(배포 주소) / 모바일: sori://login-callback
  String get redirectTo {
    if (!kIsWeb) return nativeRedirectTo;
    return Env.siteUrl;
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
    // 매직링크는 항상 배포 Site URL로 — localhost Site URL 사고 방지
    await _client.auth.signInWithOtp(
      email: trimmed,
      emailRedirectTo: Env.siteUrl,
    );
  }

  Future<bool> signInWithKakao() async {
    if (!isAvailable) {
      throw const AuthException(
        'Supabase가 설정되지 않았어요. 환경 변수를 확인해 주세요.',
      );
    }
    // 개인 개발자 앱: account_email 불가 → 닉네임/프로필만 요청
    return _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: redirectTo,
      scopes: 'profile_nickname profile_image',
      queryParams: const {
        // 이메일 스코프 명시적 제외
        'scope': 'profile_nickname profile_image',
      },
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
    // 이메일 없는 카카오 유저는 provider 메타만으로 판별
    if ((user.email == null || user.email!.trim().isEmpty) &&
        appProvider.isNotEmpty &&
        appProvider != 'email') {
      if (appProvider.contains('kakao')) return SocialProvider.kakao;
    }
    return SocialProvider.email;
  }

  /// 카카오 provider_id(고유 ID). 없으면 Supabase auth user id.
  static String providerIdFromUser(User user) {
    final identities = user.identities;
    if (identities != null) {
      for (final id in identities) {
        if (id.provider.toLowerCase() == 'kakao') {
          final pid = id.id.trim();
          if (pid.isNotEmpty) return pid;
        }
      }
      for (final id in identities) {
        final pid = id.id.trim();
        if (pid.isNotEmpty) return pid;
      }
    }
    final meta = user.userMetadata ?? {};
    for (final key in ['provider_id', 'sub', 'id']) {
      final v = meta[key];
      if (v != null) {
        final text = '$v'.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return user.id;
  }

  static String displayNameFromUser(User user) {
    final meta = user.userMetadata ?? {};
    for (final key in [
      'full_name',
      'name',
      'nickname',
      'preferred_username',
      'user_name',
    ]) {
      final v = meta[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    // email은 null일 수 있음 (카카오 개인 개발자 앱)
    final email = user.email?.trim();
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    final provider = providerFromUser(user);
    if (provider == SocialProvider.kakao) return '카카오 회원';
    return '소리 회원';
  }

  static String phoneFromUser(User user) {
    final meta = user.userMetadata ?? {};
    final phone = meta['phone'] ?? meta['phone_number'] ?? user.phone;
    if (phone is String) return phone.trim();
    return '';
  }

  /// null-safe email — 카카오는 빈 문자열.
  static String emailFromUser(User user) => user.email?.trim() ?? '';
}
