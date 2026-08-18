/// 원장 마이페이지 — 교육 수요 인사이트.
class SeminarEducationInsight {
  const SeminarEducationInsight({
    required this.totalRequests,
    required this.requestsByCase,
    this.soriCashBalance = 0,
    this.tierBadgeLabel = '',
    this.totalSeminarCount = 0,
    this.totalFundingAmount = 0,
    this.totalLikes = 0,
    this.sharedCaseCount = 0,
    this.seminarRequestCount = 0,
    this.completedSeminarCount = 0,
    this.followerCount = 0,
  });

  final int totalRequests;
  final Map<String, int> requestsByCase;
  final int soriCashBalance;
  final String tierBadgeLabel;
  final int totalSeminarCount;
  final int totalFundingAmount;
  final int totalLikes;
  final int sharedCaseCount;
  final int seminarRequestCount;
  final int completedSeminarCount;
  final int followerCount;

  int requestsForCase(String caseId) => requestsByCase[caseId.trim()] ?? 0;
}
