import '../models/customer_chart.dart';
import 'consent_publish_gate.dart';

/// 관리 기록 / 사진 저장 / B/A / 외부 발행을 분리한다.
abstract final class ConsentRecordGate {
  static bool allowsManagementRecord(CustomerChart chart) =>
      chart.consentMandatory || chart.isConsentSigned;

  static bool allowsPhotoStorage(CustomerChart chart) =>
      allowsManagementRecord(chart) && chart.consentPhoto;

  static bool allowsBaCompare(CustomerChart chart) => allowsPhotoStorage(chart);

  static bool allowsExternalPublish(CustomerChart chart) =>
      canPublishBa(chart).allowsPublish;

  /// 서명 이력이 있으나 사진·마케팅이 모두 꺼진 철회.
  static bool isWithdrawn(CustomerChart chart) =>
      chart.isConsentSigned && !chart.consentPhoto && !chart.consentMarketing;

  static bool blocksExternalAfterWithdraw(CustomerChart chart) =>
      isWithdrawn(chart) || !allowsExternalPublish(chart);
}
