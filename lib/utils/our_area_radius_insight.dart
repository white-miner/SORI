import 'our_area_category.dart';

class OurAreaCategoryShare {
  const OurAreaCategoryShare({
    required this.key,
    required this.label,
    required this.count,
  });

  final String key;
  final String label;
  final int count;
}

/// 현재 반경 결과만으로 만드는 상권 판단. 매출·추정 없음.
class OurAreaRadiusInsight {
  const OurAreaRadiusInsight({
    required this.total,
    required this.mix,
  });

  final int total;
  final List<OurAreaCategoryShare> mix;

  static const empty = OurAreaRadiusInsight(total: 0, mix: []);

  bool get isEmpty => total <= 0;
  OurAreaCategoryShare? get top => mix.isEmpty ? null : mix.first;

  static OurAreaRadiusInsight fromMappedKeys(Iterable<String> keys) {
    final counts = <String, int>{};
    for (final raw in keys) {
      final key = OurAreaCategory.mapRaw(raw);
      if (key == OurAreaCategory.all) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final mix = [
      for (final e in counts.entries)
        OurAreaCategoryShare(
          key: e.key,
          label: OurAreaCategory.labelOf(e.key),
          count: e.value,
        ),
    ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.label.compareTo(b.label);
      });
    var total = 0;
    for (final row in mix) {
      total += row.count;
    }
    return OurAreaRadiusInsight(total: total, mix: mix);
  }
}
