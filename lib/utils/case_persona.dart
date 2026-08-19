import '../models/customer.dart';
import '../models/customer_chart.dart';

/// 피드/타일용 익명 페르소나 한 줄 (이름·연락처 제외).
abstract final class CasePersona {
  static const skinTypes = ['수부지', '건성', '지성', '복합성', '민감', '중성'];

  static String? skinTypeLabel(CustomerChart chart) {
    final fromChart = chart.skinSensitivity.trim();
    if (fromChart.isNotEmpty) {
      for (final t in skinTypes) {
        if (fromChart.contains(t)) return t;
      }
      return fromChart;
    }
    for (final chip in chart.careTags) {
      for (final t in skinTypes) {
        if (chip.contains(t)) return t;
      }
    }
    return null;
  }

  static String? concernLabel(CustomerChart chart) {
    final parts = <String>[];
    for (final raw in chart.careTags) {
      final t = raw.replaceFirst('#', '').trim();
      if (t.isEmpty) continue;
      if (skinTypes.contains(t)) continue;
      parts.add(t);
    }
    if (parts.isEmpty) return null;
    final joined = parts.join('/');
    return joined.endsWith('고민') ? joined : '$joined 고민';
  }

  static String line({
    required CustomerChart chart,
    int? age,
    String? genderLabel,
    Customer? customer,
  }) {
    final resolvedAge = age ?? customer?.koreanAge;
    final resolvedGender =
        (genderLabel != null && genderLabel.trim().isNotEmpty)
            ? genderLabel.trim()
            : customer?.gender?.label;
    final skin = skinTypeLabel(chart);
    final concern = concernLabel(chart);
    return [
      if (resolvedAge != null) '만 $resolvedAge세',
      if (resolvedGender != null && resolvedGender.isNotEmpty) resolvedGender,
      ?skin,
      ?concern,
    ].join(' · ');
  }

  /// 보관함/홈/탐색 공통 메타 한 줄.
  static String feedLine({
    required CustomerChart chart,
    int? age,
    String? genderLabel,
    Customer? customer,
  }) =>
      line(
        chart: chart,
        age: age ?? chart.age,
        genderLabel: genderLabel ?? chart.gender,
        customer: customer,
      );
}
