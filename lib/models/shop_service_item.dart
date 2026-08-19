import '../utils/db_map.dart';

/// 샵 서비스 메뉴 항목 (서비스명 + 고객 안내용 설명 + 선택 기기).
class ShopServiceItem {
  const ShopServiceItem({
    required this.name,
    this.description = '',
    this.deviceInfo,
  });

  final String name;
  final String description;

  /// 사용 기기. 미입력이면 null.
  final String? deviceInfo;

  ShopServiceItem copyWith({
    String? name,
    String? description,
    String? deviceInfo,
    bool clearDeviceInfo = false,
  }) {
    return ShopServiceItem(
      name: name ?? this.name,
      description: description ?? this.description,
      deviceInfo: clearDeviceInfo ? null : (deviceInfo ?? this.deviceInfo),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'device_info': () {
          final d = deviceInfo?.trim() ?? '';
          return d.isEmpty ? null : d;
        }(),
      };

  /// string 배열(레거시)과 `{name, description, device_info}` 객체 모두 수용.
  factory ShopServiceItem.fromDynamic(dynamic value) {
    if (value is String) {
      return ShopServiceItem(name: value.trim());
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final device = DbMap.asTextOrNull(
        map['device_info'] ?? map['deviceInfo'] ?? map['device'],
      );
      return ShopServiceItem(
        name: DbMap.asText(map['name']),
        description: DbMap.asText(map['description']),
        deviceInfo: device,
      );
    }
    final text = value?.toString().trim() ?? '';
    return ShopServiceItem(name: text);
  }
}
