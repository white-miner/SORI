import '../models/customer_chart.dart';

/// 회차 단위 사진 슬롯 (chart_records before/after + visit_number SSOT).
class VisitPhotoSlot {
  const VisitPhotoSlot({
    required this.chartId,
    required this.visitNumber,
    required this.kind,
    required this.url,
    required this.careName,
  });

  final String chartId;
  final int visitNumber;
  final String kind; // before | after
  final String url;
  final String careName;

  String get key => '$chartId|$kind';

  String get label {
    final care = careName.trim().isEmpty ? '' : ' · $careName';
    final side = kind == 'before' ? 'Before' : 'After';
    return '$visitNumber회차 $side$care';
  }

  String get shortLabel => '$visitNumber회차 · ${kind == 'before' ? 'B' : 'A'}';
}

List<VisitPhotoSlot> buildVisitPhotoSlots(List<CustomerChart> charts) {
  final slots = <VisitPhotoSlot>[];
  final sorted = List<CustomerChart>.from(charts)
    ..sort((a, b) => a.visitNumber.compareTo(b.visitNumber));
  for (final chart in sorted) {
    final before = chart.beforeImageUrl?.trim();
    final after = chart.afterImageUrl?.trim();
    if (before != null && before.isNotEmpty) {
      slots.add(
        VisitPhotoSlot(
          chartId: chart.id,
          visitNumber: chart.visitNumber,
          kind: 'before',
          url: before,
          careName: chart.careName,
        ),
      );
    }
    if (after != null && after.isNotEmpty) {
      slots.add(
        VisitPhotoSlot(
          chartId: chart.id,
          visitNumber: chart.visitNumber,
          kind: 'after',
          url: after,
          careName: chart.careName,
        ),
      );
    }
  }
  return slots;
}
