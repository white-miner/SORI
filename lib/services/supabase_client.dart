import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Supabase 클라이언트 초기화. 키가 없으면 no-op (Memory fallback).
abstract final class SoriSupabase {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient? get clientOrNull {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  static SupabaseClient get client {
    final c = clientOrNull;
    if (c == null) {
      throw StateError('Supabase is not initialized. Set SUPABASE_URL/ANON_KEY.');
    }
    return c;
  }

  static Future<bool> initialize() async {
    if (_initialized) return true;
    if (!Env.hasSupabaseConfig) {
      debugPrint('SoriSupabase: no credentials — using in-memory repository.');
      return false;
    }
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // supabase_flutter 2.17+: publishableKey (anon key와 동일 역할)
      publishableKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        // 웹: localStorage / 네이티브: SharedPreferences 에 JWT·Refresh 영속화
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUri: true,
      ),
    );
    _initialized = true;
    debugPrint('SoriSupabase: initialized (siteUrl=${Env.siteUrl}).');
    return true;
  }
}
