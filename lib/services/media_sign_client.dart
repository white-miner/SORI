import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// One object to sign: bucket + object path (`<shop_id>/...`).
typedef MediaSignTarget = ({String bucket, String path});

/// Raw Edge Function reply. [status] is 0 when no response arrived.
typedef MediaSignTransportResponse = ({int status, Object? data});

/// Sends one JSON body to the `media-sign` Edge Function.
typedef MediaSignTransport =
    Future<MediaSignTransportResponse> Function(Map<String, Object?> body);

/// `media-sign` refs mode failed as a whole request.
///
/// [status]: HTTP status (401 login_required, 403 forbidden, 400, 5xx),
/// 0 for network failure, null when Supabase is not configured.
class MediaSignException implements Exception {
  const MediaSignException(this.status, this.error);

  final int? status;
  final String error;

  bool get isAuthError => status == 401;
  bool get isForbidden => status == 403;

  @override
  String toString() => 'MediaSignException(status: $status, error: $error)';
}

/// Result of one refs request. [signedUrls] is index-aligned with the request;
/// an entry is null when that object was not found or the ref was rejected.
class MediaSignRefsResult {
  const MediaSignRefsResult({
    required this.signedUrls,
    required this.expiresIn,
    this.expiresAt,
  });

  final List<String?> signedUrls;
  final Duration expiresIn;
  final DateTime? expiresAt;
}

/// Thin client for `supabase/functions/media-sign` (refs mode only).
///
/// Request:  `{ "refs": [{ "bucket", "path" }], "expires_in": <60..3600> }`
/// Response: `{ ok, mode: "refs", expires_in, expires_at, items: [{ index, signed_url, error? }] }`
/// The user's JWT is attached by `functions.invoke`; anon/expired → 401.
class MediaSignClient {
  MediaSignClient({MediaSignTransport? transport})
    : _transport = transport ?? _invokeEdgeFunction;

  static const functionName = 'media-sign';

  /// Server limit per request (`MAX_REFS` in handler.ts).
  static const maxRefs = 50;

  /// Server default and maximum TTL (`DEFAULT_TTL_SECONDS` / `MAX_TTL_SECONDS`).
  static const defaultExpiresInSeconds = 3600;
  static const minExpiresInSeconds = 60;
  static const maxExpiresInSeconds = 3600;

  final MediaSignTransport _transport;

  Future<MediaSignRefsResult> signRefs(
    List<MediaSignTarget> refs, {
    int expiresInSeconds = defaultExpiresInSeconds,
  }) async {
    if (refs.isEmpty) {
      return const MediaSignRefsResult(
        signedUrls: [],
        expiresIn: Duration(seconds: defaultExpiresInSeconds),
      );
    }
    if (refs.length > maxRefs) {
      throw ArgumentError.value(
        refs.length,
        'refs',
        'max $maxRefs per request',
      );
    }
    final ttl = expiresInSeconds.clamp(
      minExpiresInSeconds,
      maxExpiresInSeconds,
    );

    final response = await _transport({
      'refs': [
        for (final r in refs) {'bucket': r.bucket, 'path': r.path},
      ],
      'expires_in': ttl,
    });

    final data = response.data;
    final body = data is Map ? data : const <Object?, Object?>{};
    if (response.status < 200 || response.status >= 300 || body['ok'] != true) {
      final error = body['error']?.toString();
      throw MediaSignException(
        response.status,
        (error == null || error.isEmpty) ? 'unexpected_response' : error,
      );
    }

    final urls = List<String?>.filled(refs.length, null);
    final items = body['items'];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        final index = item['index'];
        final url = item['signed_url'];
        if (index is int &&
            index >= 0 &&
            index < urls.length &&
            url is String) {
          final trimmed = url.trim();
          if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
            urls[index] = trimmed;
          }
        }
      }
    }

    final expiresIn = body['expires_in'];
    final expiresAt = body['expires_at'];
    return MediaSignRefsResult(
      signedUrls: urls,
      expiresIn: Duration(seconds: expiresIn is int ? expiresIn : ttl),
      expiresAt: expiresAt is String ? DateTime.tryParse(expiresAt) : null,
    );
  }

  static Future<MediaSignTransportResponse> _invokeEdgeFunction(
    Map<String, Object?> body,
  ) async {
    final client = SoriSupabase.clientOrNull;
    if (client == null) {
      throw const MediaSignException(null, 'supabase_unavailable');
    }
    try {
      final res = await client.functions.invoke(functionName, body: body);
      return (status: res.status, data: res.data);
    } on FunctionException catch (e) {
      // Non-2xx (FunctionsHttpException), relay errors, or status 0 (fetch failure).
      return (status: e.status, data: e.details);
    } catch (e) {
      debugPrint('MediaSignClient: invoke failed: $e');
      return (status: 0, data: null);
    }
  }
}
