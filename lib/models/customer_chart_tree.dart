/// CRM 차트 트리 — **[1명의 고객 = 고유한 1개의 차트]**, 그 하위에 N회차 서비스.
///
/// 저장소에는 회차별 기록이 개별 row로 쌓인다. 동의서 체결과 시술 기록이
/// 각각 저장되거나 같은 회차를 다시 저장하면 같은 `visitNumber`를 가진 row가
/// 여러 개 생기는데, 이를 그대로 나열하면 "1회차"가 무한 증식하는 것처럼 보인다.
/// 이 파일은 그 평면 목록을 고객 1건 → 회차 N건 → 기록 M건의 트리로 접는다.
library;

import 'customer_chart.dart';

/// 회차 안의 개별 기록. 완전히 같은 내용이 반복 저장된 경우 하나로 접힌다.
class ChartRecordNode {
  const ChartRecordNode({
    required this.chart,
    required this.duplicateCount,
  });

  final CustomerChart chart;

  /// 이 노드로 접힌 동일 기록의 개수 (1이면 중복 없음).
  final int duplicateCount;

  bool get hasDuplicates => duplicateCount > 1;
}

/// 하나의 회차. 표시용 대표 기록 하나와, 그 회차에 속한 나머지 기록들.
class VisitRoundNode {
  const VisitRoundNode({
    required this.visitNumber,
    required this.records,
  });

  final int visitNumber;

  /// 대표 기록이 항상 첫 번째. 정보가 가장 풍부한 기록이 대표가 된다.
  final List<ChartRecordNode> records;

  ChartRecordNode get primary => records.first;

  /// 접힌 중복까지 포함한 원본 row 수.
  int get rawRecordCount =>
      records.fold(0, (sum, r) => sum + r.duplicateCount);

  /// 펼쳐 보여줄 하위 기록이 있는지 (서로 다른 시술이 같은 회차에 있는 경우).
  bool get hasBranches => records.length > 1;

  DateTime? get visitedAt => chartAnchorDate(primary.chart);

  bool get hasAnyPhoto => records.any(
        (r) => r.chart.hasBeforeImage || r.chart.hasAfterImage,
      );

  bool get isComplete => records.any(
        (r) => r.chart.hasBeforeImage && r.chart.hasAfterImage,
      );
}

/// 고객 1명의 차트철 전체.
class CustomerChartFile {
  const CustomerChartFile({
    required this.customerId,
    required this.chartCode,
    required this.rounds,
  });

  final String customerId;

  /// 고객당 고정되는 표시용 차트 번호.
  final String chartCode;

  /// 최신 회차가 앞.
  final List<VisitRoundNode> rounds;

  bool get isEmpty => rounds.isEmpty;

  /// 실제로 존재하는 회차 수 (중복 row가 아니라 고유 회차 기준).
  int get totalRounds => rounds.length;

  int get latestVisitNumber => rounds.isEmpty ? 0 : rounds.first.visitNumber;

  DateTime? get lastVisitedAt {
    for (final round in rounds) {
      final at = round.visitedAt;
      if (at != null) return at;
    }
    return null;
  }

  /// 그룹핑으로 화면에서 사라진 중복 row 수. 0이면 원본이 이미 깨끗하다는 뜻.
  int get collapsedDuplicateCount {
    var raw = 0;
    for (final round in rounds) {
      raw += round.rawRecordCount;
    }
    return raw - rounds.fold(0, (sum, r) => sum + r.records.length);
  }

  /// 평면 차트 목록을 트리로 접는다.
  ///
  /// [charts]는 한 고객의 기록이어야 한다. 회차는 내림차순, 회차 안의 기록은
  /// 정보량이 많은 순으로 정렬된다.
  factory CustomerChartFile.from({
    required String customerId,
    required List<CustomerChart> charts,
  }) {
    final byVisit = <int, List<CustomerChart>>{};
    for (final chart in charts) {
      byVisit.putIfAbsent(chart.visitNumber, () => []).add(chart);
    }

    final rounds = <VisitRoundNode>[];
    final visitNumbers = byVisit.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final visitNumber in visitNumbers) {
      final group = byVisit[visitNumber]!;

      // 같은 내용이 반복 저장된 row를 하나로 접는다.
      final folded = <String, List<CustomerChart>>{};
      for (final chart in group) {
        folded.putIfAbsent(_dedupeKey(chart), () => []).add(chart);
      }

      final records = folded.values.map((sameContent) {
        final sorted = List<CustomerChart>.from(sameContent)
          ..sort(_byInformationDensity);
        return ChartRecordNode(
          chart: sorted.first,
          duplicateCount: sorted.length,
        );
      }).toList()
        ..sort((a, b) => _byInformationDensity(a.chart, b.chart));

      rounds.add(
        VisitRoundNode(visitNumber: visitNumber, records: records),
      );
    }

    return CustomerChartFile(
      customerId: customerId,
      chartCode: chartCodeFor(customerId),
      rounds: rounds,
    );
  }
}

/// 회차 기록의 기준 시각.
DateTime? chartAnchorDate(CustomerChart chart) =>
    chart.visitCheckedAt ?? chart.feedbackLineOpenedAt ?? chart.createdAt;

/// 고객당 고정 차트 번호. id에서 파생하므로 재계산해도 값이 변하지 않는다.
String chartCodeFor(String customerId) {
  final normalized =
      customerId.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toUpperCase();
  if (normalized.isEmpty) return 'C-000000';
  final tail = normalized.length <= 6
      ? normalized.padLeft(6, '0')
      : normalized.substring(normalized.length - 6);
  return 'C-$tail';
}

/// 같은 회차 안에서 "같은 기록"으로 볼 기준.
///
/// 시술명·요약·날짜가 모두 같으면 중복 저장으로 간주한다. 사진 유무는 키에
/// 넣지 않는다 — 같은 시술의 사진 있는 row와 없는 row가 따로 나열되면
/// 그것 역시 중복으로 보이기 때문이다. 대표는 정보량 순으로 뽑는다.
String _dedupeKey(CustomerChart chart) {
  final at = chartAnchorDate(chart);
  final day = at == null ? '-' : '${at.year}-${at.month}-${at.day}';
  return [
    chart.careName.trim(),
    chart.treatmentSummary.trim(),
    day,
  ].join('\u0000');
}

/// 정보가 많은 기록이 앞. B/A 완비 > 사진 일부 > 요약/인사이트 > 최신순.
int _byInformationDensity(CustomerChart a, CustomerChart b) {
  int score(CustomerChart c) {
    var s = 0;
    if (c.hasBeforeImage && c.hasAfterImage) {
      s += 8;
    } else if (c.hasBeforeImage || c.hasAfterImage) {
      s += 4;
    }
    if (c.treatmentSummary.trim().isNotEmpty) s += 2;
    if (c.directorInsight.trim().isNotEmpty) s += 1;
    if (c.homeCarePrescriptions.isNotEmpty) s += 1;
    return s;
  }

  final byScore = score(b).compareTo(score(a));
  if (byScore != 0) return byScore;

  final at = chartAnchorDate(a);
  final bt = chartAnchorDate(b);
  if (at != null && bt != null) {
    final byDate = bt.compareTo(at);
    if (byDate != 0) return byDate;
  }
  return b.id.compareTo(a.id);
}
