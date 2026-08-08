import '../utils/db_map.dart';

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
    this.membershipServiceName = '',
    this.membershipTotalVisits = 0,
    this.membershipUsedVisits = 0,
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

  /// 예: "재생 케어 10회권"
  final String membershipServiceName;

  /// 총 결제 횟수 (회원권 전체 회차)
  final int membershipTotalVisits;

  /// 현재까지 차감된 횟수
  final int membershipUsedVisits;

  final CustomerGender? gender;
  final DateTime? birthDate;
  final String address;
  final String occupation;
  final String allergyNotes;
  final String medicationHistory;
  final String homeCareHabits;

  bool get isMembershipCustomer => membershipTotalVisits > 0;

  int get membershipRemainingVisits {
    if (!isMembershipCustomer) return 0;
    return (membershipTotalVisits - membershipUsedVisits).clamp(0, 999);
  }

  double get membershipProgress {
    if (!isMembershipCustomer) return 0;
    return (membershipUsedVisits / membershipTotalVisits).clamp(0.0, 1.0);
  }

  /// 잔여 2회 이하 → 갱신 경고
  bool get isMembershipLow =>
      isMembershipCustomer && membershipRemainingVisits <= 2;

  String get membershipBadgeLabel {
    if (!isMembershipCustomer) return '회원권 미등록';
    return '진행 $membershipUsedVisits회 / 잔여 $membershipRemainingVisits회';
  }

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
    String? membershipServiceName,
    int? membershipTotalVisits,
    int? membershipUsedVisits,
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
      membershipServiceName:
          membershipServiceName ?? this.membershipServiceName,
      membershipTotalVisits:
          membershipTotalVisits ?? this.membershipTotalVisits,
      membershipUsedVisits:
          membershipUsedVisits ?? this.membershipUsedVisits,
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
        'membership_service_name': membershipServiceName,
        'membership_total_visits': membershipTotalVisits,
        'membership_used_visits': membershipUsedVisits,
        'gender': gender?.dbValue,
        'birth_date': birthDate?.toIso8601String(),
        'address': address,
        'occupation': occupation,
        'allergy_notes': allergyNotes,
        'medication_history': medicationHistory,
        'home_care_habits': homeCareHabits,
      };

  factory Customer.fromMap(Map<String, dynamic> map) {
    // updated_at / created_at null·지연 응답에도 파싱이 깨지지 않도록 안전 변환.
    final id = DbMap.asText(map['id']);
    final name = DbMap.asText(map['name']);
    final phone = DbMap.asText(map['phone']);
    if (id.isEmpty || name.isEmpty || phone.isEmpty) {
      throw FormatException('customer row missing required fields: $map');
    }

    return Customer(
      id: id,
      shopId: DbMap.asText(map['shop_id'], 'shop-demo'),
      name: name,
      phone: phone,
      lastTreatmentDate: DbMap.asDateTimeOrNow(map['last_treatment_date']),
      treatmentType: DbMap.asText(map['treatment_type']),
      memo: DbMap.asText(map['memo']),
      membershipServiceName: DbMap.asText(map['membership_service_name']),
      membershipTotalVisits: DbMap.asInt(map['membership_total_visits']),
      membershipUsedVisits: DbMap.asInt(map['membership_used_visits']),
      gender: CustomerGenderX.fromDb(DbMap.asTextOrNull(map['gender'])),
      birthDate: DbMap.asDateTime(map['birth_date']),
      address: DbMap.asText(map['address']),
      occupation: DbMap.asText(map['occupation']),
      allergyNotes: DbMap.asText(map['allergy_notes']),
      medicationHistory: DbMap.asText(map['medication_history']),
      homeCareHabits: DbMap.asText(map['home_care_habits']),
    );
  }
}
