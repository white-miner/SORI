import '../utils/db_map.dart';

/// [get_case_timeline_group] RPC / 로컬 그룹핑 결과.
class CaseTimelineEntry {
  const CaseTimelineEntry({
    required this.chartId,
    required this.visitNumber,
    required this.careName,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.careTags = const [],
    this.createdAt,
  });

  final String chartId;
  final int visitNumber;
  final String careName;
  final String? beforeImageUrl;
  final String? afterImageUrl;
  final List<String> careTags;
  final DateTime? createdAt;

  factory CaseTimelineEntry.fromMap(Map<String, dynamic> map) {
    return CaseTimelineEntry(
      chartId: DbMap.asText(map['chart_id'] ?? map['id']),
      visitNumber: DbMap.asInt(map['visit_number'], 1),
      careName: DbMap.asText(map['care_name']),
      beforeImageUrl: DbMap.asTextOrNull(map['before_image_url']),
      afterImageUrl: DbMap.asTextOrNull(map['after_image_url']),
      careTags: () {
        final tags = DbMap.asStringList(map['care_tags']);
        if (tags.isNotEmpty) return tags;
        return DbMap.asStringList(map['concern_chips']);
      }(),
      createdAt: DbMap.asDateTime(map['created_at']),
    );
  }
}
