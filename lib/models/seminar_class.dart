import '../utils/db_map.dart';

enum SeminarClassStatus {
  draft,
  open,
  held,
  completed,
  cancelled;

  String get dbValue => name;

  static SeminarClassStatus fromDb(String? raw) {
    final v = (raw ?? 'open').trim().toLowerCase();
    return SeminarClassStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => SeminarClassStatus.open,
    );
  }
}

class SeminarClass {
  const SeminarClass({
    required this.id,
    required this.directorShopId,
    required this.title,
    this.targetCaseId,
    this.eventDate,
    this.location = '',
    this.price = 0,
    this.maxCapacity = 20,
    this.currentEnrollment = 0,
    this.status = SeminarClassStatus.open,
    this.description = '',
    this.classFormat = 'oneday',
    this.createdAt,
  });

  final String id;
  final String directorShopId;
  final String? targetCaseId;
  final String title;
  final DateTime? eventDate;
  final String location;
  final int price;
  final int maxCapacity;
  final int currentEnrollment;
  final SeminarClassStatus status;

  /// 강사가 작성한 세미나 상세 설명.
  final String description;

  /// oneday | regular | one_on_one | demo
  final String classFormat;
  final DateTime? createdAt;

  bool get isEnrollable =>
      status == SeminarClassStatus.open || status == SeminarClassStatus.held;

  static const formatOptions = <({String value, String label})>[
    (value: 'oneday', label: '원데이'),
    (value: 'regular', label: '정규'),
    (value: 'one_on_one', label: '1:1 밀착'),
    (value: 'demo', label: '데모 참관'),
  ];

  String get classFormatLabel {
    for (final o in formatOptions) {
      if (o.value == classFormat) return o.label;
    }
    return classFormat;
  }

  factory SeminarClass.fromMap(Map<String, dynamic> map) {
    return SeminarClass(
      id: DbMap.asText(map['id']),
      directorShopId: DbMap.asText(map['director_shop_id']),
      targetCaseId: DbMap.asTextOrNull(map['target_case_id']),
      title: DbMap.asText(map['title']),
      eventDate: DbMap.asDateTime(map['event_date']),
      location: DbMap.asText(map['location']),
      price: DbMap.asInt(map['price']),
      maxCapacity: DbMap.asInt(map['max_capacity'], 20),
      currentEnrollment: DbMap.asInt(map['current_enrollment']),
      status: SeminarClassStatus.fromDb(DbMap.asText(map['status'])),
      description: DbMap.asText(map['description']),
      classFormat: DbMap.asText(map['class_format'], 'oneday'),
      createdAt: DbMap.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'director_shop_id': directorShopId,
        if (targetCaseId != null && targetCaseId!.trim().isNotEmpty)
          'target_case_id': targetCaseId!.trim(),
        'title': title.trim(),
        if (eventDate != null) 'event_date': eventDate!.toUtc().toIso8601String(),
        'location': location.trim(),
        'price': price,
        'max_capacity': maxCapacity,
        'status': status.dbValue,
        if (description.trim().isNotEmpty) 'description': description.trim(),
        'class_format': classFormat.trim().isEmpty ? 'oneday' : classFormat.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  SeminarClass copyWith({
    int? currentEnrollment,
    SeminarClassStatus? status,
    String? classFormat,
    String? description,
  }) {
    return SeminarClass(
      id: id,
      directorShopId: directorShopId,
      targetCaseId: targetCaseId,
      title: title,
      eventDate: eventDate,
      location: location,
      price: price,
      maxCapacity: maxCapacity,
      currentEnrollment: currentEnrollment ?? this.currentEnrollment,
      status: status ?? this.status,
      description: description ?? this.description,
      classFormat: classFormat ?? this.classFormat,
      createdAt: createdAt,
    );
  }
}
