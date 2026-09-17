import '../utils/db_map.dart';

/// 세미나 수강 신청서 (`seminar_applications`).
class SeminarApplication {
  const SeminarApplication({
    required this.id,
    required this.classId,
    required this.applicantName,
    this.applicantShopId,
    this.applicantUserId,
    this.shopName = '',
    this.contactPhone = '',
    this.careerType = '',
    this.question = '',
    this.refundAgreed = false,
    this.status = 'submitted',
    this.createdAt,
  });

  final String id;
  final String classId;
  final String? applicantShopId;
  final String? applicantUserId;
  final String applicantName;
  final String shopName;
  final String contactPhone;
  final String careerType;
  final String question;
  final bool refundAgreed;
  final String status;
  final DateTime? createdAt;

  static const careerOptions = [
    '1인 샵 운영',
    '2~5인 규모 샵',
    '프랜차이즈/대형',
    '원장 지망(개업 전)',
    '기타',
  ];

  Map<String, dynamic> toInsertMap() => {
        'class_id': classId.trim(),
        if (applicantShopId != null && applicantShopId!.trim().isNotEmpty)
          'applicant_shop_id': applicantShopId!.trim(),
        if (applicantUserId != null && applicantUserId!.trim().isNotEmpty)
          'applicant_user_id': applicantUserId!.trim(),
        'applicant_name': applicantName.trim(),
        'shop_name': shopName.trim(),
        'contact_phone': contactPhone.trim(),
        'career_type': careerType.trim(),
        'question': question.trim(),
        'refund_agreed': refundAgreed,
        'status': status,
      };

  factory SeminarApplication.fromMap(Map<String, dynamic> map) {
    return SeminarApplication(
      id: DbMap.asText(map['id']),
      classId: DbMap.asText(map['class_id']),
      applicantShopId: DbMap.asTextOrNull(map['applicant_shop_id']),
      applicantUserId: DbMap.asTextOrNull(map['applicant_user_id']),
      applicantName: DbMap.asText(map['applicant_name']),
      shopName: DbMap.asText(map['shop_name']),
      contactPhone: DbMap.asText(map['contact_phone']),
      careerType: DbMap.asText(map['career_type']),
      question: DbMap.asText(map['question']),
      refundAgreed: DbMap.asBool(map['refund_agreed']),
      status: DbMap.asText(map['status'], 'submitted'),
      createdAt: DbMap.asDateTime(map['created_at']),
    );
  }
}
