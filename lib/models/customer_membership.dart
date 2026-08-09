import '../utils/db_map.dart';

/// 고객이 보유한 개별 회원권(서비스 단위).
class CustomerMembership {
  const CustomerMembership({
    required this.id,
    required this.serviceName,
    required this.totalVisits,
    this.usedVisits = 0,
  });

  final String id;
  final String serviceName;
  final int totalVisits;
  final int usedVisits;

  int get remainingVisits =>
      (totalVisits - usedVisits).clamp(0, 999);

  bool get isActive => totalVisits > 0 && remainingVisits > 0;

  bool get isLow => isActive && remainingVisits <= 2;

  CustomerMembership copyWith({
    String? id,
    String? serviceName,
    int? totalVisits,
    int? usedVisits,
  }) {
    return CustomerMembership(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      totalVisits: totalVisits ?? this.totalVisits,
      usedVisits: usedVisits ?? this.usedVisits,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'service_name': serviceName,
        'total_visits': totalVisits,
        'used_visits': usedVisits,
      };

  factory CustomerMembership.fromJson(Map<String, dynamic> map) {
    return CustomerMembership(
      id: DbMap.asText(map['id'], 'm-${DateTime.now().millisecondsSinceEpoch}'),
      serviceName: DbMap.asText(map['service_name']),
      totalVisits: DbMap.asInt(map['total_visits']),
      usedVisits: DbMap.asInt(map['used_visits']),
    );
  }

  /// 오늘 진행 서비스명과 회원권 서비스명 매칭 (공백·회권 표기 무시).
  static bool matchesService(String membershipName, String careName) {
    final a = _normalize(membershipName);
    final b = _normalize(careName);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || a.contains(b) || b.contains(a);
  }

  static String _normalize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('회권', '')
        .trim();
  }
}
