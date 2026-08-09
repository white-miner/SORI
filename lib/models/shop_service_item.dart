import '../utils/db_map.dart';

/// 샵 서비스 메뉴 항목 (서비스명 + 고객 안내용 설명).
class ShopServiceItem {
  const ShopServiceItem({
    required this.name,
    this.description = '',
  });

  final String name;
  final String description;

  ShopServiceItem copyWith({
    String? name,
    String? description,
  }) {
    return ShopServiceItem(
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
      };

  /// string 배열(레거시)과 `{name, description}` 객체 모두 수용.
  factory ShopServiceItem.fromDynamic(dynamic value) {
    if (value is String) {
      return ShopServiceItem(name: value.trim());
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return ShopServiceItem(
        name: DbMap.asText(map['name']),
        description: DbMap.asText(map['description']),
      );
    }
    final text = value?.toString().trim() ?? '';
    return ShopServiceItem(name: text);
  }
}
