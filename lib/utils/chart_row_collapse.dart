import '../models/customer_chart.dart';
import 'customer_consent_archive.dart';

/// 이미 쌓인 차트 행을 합치거나 빼는 계획.
/// 시술·사진이 있는 행은 남기고, 동의서만 있는 1년 안 중복만 뺀다.
abstract final class ChartRowCollapse {
  static const consentSummary = '고객 정보 및 관리 동의서 체결';

  static bool isConsentShell(CustomerChart chart) {
    if (!chart.isConsentSigned) return false;
    if ((chart.beforeImageUrl ?? '').trim().isNotEmpty) return false;
    if ((chart.afterImageUrl ?? '').trim().isNotEmpty) return false;
    if (chart.treatmentSummary.trim() != consentSummary) return false;
    final record = chart.visitRecord;
    if (record.concerns.isNotEmpty || record.careGoals.isNotEmpty) return false;
    if (record.desiredChange.trim().isNotEmpty) return false;
    if (record.scores.isNotEmpty) return false;
    return true;
  }

  static ChartCollapsePlan plan(
    Iterable<CustomerChart> charts, {
    Set<String> protectedIds = const {},
  }) {
    final merged = <CustomerChart>[];
    final dropIds = <String>[];
    final repoint = <String, String>{};

    final byCustomer = <String, List<CustomerChart>>{};
    for (final chart in charts) {
      final customerId = chart.customerId.trim();
      if (customerId.isEmpty) continue;
      byCustomer.putIfAbsent(customerId, () => []).add(chart);
    }

    for (final group in byCustomer.values) {
      final shells = group.where(isConsentShell).toList();
      final keepShellIds = _keepOnePerYear(shells);
      final extraShellIds = shells
          .map((chart) => chart.id)
          .where((id) => !keepShellIds.contains(id))
          .toSet();

      final byVisit = <int, List<CustomerChart>>{};
      for (final chart in group) {
        byVisit.putIfAbsent(chart.visitNumber, () => []).add(chart);
      }

      for (final visit in byVisit.values) {
        if (visit.length == 1) {
          final only = visit.single;
          if (extraShellIds.contains(only.id) &&
              !protectedIds.contains(only.id)) {
            dropIds.add(only.id);
          }
          continue;
        }

        final ranked = [...visit]..sort(_rank);
        final survivor = ranked.firstWhere(
          (chart) => !isConsentShell(chart),
          orElse: () => ranked.first,
        );
        final filled = _fillFrom(survivor, visit);
        if (_changed(survivor, filled)) merged.add(filled);

        for (final other in visit) {
          if (other.id == survivor.id) continue;
          if (protectedIds.contains(other.id)) continue;
          dropIds.add(other.id);
          repoint[other.id] = survivor.id;
        }
      }
    }

    return ChartCollapsePlan(
      merged: merged,
      dropIds: dropIds,
      repoint: repoint,
    );
  }

  static Set<String> _keepOnePerYear(List<CustomerChart> shells) {
    final sorted = [...shells]..sort(_newerFirst);
    final kept = <CustomerChart>[];
    for (final shell in sorted) {
      final covered = kept.any((chart) => _sameConsentYear(chart, shell));
      if (!covered) kept.add(shell);
    }
    return kept.map((chart) => chart.id).toSet();
  }

  static bool _sameConsentYear(CustomerChart newer, CustomerChart older) {
    final a = newer.createdAt;
    final b = older.createdAt;
    if (a == null || b == null) return true;
    final days = a.difference(b).inDays.abs();
    return days <= CustomerConsentArchive.validDays;
  }

  static CustomerChart _fillFrom(
    CustomerChart survivor,
    List<CustomerChart> group,
  ) {
    var next = survivor;
    for (final other in group) {
      if (other.id == survivor.id) continue;
      final before = (next.beforeImageUrl ?? '').trim().isEmpty
          ? other.beforeImageUrl
          : next.beforeImageUrl;
      final after = (next.afterImageUrl ?? '').trim().isEmpty
          ? other.afterImageUrl
          : next.afterImageUrl;
      final signature = (next.signatureUrl ?? '').trim().isEmpty
          ? other.signatureUrl
          : next.signatureUrl;
      final pdf = (next.consentPdfUrl ?? '').trim().isEmpty
          ? other.consentPdfUrl
          : next.consentPdfUrl;
      final takeConsent = (next.signatureUrl ?? '').trim().isEmpty &&
          (other.signatureUrl ?? '').trim().isNotEmpty;
      next = next.copyWith(
        beforeImageUrl: before,
        afterImageUrl: after,
        signatureUrl: signature,
        consentPdfUrl: pdf,
        careName: next.careName.trim().isEmpty ? other.careName : next.careName,
        treatmentSummary: next.treatmentSummary.trim().isEmpty
            ? other.treatmentSummary
            : next.treatmentSummary,
        directorInsight: next.directorInsight.trim().isEmpty
            ? other.directorInsight
            : next.directorInsight,
        concernChips:
            next.concernChips.isEmpty ? other.concernChips : next.concernChips,
        consentMandatory: takeConsent
            ? other.consentMandatory
            : next.consentMandatory,
        consentPhoto: takeConsent ? other.consentPhoto : next.consentPhoto,
        consentMarketing:
            takeConsent ? other.consentMarketing : next.consentMarketing,
        consentOfflineOnly:
            takeConsent ? other.consentOfflineOnly : next.consentOfflineOnly,
      );
    }
    return next;
  }

  static bool _changed(CustomerChart before, CustomerChart after) {
    return before.beforeImageUrl != after.beforeImageUrl ||
        before.afterImageUrl != after.afterImageUrl ||
        before.signatureUrl != after.signatureUrl ||
        before.consentPdfUrl != after.consentPdfUrl ||
        before.careName != after.careName ||
        before.treatmentSummary != after.treatmentSummary ||
        before.directorInsight != after.directorInsight ||
        before.consentMandatory != after.consentMandatory ||
        before.consentPhoto != after.consentPhoto;
  }

  static int _rank(CustomerChart a, CustomerChart b) {
    final byScore = _score(b).compareTo(_score(a));
    if (byScore != 0) return byScore;
    return _newerFirst(a, b);
  }

  static int _score(CustomerChart chart) {
    var score = 0;
    if ((chart.beforeImageUrl ?? '').trim().isNotEmpty) score += 8;
    if ((chart.afterImageUrl ?? '').trim().isNotEmpty) score += 8;
    if (!isConsentShell(chart) && chart.treatmentSummary.trim().isNotEmpty) {
      score += 4;
    }
    if (chart.careName.trim().isNotEmpty && !isConsentShell(chart)) score += 2;
    if (chart.visitRecord.concerns.isNotEmpty ||
        chart.visitRecord.careGoals.isNotEmpty) {
      score += 4;
    }
    if (chart.isConsentSigned) score += 1;
    return score;
  }

  static int _newerFirst(CustomerChart a, CustomerChart b) {
    final ac = a.createdAt;
    final bc = b.createdAt;
    if (ac == null && bc == null) return b.id.compareTo(a.id);
    if (ac == null) return 1;
    if (bc == null) return -1;
    final byDate = bc.compareTo(ac);
    if (byDate != 0) return byDate;
    return b.id.compareTo(a.id);
  }
}

class ChartCollapsePlan {
  const ChartCollapsePlan({
    required this.merged,
    required this.dropIds,
    required this.repoint,
  });

  final List<CustomerChart> merged;
  final List<String> dropIds;
  final Map<String, String> repoint;

  bool get hasWork => dropIds.isNotEmpty || merged.isNotEmpty;
}
