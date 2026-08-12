import 'customer_chart.dart';
import 'shop.dart';

/// 카카오 알림톡 요금/템플릿 상수 (인투펫형 마진 뼈대).
abstract final class KakaoAlimtalkPricing {
  /// 발송 1건당 원장 포인트 차감.
  static const int sendCostPoint = 65;

  /// 로그에 기록하는 건당 마진(원).
  static const int defaultMarginAmount = 50;

  static const String careReportTemplate = 'SORI_CARE_REPORT_V1';
  static const String careMessageTemplate = 'SORI_CARE_MESSAGE_V1';
  static const String membershipUsageTemplate = 'SORI_MEMBERSHIP_USAGE_V1';
}

class KakaoAlimtalkSendResult {
  const KakaoAlimtalkSendResult({
    required this.ok,
    this.logId,
    this.remainingPoints,
    this.errorCode,
    this.message,
  });

  final bool ok;
  final String? logId;
  final int? remainingPoints;
  final String? errorCode;
  final String? message;

  bool get isInsufficientPoints =>
      errorCode == 'insufficient_kakao_point' ||
      errorCode == 'insufficient_points';

  factory KakaoAlimtalkSendResult.success({
    required String logId,
    required int remainingPoints,
  }) {
    return KakaoAlimtalkSendResult(
      ok: true,
      logId: logId,
      remainingPoints: remainingPoints,
    );
  }

  factory KakaoAlimtalkSendResult.fail({
    required String errorCode,
    String? message,
    int? remainingPoints,
  }) {
    return KakaoAlimtalkSendResult(
      ok: false,
      errorCode: errorCode,
      message: message,
      remainingPoints: remainingPoints,
    );
  }
}

/// 로그인 없이 여는 B2C 케어 리포트 스냅샷.
class PublicCareReport {
  const PublicCareReport({
    required this.chart,
    required this.shop,
    this.customerDisplayName,
  });

  final CustomerChart chart;
  final Shop shop;
  final String? customerDisplayName;
}
