import '../models/customer_chart.dart';

/// 고객 파일철 전자 동의서 — 읽기 전용 조회.
/// Chart row를 바꾸지 않는다. visit_number로 최신을 가리지 않는다.
abstract final class CustomerConsentArchive {
  static const validDays = 365;

  /// 서명(signature_url 또는 consent_pdf_url)이 있는 현재 고객 Chart만.
  /// 정렬: created_at DESC, tie-breaker id DESC.
  /// customer_id가 비어 있는 Chart는 제외한다.
  static List<CustomerChart> historyForCustomer({
    required String customerId,
    required Iterable<CustomerChart> charts,
  }) {
    final id = customerId.trim();
    if (id.isEmpty) return const [];
    final signed = charts.where((c) {
      if (c.customerId.trim() != id) return false;
      return c.isConsentSigned;
    }).toList(growable: true);
    signed.sort(_byCreatedAtThenIdDesc);
    return signed;
  }

  static CustomerConsentSnapshot snapshot({
    required String customerId,
    required Iterable<CustomerChart> charts,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final history = historyForCustomer(customerId: customerId, charts: charts);
    return CustomerConsentSnapshot(history: history, now: clock);
  }

  static DateTime? expiresAt(CustomerChart chart) {
    final created = chart.createdAt;
    if (created == null) return null;
    return created.add(const Duration(days: validDays));
  }

  static bool isCurrentlyValid(CustomerChart chart, {DateTime? now}) {
    final until = expiresAt(chart);
    if (until == null) return false;
    return !until.isBefore(now ?? DateTime.now());
  }

  static bool hasStoredPdf(CustomerChart chart) =>
      (chart.consentPdfUrl ?? '').trim().isNotEmpty;

  static int _byCreatedAtThenIdDesc(CustomerChart a, CustomerChart b) {
    final ac = a.createdAt;
    final bc = b.createdAt;
    if (ac == null && bc == null) {
      return b.id.compareTo(a.id);
    }
    if (ac == null) return 1;
    if (bc == null) return -1;
    final byDate = bc.compareTo(ac);
    if (byDate != 0) return byDate;
    return b.id.compareTo(a.id);
  }
}

class CustomerConsentSnapshot {
  const CustomerConsentSnapshot({
    required this.history,
    required this.now,
  });

  final List<CustomerChart> history;
  final DateTime now;

  int get historyCount => history.length;

  CustomerChart? get latest => history.isEmpty ? null : history.first;

  CustomerChart? get latestValid {
    for (final chart in history) {
      if (CustomerConsentArchive.isCurrentlyValid(chart, now: now)) {
        return chart;
      }
    }
    return null;
  }

  bool get hasAny => history.isNotEmpty;

  bool get hasValid => latestValid != null;

  /// 파일철 고정 항목용. DB에 저장하지 않는 읽기 값.
  String get statusLabel {
    if (!hasAny) return '동의 없음';
    if (hasValid) return '유효';
    return '만료 또는 재동의 필요';
  }

  String get countLabel => '동의 이력 $historyCount건';
}
