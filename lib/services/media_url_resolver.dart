import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../utils/storage_image_url.dart';
import 'chart_photo_storage.dart';
import 'media_sign_client.dart';
import 'supabase_client.dart';

/// What a stored image value points at.
enum MediaRefKind {
  /// null / blank.
  empty,

  /// `data:` URI (e.g. signatures saved inline). Shown as is.
  dataUri,

  /// http(s) URL that is not an object of this Supabase project. Shown as is.
  external,

  /// Object in this project's Storage: [MediaRef.bucket] + [MediaRef.path].
  storage,

  /// Something else (unsafe path, unknown bucket). Old public-URL rule only.
  unknown,
}

/// Parsed image reference (plan S3 §2.6). Accepts every form the DB holds
/// today and after S7:
///   * `https://<project>/storage/v1/object/public/<bucket>/<path>`
///     (also `/object/sign/`, `/object/authenticated/`, `/render/image/...`)
///   * `/storage/v1/object/public/<bucket>/<path>` (relative)
///   * `<shop_id>/<customer_id>/<file>` (object path; bucket from the column)
/// Same rules as `supabase/functions/_shared/media_path.ts` `parseStorageRef`.
@immutable
class MediaRef {
  const MediaRef._(
    this.kind,
    this.raw, {
    this.bucket,
    this.path,
    this.defaultBucket = ChartPhotoStorage.bucket,
  });

  /// Buckets that exist in the project (media_path.ts `KNOWN_BUCKETS`).
  static const knownBuckets = <String>{
    'chart_photos',
    'consent_pdfs',
    'chart-signatures',
    'shop_profiles',
    'chart-photos',
  };

  /// Private (or private after S8) buckets that `media-sign` signs
  /// (handler.ts `SIGNABLE_BUCKETS`). `shop_profiles` stays public.
  static const signableBuckets = <String>{
    'chart_photos',
    'consent_pdfs',
    'chart-signatures',
  };

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final _objectUrlPath = RegExp(
    r'^/storage/v1/(?:object|render/image)/(?:public|sign|authenticated)/([^/]+)/(.+)$',
  );
  static final _dotSegment = RegExp(
    r'/(?:\.|%2e){1,2}(?:/|[?#]|$)',
    caseSensitive: false,
  );
  static final _control = RegExp(r'[\u0000-\u001f\u007f]');

  final MediaRefKind kind;

  /// Trimmed original value.
  final String raw;
  final String? bucket;
  final String? path;

  /// Bucket of the column this value came from (used by the old public-URL rule).
  final String defaultBucket;

  static MediaRef parse(
    String? raw, {
    String defaultBucket = ChartPhotoStorage.bucket,
    String? supabaseUrl,
  }) {
    final value = raw?.trim() ?? '';
    MediaRef of(MediaRefKind kind, {String? bucket, String? path}) =>
        MediaRef._(
          kind,
          value,
          bucket: bucket,
          path: path,
          defaultBucket: defaultBucket,
        );

    if (value.isEmpty) return of(MediaRefKind.empty);
    if (value.startsWith('data:')) return of(MediaRefKind.dataUri);

    if (value.contains('://')) {
      final uri = Uri.tryParse(value);
      if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
        return of(MediaRefKind.external);
      }
      final projectHost = _hostOf(supabaseUrl ?? Env.supabaseUrl);
      if (projectHost == null ||
          uri.authority.toLowerCase() != projectHost ||
          _dotSegment.hasMatch(value)) {
        return of(MediaRefKind.external);
      }
      final ref = _fromStoragePath(uri.path);
      if (ref == null) return of(MediaRefKind.external);
      return of(MediaRefKind.storage, bucket: ref.$1, path: ref.$2);
    }

    final noQuery = value.split(RegExp(r'[?#]')).first;
    final rooted = noQuery.startsWith('/') ? noQuery : '/$noQuery';
    if (rooted.contains('/storage/v1/')) {
      if (_dotSegment.hasMatch(rooted)) return of(MediaRefKind.unknown);
      final ref = _fromStoragePath(rooted);
      if (ref == null) return of(MediaRefKind.unknown);
      return of(MediaRefKind.storage, bucket: ref.$1, path: ref.$2);
    }

    final path = noQuery.replaceFirst(RegExp(r'^/+'), '');
    if (!knownBuckets.contains(defaultBucket) || !_isSafePath(path)) {
      return of(MediaRefKind.unknown);
    }
    return of(MediaRefKind.storage, bucket: defaultBucket, path: path);
  }

  /// First path segment when it is a shop UUID (lower-case), else null.
  String? get shopId {
    final p = path;
    if (p == null) return null;
    final first = p.split('/').first;
    return _uuid.hasMatch(first) ? first.toLowerCase() : null;
  }

  /// True when `media-sign` refs mode can sign it: private bucket and a
  /// `<shop_uuid>/...` path (`unknown-shop/...` uploads are not signable).
  bool get isSignable =>
      kind == MediaRefKind.storage &&
      signableBuckets.contains(bucket) &&
      shopId != null;

  /// Stable key across signed URLs: `<bucket>/<path>` for storage objects.
  /// Also meant for `CachedNetworkImage.cacheKey` (PR 3-2).
  String get cacheKey => kind == MediaRefKind.storage ? '$bucket/$path' : raw;

  static (String, String)? _fromStoragePath(String encodedPath) {
    final m = _objectUrlPath.firstMatch(encodedPath);
    if (m == null) return null;
    try {
      final bucket = Uri.decodeComponent(m.group(1)!);
      final path = m.group(2)!.split('/').map(Uri.decodeComponent).join('/');
      if (!knownBuckets.contains(bucket) || !_isSafePath(path)) return null;
      return (bucket, path);
    } catch (_) {
      return null;
    }
  }

  static bool _isSafePath(String path) {
    if (path.isEmpty || path.length > 512) return false;
    if (path.startsWith('/') || path.contains(r'\')) return false;
    if (_control.hasMatch(path)) return false;
    return path.split('/').every((s) => s.isNotEmpty && s != '.' && s != '..');
  }

  static String? _hostOf(String supabaseUrl) {
    final url = supabaseUrl.trim();
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    final host = uri?.authority.toLowerCase() ?? '';
    return host.isEmpty ? null : host;
  }

  @override
  bool operator ==(Object other) =>
      other is MediaRef &&
      other.kind == kind &&
      other.raw == raw &&
      other.bucket == bucket &&
      other.path == path &&
      other.defaultBucket == defaultBucket;

  @override
  int get hashCode => Object.hash(kind, raw, bucket, path, defaultBucket);

  @override
  String toString() => 'MediaRef($kind, $cacheKey)';
}

class _CacheEntry {
  const _CacheEntry(this.signedUrl, this.expiresAt);

  /// null → negative entry: use the old public URL until [expiresAt].
  final String? signedUrl;
  final DateTime expiresAt;
}

/// Image URL resolver for owner screens (plan S3 §2.6, PR 3-1).
///
/// * Private-bucket objects → `media-sign` refs, batched (window [batchWindow],
///   up to 50 per request, one request per shop) and cached for [cacheTtl]
///   (50 min, signed URLs live 60 min).
/// * Any failure (401/403/network/5xx/not found), customer or anon mode
///   ([canSign] false), public buckets, `unknown-shop` paths → the old public
///   URL (`StorageImageUrl.resolve`), so screens look the same until S8.
/// * External URLs and data URIs are returned as is.
///
/// Not used by any screen yet (PR 3-2 wires it in).
class MediaUrlResolver {
  MediaUrlResolver({
    MediaSignClient? client,
    bool Function()? canSign,
    String? Function(MediaRef ref)? legacyUrl,
    DateTime Function()? now,
    this.cacheTtl = const Duration(minutes: 50),
    this.batchWindow = const Duration(milliseconds: 50),
    this.retryCooldown = const Duration(minutes: 1),
  }) : _client = client ?? MediaSignClient(),
       _canSign = canSign ?? _hasSession,
       _legacyUrl = legacyUrl ?? _storageImageUrl,
       _now = now ?? DateTime.now;

  static MediaUrlResolver? _instance;

  /// App-wide resolver (lazy).
  static MediaUrlResolver get instance => _instance ??= MediaUrlResolver();

  @visibleForTesting
  static set debugInstance(MediaUrlResolver? resolver) => _instance = resolver;

  final MediaSignClient _client;
  final bool Function() _canSign;
  final String? Function(MediaRef ref) _legacyUrl;
  final DateTime Function() _now;

  /// How long a signed URL is reused (server TTL is 60 min).
  final Duration cacheTtl;

  /// Requests made within this window are sent together.
  final Duration batchWindow;

  /// After a 401 or a per-object failure, skip signing for this long.
  final Duration retryCooldown;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Completer<String?>> _inflight = {};
  final LinkedHashMap<String, MediaRef> _queue = LinkedHashMap();
  final Map<String, DateTime> _forbiddenShops = {};
  DateTime? _authBlockedUntil;
  Timer? _timer;
  int _generation = 0;

  @visibleForTesting
  int get cacheSize => _cache.length;

  @visibleForTesting
  int get pendingCount => _inflight.length;

  /// [MediaRef.parse] + [resolve].
  Future<String?> resolveRaw(
    String? raw, {
    String defaultBucket = ChartPhotoStorage.bucket,
  }) => resolve(MediaRef.parse(raw, defaultBucket: defaultBucket));

  /// Display URL for [ref]: signed URL when possible, else the old public URL.
  Future<String?> resolve(MediaRef ref) {
    switch (ref.kind) {
      case MediaRefKind.empty:
        return Future.value(null);
      case MediaRefKind.dataUri:
      case MediaRefKind.external:
        return Future.value(ref.raw);
      case MediaRefKind.unknown:
        return Future.value(_legacy(ref));
      case MediaRefKind.storage:
        break;
    }
    if (!ref.isSignable || !_signingAllowed(ref)) {
      return Future.value(_legacy(ref));
    }

    final key = ref.cacheKey;
    final cached = _cache[key];
    if (cached != null) {
      if (_now().isBefore(cached.expiresAt)) {
        return Future.value(cached.signedUrl ?? _legacy(ref));
      }
      _cache.remove(key);
    }

    final pending = _inflight[key];
    if (pending != null) return pending.future;

    final completer = Completer<String?>();
    _inflight[key] = completer;
    _queue[key] = ref;
    if (_queue.length >= MediaSignClient.maxRefs) {
      _flush();
    } else {
      _timer ??= Timer(batchWindow, _flush);
    }
    return completer.future;
  }

  /// Cached signed URL (still valid), or null. Never starts a request.
  String? peek(MediaRef ref) {
    final entry = _cache[ref.cacheKey];
    if (entry == null || !_now().isBefore(entry.expiresAt)) return null;
    return entry.signedUrl;
  }

  /// Drops cache and cooldowns (call on logout / shop switch). Requests
  /// already sent still complete, but their results are not cached.
  void clear() {
    _generation++;
    _cache.clear();
    _forbiddenShops.clear();
    _authBlockedUntil = null;
  }

  bool _signingAllowed(MediaRef ref) {
    bool allowed;
    try {
      allowed = _canSign();
    } catch (_) {
      allowed = false;
    }
    if (!allowed) return false;
    final now = _now();
    final authBlocked = _authBlockedUntil;
    if (authBlocked != null) {
      if (now.isBefore(authBlocked)) return false;
      _authBlockedUntil = null;
    }
    final shop = ref.shopId!;
    final forbiddenUntil = _forbiddenShops[shop];
    if (forbiddenUntil != null) {
      if (now.isBefore(forbiddenUntil)) return false;
      _forbiddenShops.remove(shop);
    }
    return true;
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    if (_queue.isEmpty) return;
    final refs = _queue.values.toList();
    _queue.clear();

    // One request per shop: media-sign rejects the whole request (403) when
    // any ref belongs to a shop the user cannot manage.
    final byShop = <String, List<MediaRef>>{};
    for (final r in refs) {
      byShop.putIfAbsent(r.shopId!, () => []).add(r);
    }
    final generation = _generation;
    for (final entry in byShop.entries) {
      final list = entry.value;
      for (var i = 0; i < list.length; i += MediaSignClient.maxRefs) {
        final end = (i + MediaSignClient.maxRefs).clamp(0, list.length);
        unawaited(_send(entry.key, list.sublist(i, end), generation));
      }
    }
  }

  Future<void> _send(String shopId, List<MediaRef> refs, int generation) async {
    try {
      final result = await _client.signRefs([
        for (final r in refs) (bucket: r.bucket!, path: r.path!),
      ]);
      final now = _now();
      var expiresAt = now.add(cacheTtl);
      final serverExpiry = result.expiresAt?.subtract(
        const Duration(minutes: 1),
      );
      if (serverExpiry != null && serverExpiry.isBefore(expiresAt)) {
        expiresAt = serverExpiry;
      }
      final cacheable = generation == _generation;
      for (var i = 0; i < refs.length; i++) {
        final ref = refs[i];
        final url = i < result.signedUrls.length ? result.signedUrls[i] : null;
        if (cacheable) {
          _cache[ref.cacheKey] = url != null
              ? _CacheEntry(url, expiresAt)
              : _CacheEntry(null, now.add(retryCooldown));
        }
        _complete(ref, url ?? _legacy(ref));
      }
    } on MediaSignException catch (e) {
      if (generation == _generation) {
        if (e.isAuthError) {
          _authBlockedUntil = _now().add(retryCooldown);
        } else if (e.isForbidden) {
          _forbiddenShops[shopId] = _now().add(cacheTtl);
        }
      }
      debugPrint('MediaUrlResolver: sign failed ($e), using public URL');
      for (final ref in refs) {
        _complete(ref, _legacy(ref));
      }
    } catch (e) {
      debugPrint('MediaUrlResolver: sign failed ($e), using public URL');
      for (final ref in refs) {
        _complete(ref, _legacy(ref));
      }
    }
  }

  void _complete(MediaRef ref, String? url) {
    final completer = _inflight.remove(ref.cacheKey);
    if (completer != null && !completer.isCompleted) completer.complete(url);
  }

  String? _legacy(MediaRef ref) {
    try {
      return _legacyUrl(ref);
    } catch (e) {
      debugPrint('MediaUrlResolver: public URL failed for $ref: $e');
      return null;
    }
  }

  static bool _hasSession() =>
      SoriSupabase.clientOrNull?.auth.currentSession != null;

  /// Exactly what screens show today.
  static String? _storageImageUrl(MediaRef ref) =>
      StorageImageUrl.resolve(ref.raw, bucket: ref.defaultBucket);
}
