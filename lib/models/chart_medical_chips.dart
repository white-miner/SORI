/// 차트 메디컬 체크 칩 상수 + DB TEXT 컬럼용 병합/파싱.
class ChartMedicalChips {
  ChartMedicalChips._();

  static const String allergyNone = '없음';
  static const String skinNone = '튼튼함(해당없음)';
  static const String sideEffectNone = '없음';
  static const String otherLabel = '기타(직접 입력)';

  static const List<String> allergies = [
    allergyNone,
    '라텍스/고무',
    '금속(니켈 등)',
    '화장품 향료',
    '알코올',
    '해산물/견과류(음식)',
    '햇빛(자외선 광알레르기)',
    otherLabel,
  ];

  static const List<String> skinSensitivities = [
    skinNone,
    '홍조/붉은기',
    '얇은 피부(실핏줄)',
    '켈로이드성',
    '열감에 취약',
    '마찰/압력 민감',
    '필링/산성(AHA/BHA) 민감',
    '아토피성',
    otherLabel,
  ];

  static const List<String> sideEffectHistories = [
    sideEffectNone,
    '트러블/발진',
    '가려움/따가움',
    '색소 침착(PIH)',
    '과한 붓기',
    '화상/물집',
    '시술 후 멍',
    '건조함/각질 들뜸',
    otherLabel,
  ];

  /// 선택 칩 + 기타 입력을 `"라텍스/고무, 기타(강아지 털)"` 형태로 병합.
  static String joinSelection({
    required Set<String> selected,
    required String noneLabel,
    required String otherText,
  }) {
    if (selected.isEmpty) return '';
    if (selected.contains(noneLabel)) return noneLabel;

    final parts = <String>[];
    for (final label in selected) {
      if (label == otherLabel) {
        final custom = otherText.trim();
        parts.add(custom.isEmpty ? otherLabel : '기타($custom)');
      } else {
        parts.add(label);
      }
    }
    return parts.join(', ');
  }

  /// 저장된 문자열을 칩 선택 + 기타 입력으로 복원.
  static ({Set<String> selected, String otherText}) parseStored(
    String? raw, {
    required List<String> options,
    required String noneLabel,
  }) {
    final text = (raw ?? '').trim();
    final selected = <String>{};
    final otherParts = <String>[];
    if (text.isEmpty) {
      return (selected: selected, otherText: '');
    }

    final known = options.toSet();
    for (final part in text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      if (part == noneLabel) {
        return (selected: {noneLabel}, otherText: '');
      }
      final otherMatch = RegExp(r'^기타\((.*)\)$').firstMatch(part);
      if (otherMatch != null) {
        selected.add(otherLabel);
        final inner = otherMatch.group(1)?.trim() ?? '';
        if (inner.isNotEmpty) otherParts.add(inner);
        continue;
      }
      if (part == otherLabel || part == '기타') {
        selected.add(otherLabel);
        continue;
      }
      if (known.contains(part)) {
        selected.add(part);
      } else {
        // 구버전 자유 입력 텍스트는 기타로 복원
        selected.add(otherLabel);
        otherParts.add(part);
      }
    }
    selected.remove(noneLabel);
    return (selected: selected, otherText: otherParts.join(', '));
  }
}
