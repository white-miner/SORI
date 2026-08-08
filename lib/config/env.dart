import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Compile-time / dotenv 환경 설정.
abstract final class Env {
  static const String _urlFromDefine =
      String.fromEnvironment('SUPABASE_URL');
  static const String _keyFromDefine =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl =>
      _urlFromDefine.isNotEmpty ? _urlFromDefine : _dotenv('SUPABASE_URL');

  static String get supabaseAnonKey =>
      _keyFromDefine.isNotEmpty ? _keyFromDefine : _dotenv('SUPABASE_ANON_KEY');

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String _dotenv(String key) {
    try {
      return dotenv.maybeGet(key)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// `.env`가 없으면 `.env.example`을 로드 (CI / Pages 빌드 안전).
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (e, st) {
      debugPrint('Env .env load skipped: $e\n$st');
    }
    if (!dotenv.isInitialized ||
        ((dotenv.maybeGet('SUPABASE_URL') ?? '').isEmpty &&
            (dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '').isEmpty)) {
      try {
        await dotenv.load(fileName: '.env.example', isOptional: true);
      } catch (e, st) {
        debugPrint('Env .env.example load skipped: $e\n$st');
      }
    }
  }
}
