import '../utils/db_map.dart';

class CareDiaryNote {
  const CareDiaryNote({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.noteDate,
    this.body = '',
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final String customerId;
  final DateTime noteDate;
  final String body;
  final DateTime? updatedAt;

  CareDiaryNote copyWith({
    String? id,
    String? shopId,
    String? customerId,
    DateTime? noteDate,
    String? body,
    DateTime? updatedAt,
  }) {
    return CareDiaryNote(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      customerId: customerId ?? this.customerId,
      noteDate: noteDate ?? this.noteDate,
      body: body ?? this.body,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toDbWriteMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'shop_id': shopId,
      'customer_id': customerId,
      'note_date':
          '${noteDate.year.toString().padLeft(4, '0')}-${noteDate.month.toString().padLeft(2, '0')}-${noteDate.day.toString().padLeft(2, '0')}',
      'body': body.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (includeId && id.isNotEmpty && !id.startsWith('diary-')) {
      map['id'] = id;
    }
    return map;
  }

  factory CareDiaryNote.fromMap(Map<String, dynamic> map) {
    final id = DbMap.asText(map['id']);
    final shopId = DbMap.asText(map['shop_id']);
    final customerId = DbMap.asText(map['customer_id']);
    final noteDate = DbMap.asDateTime(map['note_date']) ?? DateTime.now();
    if (id.isEmpty || shopId.isEmpty || customerId.isEmpty) {
      throw FormatException('care_diary_note missing fields: $map');
    }
    return CareDiaryNote(
      id: id,
      shopId: shopId,
      customerId: customerId,
      noteDate: DateTime(noteDate.year, noteDate.month, noteDate.day),
      body: DbMap.asText(map['body']),
      updatedAt: DbMap.asDateTime(map['updated_at']),
    );
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
