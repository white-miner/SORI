import '../models/customer_chart.dart';

/// 시술(careName) 단위로 묶인 차트 에피소드 뷰 모델.
class CareEpisodeGroup {
  const CareEpisodeGroup({
    required this.careKey,
    required this.careLabel,
    required this.visits,
  });

  final String careKey;
  final String careLabel;

  /// visitNumber ASC, 동점이면 createdAt ASC.
  final List<CustomerChart> visits;
}

/// Flat 차트 리스트 → careName 그룹 + 회차 ASC 정규화.
List<CareEpisodeGroup> groupChartsByCareName(List<CustomerChart> charts) {
  final map = <String, List<CustomerChart>>{};
  for (final chart in charts) {
    final raw = chart.careName.trim();
    final key = raw.isEmpty ? '기타 케어' : raw;
    (map[key] ??= <CustomerChart>[]).add(chart);
  }

  for (final list in map.values) {
    list.sort((a, b) {
      final byVisit = a.visitNumber.compareTo(b.visitNumber);
      if (byVisit != 0) return byVisit;
      final ad = a.createdAt ?? a.visitCheckedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? b.visitCheckedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });
  }

  final keys = map.keys.toList()
    ..sort((a, b) {
      if (a == '기타 케어') return 1;
      if (b == '기타 케어') return -1;
      final ac = map[a]!.length;
      final bc = map[b]!.length;
      if (ac != bc) return bc.compareTo(ac);
      return a.compareTo(b);
    });

  return [
    for (final key in keys)
      CareEpisodeGroup(
        careKey: key,
        careLabel: key,
        visits: List<CustomerChart>.unmodifiable(map[key]!),
      ),
  ];
}
