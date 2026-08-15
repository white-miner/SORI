import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../models/session_user.dart';
import 'pending_review_return.dart';
import 'supabase_client.dart';

/// Supabase Auth — 카카오 OAuth 단일 로그인.
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

  /// OAuth 복귀 URL — [reviewToken]이 있으면 쿼리에 보존해 홈이 아닌 후기 작성으로 복귀.
  String redirectToForReview([String? reviewToken]) {
    final token = (reviewToken ?? '').trim();
    if (token.isEmpty) return redirectTo;
    PendingReviewReturn.save(token);
    if (!kIsWeb) return nativeRedirectTo;
    final base = Uri.parse(Env.siteUrl);
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        PendingReviewReturn.queryKey: token,
      },
    ).toString();
  }

  /// 카카오 OAuth — 이메일 스코프 없이 닉네임/프로필만 요청.
  /// [reviewToken]이 있으면 로그인 후 `/#/review?token=` 으로 직행할 수 있게 redirect를 보존한다.
  Future<bool> signInWithKakao({String? reviewToken}) async {
    if (!isAvailable) {
      throw const AuthException(
        'Supabase가 설정되지 않았어요. 환경 변수를 확인해 주세요.',
      );
    }
    return _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: redirectToForReview(reviewToken),
      scopes: 'profile_nickname profile_image',
      queryParams: const {
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

  /// 카카오 단일 로그인 — 식별은 항상 kakao로 취급.
  static SocialProvider providerFromUser(User user) {
    final identities = user.identities;
    if (identities != null) {
      for (final id in identities) {
        if (id.provider.toLowerCase() == 'kakao') {
          return SocialProvider.kakao;
        }
      }
    }
    final appProvider =
        (user.appMetadata['provider'] as String?)?.toLowerCase() ?? '';
    if (appProvider.contains('kakao') || appProvider.isEmpty) {
      return SocialProvider.kakao;
    }
    return SocialProvider.kakao;
  }

  /// 카카오 provider_id(고유 ID). 없으면 Supabase auth user id.
  /// email이 null이어도 이 값으로 세션을 매핑합니다.
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
    for (final key in ['provider_id', 'sub', 'id', 'kakao_id']) {
      final v = meta[key];
      if (v != null) {
        final text = '$v'.trim();
        if (text.isNotEmpty) return text;
      }
    }
    // 최후 수단: Supabase auth uuid (email 없이도 유효)
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
    // email은 카카오에서 null — 절대 필수로 쓰지 않음
    return '카카오 회원';
  }

  /// 카카오/소셜 프로필 이미지 URL.
  static String avatarUrlFromUser(User user) {
    final meta = user.userMetadata ?? {};
    for (final key in [
      'avatar_url',
      'picture',
      'profile_image',
      'profile_image_url',
      'thumbnail_image',
    ]) {
      final v = meta[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  static String phoneFromUser(User user) {
    final meta = user.userMetadata ?? {};
    final phone = meta['phone'] ?? meta['phone_number'] ?? user.phone;
    if (phone is String) return phone.trim();
    return '';
  }

  /// 카카오는 항상 빈 문자열 가능 — 로그인 중단 금지.
  static String emailFromUser(User user) => user.email?.trim() ?? '';
}
