import '../utils/db_map.dart';

/// 고객이 보유한 개별 회원권(서비스 단위).
class CustomerMembership {
  const CustomerMembership({
    required this.id,
    required this.serviceName,
    required this.totalVisits,
    this.usedVisits = 0,
    this.expiresAt,
    this.paidAmount = 0,
    this.perSessionValue = 0,
  });

  final String id;
  final String serviceName;
  final int totalVisits;
  final int usedVisits;
  final DateTime? expiresAt;

  /// 회원권 결제 총액(원).
  final int paidAmount;

  /// 1회당 노동 부채(원).
  final int perSessionValue;

  int get remainingVisits =>
      (totalVisits - usedVisits).clamp(0, 999);

  /// 잔여 노동 부채 = per_session_value * remaining (없으면 paid/total 추정).
  int get effectivePerSession {
    if (perSessionValue > 0) return perSessionValue;
    if (paidAmount > 0 && totalVisits > 0) {
      return (paidAmount / totalVisits).round();
    }
    return 0;
  }

  int get laborDebtWon => effectivePerSession * remainingVisits;

  bool get isActive => totalVisits > 0 && remainingVisits > 0;

  bool get isLow => isActive && remainingVisits <= 2;

  /// 잔여 비율 (0~1).
  double get remainingRatio {
    if (totalVisits <= 0) return 0;
    return (remainingVisits / totalVisits).clamp(0.0, 1.0);
  }

  CustomerMembership copyWith({
    String? id,
    String? serviceName,
    int? totalVisits,
    int? usedVisits,
    DateTime? expiresAt,
    int? paidAmount,
    int? perSessionValue,
    bool clearExpiresAt = false,
  }) {
    return CustomerMembership(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      totalVisits: totalVisits ?? this.totalVisits,
      usedVisits: usedVisits ?? this.usedVisits,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      paidAmount: paidAmount ?? this.paidAmount,
      perSessionValue: perSessionValue ?? this.perSessionValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'service_name': serviceName,
        'total_visits': totalVisits,
        'used_visits': usedVisits,
        'paid_amount': paidAmount,
        'per_session_value':
            perSessionValue > 0 ? perSessionValue : effectivePerSession,
        if (expiresAt != null)
          'expires_at':
              '${expiresAt!.year.toString().padLeft(4, '0')}-${expiresAt!.month.toString().padLeft(2, '0')}-${expiresAt!.day.toString().padLeft(2, '0')}',
      };

  factory CustomerMembership.fromJson(Map<String, dynamic> map) {
    final total = DbMap.asInt(map['total_visits']);
    final paid = DbMap.asInt(map['paid_amount']);
    var per = DbMap.asInt(map['per_session_value']);
    if (per <= 0 && paid > 0 && total > 0) {
      per = (paid / total).round();
    }
    return CustomerMembership(
      id: DbMap.asText(map['id'], 'm-${DateTime.now().millisecondsSinceEpoch}'),
      serviceName: DbMap.asText(map['service_name']),
      totalVisits: total,
      usedVisits: DbMap.asInt(map['used_visits']),
      expiresAt: DbMap.asDateTime(map['expires_at']),
      paidAmount: paid,
      perSessionValue: per,
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
