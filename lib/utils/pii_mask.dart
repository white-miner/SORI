/// 공개 피드용 고객 실명 마스킹.
abstract final class PiiMask {
  static const _keepHonorifics = {
    '고객님',
    '원장님',
    '선생님',
    '사장님',
    '실장님',
    '부장님',
    '이사님',
  };

  /// `박종환님` → `박**님`. 이미 익명인 `고객님` 등은 유지.
  static String customerNames(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return text;
    return text.replaceAllMapped(RegExp(r'([가-힣]{2,5})님'), (m) {
      final full = m.group(0)!;
      if (_keepHonorifics.contains(full)) return full;
      final name = m.group(1)!;
      if (name.length <= 1) return '고객님';
      return '${name[0]}${'*' * (name.length - 1)}님';
    });
  }
}
