import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Compile-time / dotenv 환경 설정.
abstract final class Env {
  static const String _urlFromDefine =
      String.fromEnvironment('SUPABASE_URL');
  static const String _keyFromDefine =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl =>
      _normalizeUrl(_urlFromDefine.isNotEmpty
          ? _urlFromDefine
          : _dotenv('SUPABASE_URL'));

  static String get supabaseAnonKey =>
      _keyFromDefine.isNotEmpty ? _keyFromDefine : _dotenv('SUPABASE_ANON_KEY');

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

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

  static String _dotenv(String key) {
    try {
      return dotenv.maybeGet(key)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// `.env` → `.env.example` 순으로 로드 (CI는 example 복사본 사용).
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (e, st) {
      debugPrint('Env .env load skipped: $e\n$st');
    }
    final urlEmpty = (dotenv.isInitialized
            ? (dotenv.maybeGet('SUPABASE_URL') ?? '')
            : '')
        .isEmpty;
    final keyEmpty = (dotenv.isInitialized
            ? (dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '')
            : '')
        .isEmpty;
    if (!dotenv.isInitialized || (urlEmpty && keyEmpty)) {
      try {
        await dotenv.load(fileName: '.env.example', isOptional: true);
      } catch (e, st) {
        debugPrint('Env .env.example load skipped: $e\n$st');
      }
    }
  }
}
