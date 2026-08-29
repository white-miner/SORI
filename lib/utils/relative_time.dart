/// Relative time label (e.g. `3분 전`).
String formatRelativeTime(DateTime? at) {
  if (at == null) return '';
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}주 전';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}개월 전';
  return '${(diff.inDays / 365).floor()}년 전';
}
