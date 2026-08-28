import '../utils/db_map.dart';

/// 보관함 북마크 1건.
class CaseBookmarkEntry {
  const CaseBookmarkEntry({
    required this.chartId,
    this.folder = 'default',
    this.createdAt,
  });

  final String chartId;
  final String folder;
  final DateTime? createdAt;

  factory CaseBookmarkEntry.fromMap(Map<String, dynamic> map) {
    return CaseBookmarkEntry(
      chartId: DbMap.asText(map['chart_id'] ?? map['chartId']),
      folder: DbMap.asText(map['folder'], 'default'),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
    );
  }
}

class CaseBookmarkToggleResult {
  const CaseBookmarkToggleResult({
    required this.ok,
    required this.chartId,
    required this.bookmarked,
    this.folder = 'default',
  });

  final bool ok;
  final String chartId;
  final bool bookmarked;
  final String folder;

  factory CaseBookmarkToggleResult.fromMap(Map<String, dynamic> map) {
    return CaseBookmarkToggleResult(
      ok: map['ok'] == true,
      chartId: DbMap.asText(map['chart_id'] ?? map['chartId']),
      bookmarked: map['bookmarked'] == true,
      folder: DbMap.asText(map['folder'], 'default'),
    );
  }
}
