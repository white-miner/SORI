enum CustomerGender { female, male }

extension CustomerGenderX on CustomerGender {
  String get label => switch (this) {
        CustomerGender.female => '여성',
        CustomerGender.male => '남성',
      };

  String get dbValue => switch (this) {
        CustomerGender.female => 'female',
        CustomerGender.male => 'male',
      };

  static CustomerGender? fromDb(String? value) => switch (value) {
        'female' => CustomerGender.female,
        'male' => CustomerGender.male,
        _ => null,
      };
}

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
    this.gender,
    this.birthDate,
    this.address = '',
    this.occupation = '',
    this.allergyNotes = '',
    this.medicationHistory = '',
    this.homeCareHabits = '',
  });

  final String id;
  final String name;
  final String phone;
  final DateTime lastTreatmentDate;
  final String treatmentType;
  final String shopId;
  final String memo;
  final int membershipTotalVisits;
  final CustomerGender? gender;
  final DateTime? birthDate;
  final String address;
  final String occupation;
  final String allergyNotes;
  final String medicationHistory;
  final String homeCareHabits;

  bool get isMembershipCustomer => membershipTotalVisits > 0;

  String? get birthYearLabel {
    if (birthDate == null) return null;
    return '${birthDate!.year}년생';
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    DateTime? lastTreatmentDate,
    String? treatmentType,
    String? shopId,
    String? memo,
    int? membershipTotalVisits,
    CustomerGender? gender,
    DateTime? birthDate,
    String? address,
    String? occupation,
    String? allergyNotes,
    String? medicationHistory,
    String? homeCareHabits,
    bool clearGender = false,
    bool clearBirthDate = false,
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
      gender: clearGender ? null : (gender ?? this.gender),
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      address: address ?? this.address,
      occupation: occupation ?? this.occupation,
      allergyNotes: allergyNotes ?? this.allergyNotes,
      medicationHistory: medicationHistory ?? this.medicationHistory,
      homeCareHabits: homeCareHabits ?? this.homeCareHabits,
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
        'gender': gender?.dbValue,
        'birth_date': birthDate?.toIso8601String(),
        'address': address,
        'occupation': occupation,
        'allergy_notes': allergyNotes,
        'medication_history': medicationHistory,
        'home_care_habits': homeCareHabits,
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
      gender: CustomerGenderX.fromDb(map['gender'] as String?),
      birthDate: map['birth_date'] != null
          ? DateTime.parse(map['birth_date'] as String)
          : null,
      address: map['address'] as String? ?? '',
      occupation: map['occupation'] as String? ?? '',
      allergyNotes: map['allergy_notes'] as String? ?? '',
      medicationHistory: map['medication_history'] as String? ?? '',
      homeCareHabits: map['home_care_habits'] as String? ?? '',
    );
  }
}
