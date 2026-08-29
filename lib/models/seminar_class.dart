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
    this.durationMinutes = 120,
    this.providedMaterials = const [],
    this.additionalImages = const [],
    this.createdAt,
  });

  final String id;
  final String directorShopId;

  /// PO linked_chart_id — source B/A chart.
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

  /// Total class duration in minutes.
  final int durationMinutes;

  /// PPT, pigments, diploma, etc.
  final List<String> providedMaterials;

  /// Extra promo images beyond linked chart.
  final List<String> additionalImages;
  final DateTime? createdAt;

  /// PO alias for [targetCaseId].
  String? get linkedChartId => targetCaseId;

  bool get isEnrollable =>
      status == SeminarClassStatus.open || status == SeminarClassStatus.held;

  static const formatOptions = <({String value, String label})>[
    (value: 'oneday', label: '원데이'),
    (value: 'regular', label: '정규'),
    (value: 'one_on_one', label: '1:1 밀착'),
    (value: 'demo', label: '데모 참관'),
  ];

  static const durationOptions = <({int minutes, String label})>[
    (minutes: 60, label: '1시간'),
    (minutes: 90, label: '1시간 30분'),
    (minutes: 120, label: '2시간'),
    (minutes: 150, label: '2시간 30분'),
    (minutes: 180, label: '3시간'),
    (minutes: 210, label: '3시간 30분'),
    (minutes: 240, label: '4시간'),
    (minutes: 300, label: '5시간'),
  ];

  static const materialSuggestions = <String>[
    '자체 제작 PPT',
    '실습용 색소',
    '디플로마',
    '수료증',
    '실습 키트',
    '교재 PDF',
  ];

  String get classFormatLabel {
    for (final o in formatOptions) {
      if (o.value == classFormat) return o.label;
    }
    return classFormat;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  factory SeminarClass.fromMap(Map<String, dynamic> map) {
    return SeminarClass(
      id: DbMap.asText(map['id']),
      directorShopId: DbMap.asText(map['director_shop_id']),
      targetCaseId: DbMap.asTextOrNull(
        map['target_case_id'] ?? map['linked_chart_id'],
      ),
      title: DbMap.asText(map['title']),
      eventDate: DbMap.asDateTime(map['event_date']),
      location: DbMap.asText(map['location']),
      price: DbMap.asInt(map['price']),
      maxCapacity: DbMap.asInt(map['max_capacity'], 20),
      currentEnrollment: DbMap.asInt(map['current_enrollment']),
      status: SeminarClassStatus.fromDb(DbMap.asText(map['status'])),
      description: DbMap.asText(map['description']),
      classFormat: DbMap.asText(map['class_format'], 'oneday'),
      durationMinutes: DbMap.asInt(map['duration_minutes'], 120),
      providedMaterials: _stringList(map['provided_materials']),
      additionalImages: _stringList(map['additional_images']),
      createdAt: DbMap.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toRpcPayload({bool includeId = false}) => {
        if (includeId && id.trim().isNotEmpty) 'id': id.trim(),
        'director_shop_id': directorShopId,
        'linked_chart_id': targetCaseId?.trim(),
        'title': title.trim(),
        if (eventDate != null)
          'event_date': eventDate!.toUtc().toIso8601String(),
        'location': location.trim(),
        'price': price,
        'max_capacity': maxCapacity,
        'status': status.dbValue,
        'description': description.trim(),
        'class_format':
            classFormat.trim().isEmpty ? 'oneday' : classFormat.trim(),
        'duration_minutes': durationMinutes,
        'provided_materials': providedMaterials,
        'additional_images': additionalImages,
      };

  Map<String, dynamic> toInsertMap() => {
        'director_shop_id': directorShopId,
        'target_case_id': targetCaseId?.trim(),
        'title': title.trim(),
        if (eventDate != null) 'event_date': eventDate!.toUtc().toIso8601String(),
        'location': location.trim(),
        'price': price,
        'max_capacity': maxCapacity,
        'status': status.dbValue,
        if (description.trim().isNotEmpty) 'description': description.trim(),
        'class_format': classFormat.trim().isEmpty ? 'oneday' : classFormat.trim(),
        'duration_minutes': durationMinutes,
        'provided_materials': providedMaterials,
        'additional_images': additionalImages,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'title': title.trim(),
        if (eventDate != null) 'event_date': eventDate!.toUtc().toIso8601String(),
        'location': location.trim(),
        'price': price,
        'max_capacity': maxCapacity,
        'status': status.dbValue,
        'description': description.trim(),
        'class_format':
            classFormat.trim().isEmpty ? 'oneday' : classFormat.trim(),
        'target_case_id': targetCaseId?.trim(),
        'duration_minutes': durationMinutes,
        'provided_materials': providedMaterials,
        'additional_images': additionalImages,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  SeminarClass copyWith({
    int? currentEnrollment,
    SeminarClassStatus? status,
    String? classFormat,
    String? description,
    String? title,
    DateTime? eventDate,
    String? location,
    int? price,
    int? maxCapacity,
    String? targetCaseId,
    int? durationMinutes,
    List<String>? providedMaterials,
    List<String>? additionalImages,
    bool clearTargetCase = false,
  }) {
    return SeminarClass(
      id: id,
      directorShopId: directorShopId,
      targetCaseId: clearTargetCase ? null : (targetCaseId ?? this.targetCaseId),
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      location: location ?? this.location,
      price: price ?? this.price,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      currentEnrollment: currentEnrollment ?? this.currentEnrollment,
      status: status ?? this.status,
      description: description ?? this.description,
      classFormat: classFormat ?? this.classFormat,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      providedMaterials: providedMaterials ?? this.providedMaterials,
      additionalImages: additionalImages ?? this.additionalImages,
      createdAt: createdAt,
    );
  }
}
