class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.lastTreatmentDate,
    required this.treatmentType,
    this.memo = '',
  });

  final String id;
  final String name;
  final String phone;
  final DateTime lastTreatmentDate;
  final String treatmentType;
  final String memo;

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    DateTime? lastTreatmentDate,
    String? treatmentType,
    String? memo,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      lastTreatmentDate: lastTreatmentDate ?? this.lastTreatmentDate,
      treatmentType: treatmentType ?? this.treatmentType,
      memo: memo ?? this.memo,
    );
  }
}
