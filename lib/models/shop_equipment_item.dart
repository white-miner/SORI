import '../utils/db_map.dart';

/// 샵 「사용 기기 및 제품」카드.
class ShopEquipmentItem {
  const ShopEquipmentItem({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? imageUrl;

  bool get hasImage {
    final u = imageUrl?.trim() ?? '';
    return u.startsWith('http') || u.startsWith('data:');
  }

  ShopEquipmentItem copyWith({
    String? id,
    String? name,
    String? imageUrl,
    bool clearImage = false,
  }) {
    return ShopEquipmentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name.trim(),
        'image_url': () {
          final u = imageUrl?.trim() ?? '';
          return u.isEmpty ? null : u;
        }(),
      };

  factory ShopEquipmentItem.fromDynamic(dynamic value) {
    if (value is String) {
      final n = value.trim();
      return ShopEquipmentItem(
        id: 'eq-${n.hashCode}',
        name: n,
      );
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final name = DbMap.asText(map['name']);
      final id = DbMap.asText(map['id']);
      return ShopEquipmentItem(
        id: id.isEmpty ? 'eq-${name.hashCode}' : id,
        name: name,
        imageUrl: DbMap.asTextOrNull(map['image_url'] ?? map['imageUrl']),
      );
    }
    return const ShopEquipmentItem(id: 'eq-empty', name: '');
  }
}
