class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.lastTreatmentDate,
    required this.treatmentType,
    this.shopId = 'shop-demo',
    this.memo = '',
    this.membershipTotalVisits = 0,
  });

  final String id;
  final String name;
  final String phone;
  final DateTime lastTreatmentDate;
  final String treatmentType;
  final String shopId;
  final String memo;
  final int membershipTotalVisits;

  bool get isMembershipCustomer => membershipTotalVisits > 0;

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    DateTime? lastTreatmentDate,
    String? treatmentType,
    String? shopId,
    String? memo,
    int? membershipTotalVisits,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      lastTreatmentDate: lastTreatmentDate ?? this.lastTreatmentDate,
      treatmentType: treatmentType ?? this.treatmentType,
      shopId: shopId ?? this.shopId,
      memo: memo ?? this.memo,
      membershipTotalVisits:
          membershipTotalVisits ?? this.membershipTotalVisits,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'shop_id': shopId,
        'name': name,
        'phone': phone,
        'last_treatment_date': lastTreatmentDate.toIso8601String(),
        'treatment_type': treatmentType,
        'memo': memo,
        'membership_total_visits': membershipTotalVisits,
      };

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      shopId: map['shop_id'] as String? ?? 'shop-demo',
      name: map['name'] as String,
      phone: map['phone'] as String,
      lastTreatmentDate: DateTime.parse(map['last_treatment_date'] as String),
      treatmentType: map['treatment_type'] as String? ?? '',
      memo: map['memo'] as String? ?? '',
      membershipTotalVisits: map['membership_total_visits'] as int? ?? 0,
    );
  }
}
