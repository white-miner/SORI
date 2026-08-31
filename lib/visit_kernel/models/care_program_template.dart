import '../../utils/db_map.dart';

/// PRD v4.5 — one step in a care program preset (1–5 per template).
class CareProgramStep {
  const CareProgramStep({required this.label, required this.minutes});

  final String label;
  final int minutes;

  int get seconds => minutes * 60;

  Map<String, dynamic> toJson() => {'label': label, 'minutes': minutes};

  factory CareProgramStep.fromJson(Map<String, dynamic> json) {
    return CareProgramStep(
      label: DbMap.asText(json['label']),
      minutes: DbMap.asInt(json['minutes'], 5).clamp(1, 180),
    );
  }
}

/// PRD v4.5 — shop preset slot (0–4).
class CareProgramTemplate {
  const CareProgramTemplate({
    required this.id,
    required this.shopId,
    required this.slotIndex,
    required this.name,
    required this.steps,
    this.updatedAt,
  });

  final String id;
  final String shopId;
  final int slotIndex;
  final String name;
  final List<CareProgramStep> steps;
  final DateTime? updatedAt;

  bool get isEmpty => name.trim().isEmpty && steps.isEmpty;

  CareProgramTemplate copyWith({
    String? id,
    String? shopId,
    int? slotIndex,
    String? name,
    List<CareProgramStep>? steps,
    DateTime? updatedAt,
  }) {
    return CareProgramTemplate(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      slotIndex: slotIndex ?? this.slotIndex,
      name: name ?? this.name,
      steps: steps ?? this.steps,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CareProgramTemplate.empty({
    required String shopId,
    required int slotIndex,
  }) {
    return CareProgramTemplate(
      id: '',
      shopId: shopId,
      slotIndex: slotIndex,
      name: '',
      steps: const [],
    );
  }

  Map<String, dynamic> toMap() => {
        if (id.isNotEmpty) 'id': id,
        'shop_id': shopId,
        'slot_index': slotIndex,
        'name': name,
        'steps': steps.map((s) => s.toJson()).toList(),
        'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      };

  factory CareProgramTemplate.fromMap(Map<String, dynamic> map) {
    final rawSteps = map['steps'];
    final steps = <CareProgramStep>[];
    if (rawSteps is List) {
      for (final item in rawSteps) {
        if (item is Map) {
          steps.add(
            CareProgramStep.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return CareProgramTemplate(
      id: DbMap.asText(map['id']),
      shopId: DbMap.asText(map['shop_id']),
      slotIndex: DbMap.asInt(map['slot_index'], 0).clamp(0, 4),
      name: DbMap.asText(map['name']),
      steps: steps,
      updatedAt: DbMap.asDateTime(map['updated_at']),
    );
  }
}
