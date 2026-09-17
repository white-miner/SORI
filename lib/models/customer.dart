import '../utils/db_map.dart';
import 'customer_membership.dart';

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
    this.memberships = const [],
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
    this.lastPromotionSentAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final DateTime lastTreatmentDate;
  final String treatmentType;
  final String shopId;
  final String memo;

  /// 다중 회원권 (customers.memberships jsonb).
  final List<CustomerMembership> memberships;

  /// 레거시 단일 회원권 컬럼 (동기화용 미러).
  final String membershipServiceName;
  final int membershipTotalVisits;
  final int membershipUsedVisits;

  final CustomerGender? gender;
  final DateTime? birthDate;
  final String address;
  final String occupation;
  final String allergyNotes;
  final String medicationHistory;
  final String homeCareHabits;

  /// 회원권 사용요청/프로모션 마지막 발송.
  final DateTime? lastPromotionSentAt;

  /// 고객 등록일 (장기 미방문 부채 트리거용).
  final DateTime? createdAt;

  List<CustomerMembership> get activeMemberships =>
      memberships.where((m) => m.totalVisits > 0).toList();

  CustomerMembership? get primaryMembership {
    final active = memberships.where((m) => m.isActive).toList();
    if (active.isNotEmpty) return active.first;
    if (memberships.isNotEmpty) return memberships.first;
    return null;
  }

  bool get isMembershipCustomer =>
      memberships.any((m) => m.totalVisits > 0) || membershipTotalVisits > 0;

  int get membershipRemainingVisits {
    if (memberships.isNotEmpty) {
      return memberships.fold<int>(0, (sum, m) => sum + m.remainingVisits);
    }
    if (!isMembershipCustomer) return 0;
    return (membershipTotalVisits - membershipUsedVisits).clamp(0, 999);
  }

  double get membershipProgress {
    final total = memberships.isNotEmpty
        ? memberships.fold<int>(0, (s, m) => s + m.totalVisits)
        : membershipTotalVisits;
    final used = memberships.isNotEmpty
        ? memberships.fold<int>(0, (s, m) => s + m.usedVisits)
        : membershipUsedVisits;
    if (total <= 0) return 0;
    return (used / total).clamp(0.0, 1.0);
  }

  bool get isMembershipLow =>
      isMembershipCustomer &&
      (memberships.any((m) => m.isLow) ||
          (memberships.isEmpty && membershipRemainingVisits <= 2));

  String get membershipBadgeLabel {
    if (!isMembershipCustomer) return '회원권 미등록';
    if (memberships.length > 1) {
      return '회원권 ${memberships.length}종 · 잔여 $membershipRemainingVisits회';
    }
    final p = primaryMembership;
    if (p != null) {
      return '진행 ${p.usedVisits}회 / 잔여 ${p.remainingVisits}회';
    }
    return '진행 $membershipUsedVisits회 / 잔여 $membershipRemainingVisits회';
  }

  String? get birthYearLabel {
    if (birthDate == null) return null;
    return '${birthDate!.year}년생';
  }

  /// 만 나이 (생년월일 기준).
  int? get koreanAge {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var age = now.year - b.year;
    if (now.month < b.month ||
        (now.month == b.month && now.day < b.day)) {
      age -= 1;
    }
    return age < 0 ? null : age;
  }

  String get nameWithAge {
    final age = koreanAge;
    if (age == null) return name;
    return '$name (만 $age세)';
  }

  /// 레거시 컬럼과 memberships 리스트를 맞춘 복사본.
  Customer withSyncedMembershipMirrors() {
    final list = memberships.isNotEmpty
        ? memberships
        : (membershipTotalVisits > 0
            ? [
                CustomerMembership(
                  id: 'legacy-$id',
                  serviceName: membershipServiceName.isNotEmpty
                      ? membershipServiceName
                      : treatmentType,
                  totalVisits: membershipTotalVisits,
                  usedVisits: membershipUsedVisits,
                ),
              ]
            : const <CustomerMembership>[]);
    final primary = list.isNotEmpty ? list.first : null;
    return copyWith(
      memberships: list,
      membershipServiceName: primary?.serviceName ?? '',
      membershipTotalVisits: primary?.totalVisits ?? 0,
      membershipUsedVisits: primary?.usedVisits ?? 0,
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    DateTime? lastTreatmentDate,
    String? treatmentType,
    String? shopId,
    String? memo,
    List<CustomerMembership>? memberships,
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
    DateTime? lastPromotionSentAt,
    DateTime? createdAt,
    bool clearGender = false,
    bool clearBirthDate = false,
    bool clearLastPromotionSentAt = false,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      lastTreatmentDate: lastTreatmentDate ?? this.lastTreatmentDate,
      treatmentType: treatmentType ?? this.treatmentType,
      shopId: shopId ?? this.shopId,
      memo: memo ?? this.memo,
      memberships: memberships ?? this.memberships,
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
      lastPromotionSentAt: clearLastPromotionSentAt
          ? null
          : (lastPromotionSentAt ?? this.lastPromotionSentAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// customers upsert 전용 안전 페이로드 (메디컬·차트 필드 제외).
  /// SSOT: memberships jsonb → sync → membership_tickets.
  Map<String, dynamic> toDbWriteMap({bool includeId = false}) {
    final synced = withSyncedMembershipMirrors();
    final map = <String, dynamic>{
      'shop_id': synced.shopId,
      'name': synced.name,
      'phone': synced.phone.replaceAll(RegExp(r'[^0-9]'), ''),
      'last_treatment_date':
          '${synced.lastTreatmentDate.year.toString().padLeft(4, '0')}-'
          '${synced.lastTreatmentDate.month.toString().padLeft(2, '0')}-'
          '${synced.lastTreatmentDate.day.toString().padLeft(2, '0')}',
      'treatment_type': synced.treatmentType,
      'memo': synced.memo,
      'memberships': synced.memberships.map((m) => m.toJson()).toList(),
      // 레거시 미러 (구 UI/쿼리 호환). 티켓 지갑 SSOT 는 membership_tickets.
      'membership_service_name': synced.membershipServiceName,
      'membership_total_visits': synced.membershipTotalVisits,
      'membership_used_visits': synced.membershipUsedVisits,
      'gender': synced.gender?.dbValue,
      'birth_date': synced.birthDate == null
          ? null
          : '${synced.birthDate!.year.toString().padLeft(4, '0')}-'
              '${synced.birthDate!.month.toString().padLeft(2, '0')}-'
              '${synced.birthDate!.day.toString().padLeft(2, '0')}',
      'address': synced.address,
      'occupation': synced.occupation,
      'last_promotion_sent_at':
          synced.lastPromotionSentAt?.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (includeId && synced.id.isNotEmpty) {
      map['id'] = synced.id;
    }
    return map;
  }

  Map<String, dynamic> toMap() {
    final synced = withSyncedMembershipMirrors();
    return {
      ...synced.toDbWriteMap(includeId: true),
      // 로컬/디버그용 — DB customers upsert 에는 넣지 않음 (차트 SSOT)
      'allergy_notes': synced.allergyNotes,
      'medication_history': synced.medicationHistory,
      'home_care_habits': synced.homeCareHabits,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    final id = DbMap.asText(map['id']);
    final name = DbMap.asText(map['name']);
    final phone = DbMap.asText(map['phone']);
    if (id.isEmpty || name.isEmpty || phone.isEmpty) {
      throw FormatException('customer row missing required fields: $map');
    }

    final rawMemberships = map['memberships'];
    var memberships = <CustomerMembership>[];
    if (rawMemberships is List) {
      for (final item in rawMemberships) {
        if (item is Map) {
          memberships.add(
            CustomerMembership.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final legacyName = DbMap.asText(map['membership_service_name']);
    final legacyTotal = DbMap.asInt(map['membership_total_visits']);
    final legacyUsed = DbMap.asInt(map['membership_used_visits']);
    if (memberships.isEmpty && legacyTotal > 0) {
      memberships = [
        CustomerMembership(
          id: 'legacy-$id',
          serviceName: legacyName,
          totalVisits: legacyTotal,
          usedVisits: legacyUsed,
        ),
      ];
    }

    return Customer(
      id: id,
      shopId: DbMap.asText(map['shop_id'], 'shop-demo'),
      name: name,
      phone: phone,
      lastTreatmentDate: DbMap.asDateTimeOrNow(map['last_treatment_date']),
      treatmentType: DbMap.asText(map['treatment_type']),
      memo: DbMap.asText(map['memo']),
      memberships: memberships,
      membershipServiceName: legacyName,
      membershipTotalVisits: legacyTotal,
      membershipUsedVisits: legacyUsed,
      gender: CustomerGenderX.fromDb(DbMap.asTextOrNull(map['gender'])),
      birthDate: DbMap.asDateTime(map['birth_date']),
      address: DbMap.asText(map['address']),
      occupation: DbMap.asText(map['occupation']),
      allergyNotes: DbMap.asText(map['allergy_notes']),
      medicationHistory: DbMap.asText(map['medication_history']),
      homeCareHabits: DbMap.asText(map['home_care_habits']),
      lastPromotionSentAt: DbMap.asDateTime(map['last_promotion_sent_at']),
      createdAt: DbMap.asDateTime(map['created_at']),
    ).withSyncedMembershipMirrors();
  }
}
