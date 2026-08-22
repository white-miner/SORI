import 'package:flutter/material.dart';

/// 샵 영업시간 — 운영 요일(월=1…일=7) + 공통 오픈/마감.
class ShopBusinessHours {
  const ShopBusinessHours({
    this.openDays = const {1, 2, 3, 4, 5},
    this.openHour = 10,
    this.openMinute = 0,
    this.closeHour = 20,
    this.closeMinute = 0,
  });

  /// 1=월 … 7=일
  final Set<int> openDays;
  final int openHour;
  final int openMinute;
  final int closeHour;
  final int closeMinute;

  static const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  static String dayLabel(int day) {
    if (day < 1 || day > 7) return '?';
    return dayLabels[day - 1];
  }

  TimeOfDay get openTimeOfDay =>
      TimeOfDay(hour: openHour.clamp(0, 23), minute: openMinute.clamp(0, 59));

  TimeOfDay get closeTimeOfDay =>
      TimeOfDay(hour: closeHour.clamp(0, 23), minute: closeMinute.clamp(0, 59));

  String get openTimeLabel => _fmt(openHour, openMinute);
  String get closeTimeLabel => _fmt(closeHour, closeMinute);

  static String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Set<int> get closedDays =>
      {1, 2, 3, 4, 5, 6, 7}.difference(openDays.map(_normDay).toSet());

  static int _normDay(int d) => d.clamp(1, 7);

  ShopBusinessHours copyWith({
    Set<int>? openDays,
    int? openHour,
    int? openMinute,
    int? closeHour,
    int? closeMinute,
  }) {
    return ShopBusinessHours(
      openDays: openDays ?? this.openDays,
      openHour: openHour ?? this.openHour,
      openMinute: openMinute ?? this.openMinute,
      closeHour: closeHour ?? this.closeHour,
      closeMinute: closeMinute ?? this.closeMinute,
    );
  }

  Map<String, dynamic> toJson() => {
        'open_days': openDays.map(_normDay).toList()..sort(),
        'open_time': openTimeLabel,
        'close_time': closeTimeLabel,
      };

  factory ShopBusinessHours.fromJson(dynamic raw) {
    if (raw is! Map) return const ShopBusinessHours();
    final map = Map<String, dynamic>.from(raw);
    final daysRaw = map['open_days'] ?? map['openDays'] ?? map['days'];
    final days = <int>{};
    if (daysRaw is List) {
      for (final e in daysRaw) {
        final n = e is int ? e : int.tryParse('$e');
        if (n != null && n >= 1 && n <= 7) days.add(n);
      }
    }
    final open = _parseHm(map['open_time'] ?? map['openTime']);
    final close = _parseHm(map['close_time'] ?? map['closeTime']);
    return ShopBusinessHours(
      openDays: days,
      openHour: open.$1,
      openMinute: open.$2,
      closeHour: close.$1,
      closeMinute: close.$2,
    );
  }

  static (int, int) _parseHm(dynamic v) {
    final s = (v?.toString() ?? '').trim();
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
    if (m == null) return (10, 0);
    return (
      int.parse(m.group(1)!).clamp(0, 23),
      int.parse(m.group(2)!).clamp(0, 59),
    );
  }

  bool get isEmpty => openDays.isEmpty;

  /// 예: `월-금 10:00 - 20:00 / 토, 일 휴무`
  String formatDisplay() {
    if (openDays.isEmpty) {
      return '매일 휴무';
    }
    final openPart = '${_formatDayRanges(openDays)} $openTimeLabel - $closeTimeLabel';
    final closed = closedDays;
    if (closed.isEmpty) {
      return openPart;
    }
    final closedPart = '${_joinDays(closed.toList()..sort())} 휴무';
    return '$openPart / $closedPart';
  }

  /// 연속 요일을 `월-금`, 비연속은 `월, 수, 금` 형태로.
  static String _formatDayRanges(Set<int> days) {
    final sorted = days.map(_normDay).toList()..sort();
    if (sorted.isEmpty) return '';
    final ranges = <String>[];
    var start = sorted.first;
    var prev = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final d = sorted[i];
      if (d == prev + 1) {
        prev = d;
        continue;
      }
      ranges.add(_rangeLabel(start, prev));
      start = d;
      prev = d;
    }
    ranges.add(_rangeLabel(start, prev));
    return ranges.join(', ');
  }

  static String _rangeLabel(int start, int end) {
    if (start == end) return dayLabel(start);
    if (end == start + 1) {
      return '${dayLabel(start)}, ${dayLabel(end)}';
    }
    return '${dayLabel(start)}-${dayLabel(end)}';
  }

  static String _joinDays(List<int> days) =>
      days.map(dayLabel).join(', ');
}
