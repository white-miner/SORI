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

  /// 서비스 메뉴 그룹 키. 공백을 접어 같은 시술이 흩어지지 않게 한다.
  String get programKey => normalizeCareProgramKey(careName);

  String get programLabel => careProgramLabel(careName);

  String get label {
    final care = careName.trim().isEmpty ? '' : ' · $careName';
    final side = kind == 'before' ? 'Before' : 'After';
    return '$visitNumber회차 $side$care';
  }

  String get shortLabel => '$visitNumber회차 · ${kind == 'before' ? 'B' : 'A'}';

  /// 스토리 스택 하단 라벨. 중점은 드롭다운용 [shortLabel]에 남긴다.
  String get storyLabel => '$visitNumber회차 ${kind == 'before' ? 'B' : 'A'}';
}

/// 한 고객의 서비스 메뉴(1 depth) 아래 회차 사진(2 depth).
class CareProgramGroup {
  const CareProgramGroup({
    required this.key,
    required this.label,
    required this.slots,
  });

  final String key;
  final String label;
  final List<VisitPhotoSlot> slots;
}

/// 뷰어 진입 시 왼쪽/오른쪽/프로그램의 초기값.
class CompareViewerSeed {
  const CompareViewerSeed({required this.programKey, this.left, this.right});

  final String programKey;
  final VisitPhotoSlot? left;
  final VisitPhotoSlot? right;
}

String normalizeCareProgramKey(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ');

String careProgramLabel(String raw) {
  final key = normalizeCareProgramKey(raw);
  return key.isEmpty ? '관리 케이스' : key;
}

List<VisitPhotoSlot> buildVisitPhotoSlots(List<CustomerChart> charts) {
  final slots = <VisitPhotoSlot>[];
  for (final chart in charts) {
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

int _slotOrder(VisitPhotoSlot a, VisitPhotoSlot b) {
  final byVisit = a.visitNumber.compareTo(b.visitNumber);
  if (byVisit != 0) return byVisit;
  if (a.kind != b.kind) return a.kind == 'before' ? -1 : 1;
  return a.chartId.compareTo(b.chartId);
}

/// 등장 순서를 유지한 채 서비스 메뉴로 묶고, 그룹 안은 회차순.
List<CareProgramGroup> groupVisitPhotoSlotsByProgram(
  List<VisitPhotoSlot> slots,
) {
  final order = <String>[];
  final buckets = <String, List<VisitPhotoSlot>>{};
  for (final slot in slots) {
    final key = slot.programKey;
    if (!buckets.containsKey(key)) {
      order.add(key);
      buckets[key] = [];
    }
    buckets[key]!.add(slot);
  }
  return [
    for (final key in order)
      CareProgramGroup(
        key: key,
        label: careProgramLabel(key),
        slots: (buckets[key]!..sort(_slotOrder)),
      ),
  ];
}

List<VisitPhotoSlot> slotsForProgram({
  required List<VisitPhotoSlot> slots,
  required String programKey,
}) {
  final scoped =
      slots.where((s) => s.programKey == programKey).toList(growable: true)
        ..sort(_slotOrder);
  return scoped;
}

VisitPhotoSlot? slotOf({
  required List<VisitPhotoSlot> slots,
  required String chartId,
  required String kind,
}) {
  for (final slot in slots) {
    if (slot.chartId == chartId && slot.kind == kind) return slot;
  }
  return null;
}

/// 피드에서 보던 차트를 우선하고, 없으면 해당 프로그램의 첫 B · 마지막 A.
CompareViewerSeed resolveCompareViewerSeed({
  required List<VisitPhotoSlot> slots,
  String? initialChartId,
  String? initialCareName,
}) {
  if (slots.isEmpty) {
    return CompareViewerSeed(
      programKey: normalizeCareProgramKey(initialCareName ?? ''),
    );
  }

  final chartId = initialChartId?.trim() ?? '';
  VisitPhotoSlot? hinted;
  if (chartId.isNotEmpty) {
    for (final slot in slots) {
      if (slot.chartId == chartId) {
        hinted = slot;
        break;
      }
    }
  }

  final programKey = hinted != null
      ? hinted.programKey
      : (initialCareName != null
            ? normalizeCareProgramKey(initialCareName)
            : slots.first.programKey);

  final scoped = slotsForProgram(slots: slots, programKey: programKey);
  final pool = scoped.isNotEmpty ? scoped : slots;
  final scopeKey = scoped.isNotEmpty ? programKey : pool.first.programKey;

  if (hinted != null) {
    final before = slotOf(slots: pool, chartId: chartId, kind: 'before');
    final after = slotOf(slots: pool, chartId: chartId, kind: 'after');
    return CompareViewerSeed(
      programKey: scopeKey,
      left: before ?? hinted,
      right:
          after ??
          (before != null && pool.length > 1
              ? pool.lastWhere((s) => s.key != before.key, orElse: () => before)
              : hinted),
    );
  }

  VisitPhotoSlot firstBefore = pool.first;
  for (final slot in pool) {
    if (slot.kind == 'before') {
      firstBefore = slot;
      break;
    }
  }
  VisitPhotoSlot lastAfter = pool.last;
  for (final slot in pool.reversed) {
    if (slot.kind == 'after') {
      lastAfter = slot;
      break;
    }
  }

  return CompareViewerSeed(
    programKey: scopeKey,
    left: firstBefore,
    right: lastAfter,
  );
}
