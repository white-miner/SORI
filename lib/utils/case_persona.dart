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
    final skin = skinTypeLabel(chart);
    for (final raw in chart.careTags) {
      var t = raw.replaceFirst('#', '').trim();
      if (t.isEmpty) continue;
      if (skin != null && (t == skin || t.contains(skin))) continue;
      if (t.endsWith('고민')) return t;
      final head = t.split(RegExp(r'[/,]')).first.trim();
      if (head.isEmpty) continue;
      if (skin != null && head.contains(skin)) continue;
      return '$head 고민';
    }
    return null;
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
}
