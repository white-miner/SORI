import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Phase C.2 — 지역 맵 저장함 (post / seminar). 좌표·GPS 이력은 저장하지 않는다.
enum RegionContentKind { post, seminar }

extension RegionContentKindX on RegionContentKind {
  String get wire => switch (this) {
        RegionContentKind.post => 'post',
        RegionContentKind.seminar => 'seminar',
      };

  static RegionContentKind? parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'post':
        return RegionContentKind.post;
      case 'seminar':
        return RegionContentKind.seminar;
      default:
        return null;
    }
  }
}

class RegionContentBookmark {
  const RegionContentBookmark({
    required this.kind,
    required this.targetId,
    this.createdAt,
  });

  final RegionContentKind kind;
  final String targetId;
  final DateTime? createdAt;
}

/// SSOT: Supabase RPC. 마이그레이션 미적용·오프라인 시 prefs 폴백(기기 로컬만).
class RegionContentBookmarkStore {
  RegionContentBookmarkStore._();
  static final RegionContentBookmarkStore instance =
      RegionContentBookmarkStore._();

  static const _prefsKey = 'region_content_bookmarks_v1';

  List<RegionContentBookmark> _cache = const [];
  List<RegionContentBookmark> get items => List.unmodifiable(_cache);

  /// 저장함 Peek용 최근 3개.
  List<RegionContentBookmark> recent({int limit = 3}) =>
      _cache.take(limit).toList(growable: false);

  bool isBookmarked(RegionContentKind kind, String targetId) {
    final id = targetId.trim();
    if (id.isEmpty) return false;
    return _cache.any((e) => e.kind == kind && e.targetId == id);
  }

  Future<void> refresh() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        _cache = await _loadPrefs();
        return;
      }
      final rows = await client.rpc(
        'list_my_region_content_bookmarks',
        params: {'p_limit': 200},
      );
      final list = <RegionContentBookmark>[];
      if (rows is List) {
        for (final raw in rows) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final kind = RegionContentKindX.parse(map['kind']?.toString());
          final id = map['target_id']?.toString().trim() ?? '';
          if (kind == null || id.isEmpty) continue;
          list.add(
            RegionContentBookmark(
              kind: kind,
              targetId: id,
              createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
            ),
          );
        }
      }
      _cache = list;
      await _savePrefs(list);
    } catch (e) {
      debugPrint('list_my_region_content_bookmarks: $e');
      _cache = await _loadPrefs();
    }
  }

  Future<bool> toggle(RegionContentKind kind, String targetId) async {
    final id = targetId.trim();
    if (id.isEmpty) return isBookmarked(kind, id);

    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        final res = await client.rpc(
          'toggle_region_content_bookmark',
          params: {
            'p_kind': kind.wire,
            'p_target_id': id,
          },
        );
        var bookmarked = !isBookmarked(kind, id);
        if (res is Map) {
          final b = res['bookmarked'];
          if (b is bool) bookmarked = b;
        }
        await refresh();
        return bookmarked;
      }
    } catch (e) {
      debugPrint('toggle_region_content_bookmark: $e');
    }

    // Local fallback (migration not applied / signed out).
    final next = List<RegionContentBookmark>.from(_cache);
    final idx = next.indexWhere((e) => e.kind == kind && e.targetId == id);
    final bool bookmarked;
    if (idx >= 0) {
      next.removeAt(idx);
      bookmarked = false;
    } else {
      next.insert(
        0,
        RegionContentBookmark(
          kind: kind,
          targetId: id,
          createdAt: DateTime.now(),
        ),
      );
      bookmarked = true;
    }
    _cache = next;
    await _savePrefs(next);
    return bookmarked;
  }

  Future<List<RegionContentBookmark>> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <RegionContentBookmark>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final kind = RegionContentKindX.parse(e['kind']?.toString());
        final id = e['id']?.toString().trim() ?? '';
        if (kind == null || id.isEmpty) continue;
        out.add(RegionContentBookmark(kind: kind, targetId: id));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _savePrefs(List<RegionContentBookmark> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = items
          .map((e) => {'kind': e.kind.wire, 'id': e.targetId})
          .toList();
      await prefs.setString(_prefsKey, jsonEncode(payload));
    } catch (_) {}
  }
}
