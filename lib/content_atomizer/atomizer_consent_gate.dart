import '../models/customer_chart.dart';
import '../../utils/consent_publish_gate.dart';

/// PO Phase 2: Clinical B/A & Mentoring = photo + marketing consent required.
bool allowsPhotoMarketingContent(CustomerChart chart) {
  if (!chart.isConsentSigned) return false;
  if (!chart.consentPhoto) return false;
  return canPublishBa(chart).allowsPublish;
}

String photoContentDropReason(CustomerChart chart) {
  if (!chart.isConsentSigned) return '전자 동의서 서명 필요';
  if (!chart.consentPhoto) return '사진 활용 동의 필요';
  final gate = canPublishBa(chart);
  if (!gate.allowsPublish) return gate.alertMessage;
  return '';
}
