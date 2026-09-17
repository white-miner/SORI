import '../utils/db_map.dart';

/// 미연결(신규) 촬영 큐 항목 — 기기 로컬 + chart_photos URL.
class ShootInboxItem {
  const ShootInboxItem({
    required this.id,
    required this.shopId,
    required this.kind,
    required this.imageUrl,
    this.label = '',
    this.sessionToken = '',
    this.createdAt,
    this.ghostBeforeUrl,
  });

  final String id;
  final String shopId;

  /// before | after
  final String kind;
  final String imageUrl;
  final String label;
  final String sessionToken;
  final DateTime? createdAt;

  /// After 잔상용 (같은 세션 Before URL).
  final String? ghostBeforeUrl;

  bool get isBefore => kind == 'before';
  bool get isAfter => kind == 'after';

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'kind': kind,
        'image_url': imageUrl,
        'label': label,
        'session_token': sessionToken,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'ghost_before_url': ghostBeforeUrl,
      };

  factory ShootInboxItem.fromJson(Map<String, dynamic> map) {
    return ShootInboxItem(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id'] ?? map['shopId']),
      kind: DbMap.asText(map['kind'], 'before'),
      imageUrl: DbMap.asText(map['image_url'] ?? map['imageUrl']),
      label: DbMap.asText(map['label']),
      sessionToken: DbMap.asText(map['session_token'] ?? map['sessionToken']),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']),
      ghostBeforeUrl: DbMap.asTextOrNull(
        map['ghost_before_url'] ?? map['ghostBeforeUrl'],
      ),
    );
  }

  ShootInboxItem copyWith({
    String? label,
    String? ghostBeforeUrl,
  }) {
    return ShootInboxItem(
      id: id,
      shopId: shopId,
      kind: kind,
      imageUrl: imageUrl,
      label: label ?? this.label,
      sessionToken: sessionToken,
      createdAt: createdAt,
      ghostBeforeUrl: ghostBeforeUrl ?? this.ghostBeforeUrl,
    );
  }
}
