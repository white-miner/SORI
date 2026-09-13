import 'dart:convert';

/// 오프라인 입력 큐. idempotency key로 중복 전송을 막는다.
class MarketSyncItem {
  const MarketSyncItem({
    required this.idempotencyKey,
    required this.kind,
    required this.payload,
    required this.updatedAt,
  });

  final String idempotencyKey;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'idempotencyKey': idempotencyKey,
        'kind': kind,
        'payload': payload,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MarketSyncItem.fromJson(Map<String, dynamic> map) {
    return MarketSyncItem(
      idempotencyKey: '${map['idempotencyKey']}',
      kind: '${map['kind']}',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
      updatedAt: DateTime.tryParse('${map['updatedAt']}') ?? DateTime.now().toUtc(),
    );
  }
}

class MarketSyncQueue {
  final Map<String, MarketSyncItem> _items = {};

  List<MarketSyncItem> get pending => _items.values.toList(growable: false);

  void enqueue(MarketSyncItem item) {
    final existing = _items[item.idempotencyKey];
    if (existing != null && existing.updatedAt.isAfter(item.updatedAt)) {
      return;
    }
    _items[item.idempotencyKey] = item;
  }

  MarketSyncItem? takeConflictWinner(MarketSyncItem local, MarketSyncItem remote) {
    return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
  }

  void ack(String idempotencyKey) => _items.remove(idempotencyKey);

  String encode() => jsonEncode([for (final i in pending) i.toJson()]);

  void load(String raw) {
    _items.clear();
    if (raw.trim().isEmpty) return;
    final list = jsonDecode(raw);
    if (list is! List) return;
    for (final e in list) {
      if (e is Map) enqueue(MarketSyncItem.fromJson(Map<String, dynamic>.from(e)));
    }
  }
}
