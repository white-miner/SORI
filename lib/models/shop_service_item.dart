import '../utils/db_map.dart';

/// 샵 서비스 메뉴 항목 (서비스명 + 키워드 칩 + 설명 + 선택 기기).
class ShopServiceItem {
  const ShopServiceItem({
    required this.name,
    this.description = '',
    this.deviceInfo,
    this.keywords = const [],
  });

  final String name;
  final String description;

  /// 사용 기기. 미입력이면 null.
  final String? deviceInfo;

  /// 서비스 메뉴 키워드 칩 (기기/체감/효과 등).
  final List<String> keywords;

  ShopServiceItem copyWith({
    String? name,
    String? description,
    String? deviceInfo,
    List<String>? keywords,
    bool clearDeviceInfo = false,
  }) {
    return ShopServiceItem(
      name: name ?? this.name,
      description: description ?? this.description,
      deviceInfo: clearDeviceInfo ? null : (deviceInfo ?? this.deviceInfo),
      keywords: keywords ?? this.keywords,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'keywords': DbMap.sanitizeStringList(keywords),
        'device_info': () {
          final d = deviceInfo?.trim() ?? '';
          return d.isEmpty ? null : d;
        }(),
      };

  /// string 배열(레거시)과 `{name, description, keywords, device_info}` 객체 모두 수용.
  factory ShopServiceItem.fromDynamic(dynamic value) {
    if (value is String) {
      return ShopServiceItem(name: value.trim());
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final device = DbMap.asTextOrNull(
        map['device_info'] ?? map['deviceInfo'] ?? map['device'],
      );
      final keywords = DbMap.sanitizeStringList(
        map['keywords'] ?? map['chips'] ?? map['selected_chips'],
      );
      return ShopServiceItem(
        name: DbMap.asText(map['name']),
        description: DbMap.asText(map['description']),
        deviceInfo: device,
        keywords: keywords,
      );
    }
    final text = value?.toString().trim() ?? '';
    return ShopServiceItem(name: text);
  }
}
