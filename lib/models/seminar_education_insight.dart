/// 원장 마이페이지 — 교육 수요 인사이트.
class SeminarEducationInsight {
  const SeminarEducationInsight({
    required this.totalRequests,
    required this.requestsByCase,
    this.soriCashBalance = 0,
    this.tierBadgeLabel = '',
  });

  final int totalRequests;
  final Map<String, int> requestsByCase;
  final int soriCashBalance;
  final String tierBadgeLabel;

  int requestsForCase(String caseId) => requestsByCase[caseId.trim()] ?? 0;
}
