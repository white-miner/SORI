/// 한글 초성 추출·매칭 (예: 'ㅎㄱㄷ' → '홍길동').
abstract final class KoreanChoseong {
  static const List<String> _chosung = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
    'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
  ];

  static final Set<int> _chosungCodes =
      _chosung.map((e) => e.runes.first).toSet();

  /// 문자열에서 초성만 이어 붙인 결과.
  static String extract(String text) {
    final buf = StringBuffer();
    for (final code in text.runes) {
      if (code >= 0xAC00 && code <= 0xD7A3) {
        buf.write(_chosung[(code - 0xAC00) ~/ 588]);
      } else if (_chosungCodes.contains(code)) {
        buf.write(String.fromCharCode(code));
      }
    }
    return buf.toString();
  }

  /// 이름 부분 일치 또는 초성 부분 일치.
  static bool matchesName(String name, String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    final nameNorm = name.trim().toLowerCase();
    final qNorm = q.toLowerCase();
    if (nameNorm.contains(qNorm)) return true;

    final nameCho = extract(name);
    final queryCho = extract(q);
    if (queryCho.isNotEmpty && nameCho.contains(queryCho)) return true;

    // 쿼리가 이미 초성만인 경우 (공백 무시)
    final rawCho = q.replaceAll(RegExp(r'\s+'), '');
    if (rawCho.isNotEmpty &&
        rawCho.runes.every(_chosungCodes.contains) &&
        nameCho.contains(rawCho)) {
      return true;
    }
    return false;
  }
}
