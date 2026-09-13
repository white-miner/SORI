/// 개인정보·키·주소 원문을 넣지 않는 우리지역 이벤트.
class MarketAnalytics {
  MarketAnalytics._();
  static final List<Map<String, Object?>> _events = [];

  static List<Map<String, Object?>> get events =>
      List.unmodifiable(_events);

  static void reset() => _events.clear();

  static void track(String name, [Map<String, Object?> props = const {}]) {
    final safe = <String, Object?>{};
    for (final e in props.entries) {
      if (_blockedKey(e.key) || _blockedValue(e.value)) continue;
      safe[e.key] = e.value;
    }
    _events.add({'name': name, ...safe});
  }

  static bool _blockedKey(String key) {
    final k = key.toLowerCase();
    return k.contains('key') ||
        k.contains('secret') ||
        k.contains('token') ||
        k.contains('address') ||
        k.contains('name') ||
        k.contains('phone') ||
        k.contains('url') ||
        k.contains('photo');
  }

  static bool _blockedValue(Object? value) {
    final s = '$value'.toLowerCase();
    if (s.length > 80) return true;
    return s.contains('servicekey') ||
        s.contains('sk-') ||
        s.contains('eyj') ||
        s.contains('http');
  }
}
