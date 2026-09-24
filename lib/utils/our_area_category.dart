/// 우리 지역 업종 표준 키. public 원문 문자열을 이 값으로만 줄인다.
abstract final class OurAreaCategory {
  static const all = 'all';
  static const hair = 'hair';
  static const barber = 'barber';
  static const nail = 'nail';
  static const skin = 'skin';
  static const tattoo = 'tattoo';
  static const permanent = 'permanent';
  static const makeup = 'makeup';
  static const other = 'other';

  /// 지도 위 업종 칩. 반영구는 원문에 있을 때만 걸리고, 기타는 매핑되지 않은 업소다.
  static const selectableKeys = <String>[
    all,
    hair,
    skin,
    nail,
    tattoo,
    barber,
    permanent,
    other,
  ];

  static const labels = <String, String>{
    all: '전체',
    hair: '헤어',
    barber: '바버',
    nail: '네일',
    skin: '피부',
    tattoo: '타투',
    permanent: '반영구',
    makeup: '메이크업',
    other: '기타 뷰티',
  };

  static String labelOf(String key) => labels[key] ?? labels[other]!;

  /// 칩에 보이는 짧은 이름. 데이터 라벨 `기타 뷰티`는 유지한다.
  static String chipLabel(String key) => key == other ? '기타' : labelOf(key);

  static String mapRaw(String? raw) {
    final blob = (raw ?? '').trim().toLowerCase();
    if (blob.isEmpty) return other;
    if (blob == all || blob == '전체') return all;
    if (labels.containsKey(blob)) return blob;
    if (RegExp(r'네일|손톱|nail').hasMatch(blob)) return nail;
    if (RegExp(r'바버|이발|이용|barber').hasMatch(blob)) return barber;
    if (RegExp(r'반영구').hasMatch(blob)) return permanent;
    if (RegExp(r'타투|문신|tattoo').hasMatch(blob)) return tattoo;
    if (RegExp(r'메이크업|makeup').hasMatch(blob)) return makeup;
    if (RegExp(r'피부|에스테틱|마사지|체형|왁싱|skin').hasMatch(blob)) {
      return skin;
    }
    if (RegExp(r'미용|헤어|두발|hair').hasMatch(blob)) return hair;
    return other;
  }

  /// 특정 업종을 고르면 매핑 실패(`other`)는 조용히 제외한다.
  static bool matches({
    required String selected,
    required String chipKey,
    String categoryLabel = '',
  }) {
    final want = mapRaw(selected);
    if (want == all) return true;
    var got = mapRaw(chipKey);
    if (got == other) got = mapRaw(categoryLabel);
    if (want == other) return got == other;
    if (got == other) return false;
    return got == want;
  }
}
