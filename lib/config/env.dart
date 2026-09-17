import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'process_env_stub.dart'
    if (dart.library.io) 'process_env_io.dart' as process_env;

/// Compile-time / dotenv / process 환경 설정.
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

  static const String _publicDataFromDefine =
      String.fromEnvironment('PUBLIC_DATA_SERVICE_KEY');
  static const String _dataGoFromDefine =
      String.fromEnvironment('DATA_GO_KR_SERVICE_KEY');
  static const String _sbizFromDefine =
      String.fromEnvironment('SBIZ_STORE_SERVICE_KEY');
  static const String _moisFromDefine =
      String.fromEnvironment('MOIS_POP_SERVICE_KEY');
  static const String _useDemoFromDefine =
      String.fromEnvironment('USE_DEMO_MARKET_DATA');
  static const String _flavorFromDefine =
      String.fromEnvironment('SORI_ENV', defaultValue: 'development');

  /// development | staging | production
  static String get flavorName {
    final raw = _firstNonEmpty([
      _flavorFromDefine,
      _dotenv('SORI_ENV'),
      process_env.readProcessEnv('SORI_ENV'),
    ]).toLowerCase();
    if (raw == 'prod' || raw == 'production') return 'production';
    if (raw == 'stage' || raw == 'staging') return 'staging';
    return 'development';
  }

  static bool get isProduction => flavorName == 'production';
  static bool get isStaging => flavorName == 'staging';
  static bool get isDevelopment => flavorName == 'development';
  static bool get isReleaseProduction => isProduction && kReleaseMode;

  /// PowerShell / dart-define / dotenv 에서 읽은 공공데이터 키 별칭.
  static const publicDataKeyAliases = <String>[
    'PUBLIC_DATA_SERVICE_KEY',
    'DATA_GO_KR_SERVICE_KEY',
    'SBIZ_STORE_SERVICE_KEY',
    'SERVICE_KEY',
    'PUBLIC_DATA_API_KEY',
    'DATA_GO_KR_API_KEY',
  ];

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

  /// 값 자체는 호출부 로그에 넣지 말 것. 존재 여부만 공개.
  static bool get publicDataKeyConfigured => publicDataServiceKey.isNotEmpty;

  static bool get moisPopKeyConfigured => moisPopServiceKey.isNotEmpty;

  /// `USE_DEMO_MARKET_DATA=true` 를 명시한 경우에만 시드 허용.
  /// production release 에서는 기본·강제 모두 DEMO 비활성.
  static bool get useDemoMarketData {
    if (isReleaseProduction) return false;
    final raw = _firstNonEmpty([
      _useDemoFromDefine,
      _dotenv('USE_DEMO_MARKET_DATA'),
      process_env.readProcessEnv('USE_DEMO_MARKET_DATA'),
    ]);
    return raw.toLowerCase() == 'true' || raw == '1';
  }

  /// 런치 검증용. 키 값은 넣지 않는다.
  static Map<String, bool> launchConfiguredFlags() => {
        'supabase': hasSupabaseConfig,
        'openai': hasOpenAiConfig,
        'public_data': publicDataKeyConfigured,
        'mois_pop': moisPopKeyConfigured,
        'demo_market': useDemoMarketData,
      };

  /// 소상공인 상가 API serviceKey. UI/로그에 출력 금지.
  static String get publicDataServiceKey {
    return _firstNonEmpty([
      _publicDataFromDefine,
      _dataGoFromDefine,
      _sbizFromDefine,
      for (final name in publicDataKeyAliases) _dotenv(name),
      for (final name in publicDataKeyAliases) process_env.readProcessEnv(name),
    ]);
  }

  static String get moisPopServiceKey {
    return _firstNonEmpty([
      _moisFromDefine,
      _dotenv('MOIS_POP_SERVICE_KEY'),
      process_env.readProcessEnv('MOIS_POP_SERVICE_KEY'),
    ]);
  }

  static String _firstNonEmpty(Iterable<String> values) {
    for (final raw in values) {
      final v = raw.trim();
      if (v.isNotEmpty && !isPlaceholderCredential(v)) return v;
    }
    return '';
  }

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
