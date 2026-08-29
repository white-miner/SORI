import 'package:intl/intl.dart';

/// PO: `12:44 ~ 15:44 (총 3시간)` style label.
String formatSeminarDurationLabel(int minutes) {
  final m = minutes.clamp(15, 720);
  final h = m ~/ 60;
  final r = m % 60;
  if (h <= 0) return '$r분';
  if (r == 0) return '$h시간';
  return '$h시간 $r분';
}

String formatSeminarTimeRange({
  required DateTime? start,
  required int durationMinutes,
}) {
  if (start == null) return '일정 미정';
  final local = start.toLocal();
  final end = local.add(Duration(minutes: durationMinutes.clamp(15, 720)));
  final startFmt = DateFormat('M월 d일 (E) HH:mm', 'ko_KR');
  final endFmt = DateFormat('HH:mm', 'ko_KR');
  final dur = formatSeminarDurationLabel(durationMinutes);
  return '${startFmt.format(local)} ~ ${endFmt.format(end)} (총 $dur)';
}
