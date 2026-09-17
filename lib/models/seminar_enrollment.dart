import '../utils/db_map.dart';

/// 세미나 수강 등록 (에스크로 held → completed).
class SeminarEnrollment {
  const SeminarEnrollment({
    required this.id,
    required this.classId,
    required this.enrollorShopId,
    required this.classTitle,
    this.amount = 0,
    this.status = 'held',
    this.eventDate,
    this.createdAt,
  });

  final String id;
  final String classId;
  final String enrollorShopId;
  final String classTitle;
  final int amount;
  final String status;
  final DateTime? eventDate;
  final DateTime? createdAt;

  bool get isHeld => status.trim().toLowerCase() == 'held';
  bool get isCompleted => status.trim().toLowerCase() == 'completed';

  factory SeminarEnrollment.fromMap(Map<String, dynamic> map) {
    final cls = map['seminar_classes'];
    final classMap = cls is Map ? Map<String, dynamic>.from(cls) : map;

    return SeminarEnrollment(
      id: DbMap.asText(map['id']),
      classId: DbMap.asText(map['class_id'] ?? classMap['id']),
      enrollorShopId: DbMap.asText(map['enrollor_shop_id']),
      classTitle: DbMap.asText(
        classMap['title'] ?? map['class_title'],
        '세미나 클래스',
      ),
      amount: DbMap.asInt(map['amount']),
      status: DbMap.asText(map['status'], 'held'),
      eventDate: DbMap.asDateTime(classMap['event_date']),
      createdAt: DbMap.asDateTime(map['created_at']),
    );
  }
}
