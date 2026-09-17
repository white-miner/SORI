/// Legacy lead intake — customer preferred schedule (not Visit Launcher).
enum CareScheduleSource {
  manual,
  customerLead;

  String get label => switch (this) {
        CareScheduleSource.manual => '수동',
        CareScheduleSource.customerLead => '희망 일정',
      };
}

enum CareScheduleStatus {
  scheduled,
  completed,
  cancelled;

  String get dbValue => name;

  static CareScheduleStatus fromDb(String? raw) {
    return CareScheduleStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => CareScheduleStatus.scheduled,
    );
  }
}

class CareScheduleEntry {
  const CareScheduleEntry({
    required this.id,
    required this.shopId,
    required this.scheduledAt,
    required this.customerName,
    this.customerId,
    this.customerPhone,
    this.careLabel = '',
    this.note = '',
    this.source = CareScheduleSource.manual,
    this.status = CareScheduleStatus.scheduled,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final DateTime scheduledAt;
  final String customerName;
  final String? customerId;
  final String? customerPhone;
  final String careLabel;
  final String note;
  final CareScheduleSource source;
  final CareScheduleStatus status;
  final DateTime? createdAt;

  bool isSameDay(DateTime day) {
    return scheduledAt.year == day.year &&
        scheduledAt.month == day.month &&
        scheduledAt.day == day.day;
  }

  CareScheduleEntry copyWith({
    CareScheduleStatus? status,
    String? careLabel,
    String? note,
    String? customerId,
  }) {
    return CareScheduleEntry(
      id: id,
      shopId: shopId,
      scheduledAt: scheduledAt,
      customerName: customerName,
      customerId: customerId ?? this.customerId,
      customerPhone: customerPhone,
      careLabel: careLabel ?? this.careLabel,
      note: note ?? this.note,
      source: source,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'customer_name': customerName,
      'customer_id': customerId,
      'customer_phone': customerPhone,
      'care_label': careLabel,
      'note': note,
      'source': source.name,
      'status': status.dbValue,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  factory CareScheduleEntry.fromMap(Map<String, dynamic> map) {
    final scheduledRaw = map['scheduled_at']?.toString() ?? '';
    return CareScheduleEntry(
      id: map['id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      scheduledAt: DateTime.tryParse(scheduledRaw)?.toLocal() ?? DateTime.now(),
      customerName: map['customer_name']?.toString() ?? '',
      customerId: map['customer_id']?.toString(),
      customerPhone: map['customer_phone']?.toString(),
      careLabel: map['care_label']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      source: CareScheduleSource.values.firstWhere(
        (e) => e.name == map['source']?.toString(),
        orElse: () => CareScheduleSource.manual,
      ),
      status: CareScheduleStatus.fromDb(map['status']?.toString()),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }
}
