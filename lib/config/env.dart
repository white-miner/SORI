import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Compile-time / dotenv 환경 설정.
abstract final class Env {
  /// GitHub Pages 프로덕션 Site URL (localhost 폴백 방지).
  static const String defaultSiteUrl = 'https://white-miner.github.io/SORI/';

  static const String _urlFromDefine =
      String.fromEnvironment('SUPABASE_URL');
  static const String _keyFromDefine =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _openaiFromDefine =
      String.fromEnvironment('OPENAI_API_KEY');
  static const String _siteFromDefine = String.fromEnvironment('SITE_URL');

  static String get supabaseUrl {
    final raw = _urlFromDefine.isNotEmpty
        ? _urlFromDefine
        : _dotenv('SUPABASE_URL');
    final normalized = _normalizeUrl(raw);
    if (isPlaceholderCredential(normalized)) return '';
    return normalized;
  }

  static String get supabaseAnonKey {
    final raw =
        _keyFromDefine.isNotEmpty ? _keyFromDefine : _dotenv('SUPABASE_ANON_KEY');
    if (isPlaceholderCredential(raw)) return '';
    return raw;
  }

  static String get openaiApiKey =>
      _openaiFromDefine.isNotEmpty
          ? _openaiFromDefine
          : _dotenv('OPENAI_API_KEY');

  /// Auth OAuth redirect용 Site URL.
  /// localhost / 빈 값은 배포 주소로 강제합니다.
  static String get siteUrl {
    final raw = _siteFromDefine.isNotEmpty
        ? _siteFromDefine
        : _dotenv('SITE_URL');
    final normalized = _normalizeSiteUrl(raw);
    if (normalized.isEmpty) return defaultSiteUrl;
    final host = Uri.tryParse(normalized)?.host.toLowerCase() ?? '';
    if (host.isEmpty ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0') {
      return defaultSiteUrl;
    }
    return normalized;
  }

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// example·플레이스홀더는 연결 성공으로 보지 않는다.
  static bool isPlaceholderCredential(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return true;
    return v.contains('your_project') ||
        v.contains('your_anon') ||
        v.contains('your-anon') ||
        v.contains('changeme') ||
        v.contains('example.supabase') ||
        v.contains('sk-your-openai');
  }

  static bool get hasOpenAiConfig => openaiApiKey.isNotEmpty;

  /// `...supabase.co/rest/v1/` 형태도 프로젝트 루트 URL로 정규화.
  static String _normalizeUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;
    u = u.replaceFirst(RegExp(r'/rest/v1/?$', caseSensitive: false), '');
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  static String _normalizeSiteUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    if (!u.endsWith('/')) u = '$u/';
    return u;
  }

  static String _dotenv(String key) {
    try {
      return dotenv.maybeGet(key)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// `.env`만 로드한다. example의 가짜 URL/키는 설정으로 인정하지 않는다.
  /// CI는 `--dart-define`이 이 파일보다 우선한다.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (e, st) {
      debugPrint('Env .env load skipped: $e\n$st');
    }
  }
}
