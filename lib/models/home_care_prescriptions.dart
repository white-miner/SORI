/// 홈케어 처방 태그 ID ↔ 화면용 Why/How 서술형 텍스트 사전.
/// DB에는 가벼운 tag ID만 저장하고, 본문은 프론트에서만 렌더링한다.
class HomecareDictionary {
  HomecareDictionary._();

  static const Map<String, String> chipLabels = {
    'tag_gentle_cleanse': '무마찰 세안',
    'tag_moisture_pack': '수분팩 3일',
    'tag_no_exfoliation': '각질제거 금지',
    'tag_water': '물 2L 섭취',
    'tag_cream': '크림 1.5배',
    'tag_sun': '자외선 차단 필수',
    'tag_no_sauna': '사우나·찜질 금지',
    'tag_sleep': '22시 이전 취침',
    'tag_cool': '쿨링 찜질',
    'tag_no_makeup': '화장 24시간 금지',
  };

  static const Map<String, String> directives = {
    'tag_gentle_cleanse':
        '시술 직후 피부 장벽이 열려 있어요. 거품을 손끝으로 살살 굴리듯 씻고, 수건으로 문지르지 말고 톡톡 눌러 물기를 제거하세요.',
    'tag_moisture_pack':
        '수분 증발을 막기 위해 앞으로 3일간 저녁에 수분팩을 10~15분 올려 주세요. 제거 후 크림을 바로 덮어 수분을 가둡니다.',
    'tag_no_exfoliation':
        '턴오버가 아직 안정되지 않았어요. 스크럽·필링·각질패드는 최소 7일 쉬고, 당김이 있어도 억지로 벗기지 마세요.',
    'tag_water':
        '피부 속 수분 순환을 돕기 위해 하루 물 2L를 목표로 하세요. 한 번에 많이 마시기보다 1~2시간마다 한 컵씩 나눠 드세요.',
    'tag_cream':
        '피부 장벽 재건을 위해 크림을 평소보다 1.5배 듬뿍 도포하세요. 볼·입가·턱선을 손바닥 온기로 30초 눌러 흡수시킵니다.',
    'tag_sun':
        '자외선(UVA)은 유리창을 뚫고 타격을 입히므로, 실내에서도 SPF50 이상을 바르고 2~3시간마다 얇게 덧발라 주세요.',
    'tag_no_sauna':
        '열감이 염증을 키울 수 있어요. 3일간 사우나·찜질방·뜨거운 샤워는 피하고, 미지근한 물로 짧게 씻으세요.',
    'tag_sleep':
        '야간 재생 호르몬이 활발한 시간대를 쓰려면 22시 전 취침을 목표로 하세요. 취침 전 보습을 마무리하면 효과가 배가됩니다.',
    'tag_cool':
        '열감·붓기가 있을 때 깨끗하고 차갑게 적신 패드를 3~5분 올려 주세요. 얼음을 직접 피부에 대지 마세요.',
    'tag_no_makeup':
        '시술 직후 모공·장벽이 예민합니다. 24시간은 메이크업·쿠션을 쉬고, 톤업이 필요하면 선크림만 가볍게 올려 주세요.',
  };

  /// 구버전 ID / 칩 라벨 → 정규 tag ID.
  static const Map<String, String> _legacyToTag = {
    'gentle_cleanse': 'tag_gentle_cleanse',
    'moisture_pack_3d': 'tag_moisture_pack',
    'no_exfoliation': 'tag_no_exfoliation',
    'water_2l': 'tag_water',
    'cream_1_5x': 'tag_cream',
    'spf_reapply': 'tag_sun',
    'no_sauna': 'tag_no_sauna',
    'sleep_early': 'tag_sleep',
    'cool_compress': 'tag_cool',
    'no_makeup_24h': 'tag_no_makeup',
    '무마찰 세안': 'tag_gentle_cleanse',
    '수분팩 3일': 'tag_moisture_pack',
    '각질제거 금지': 'tag_no_exfoliation',
    '물 2L 섭취': 'tag_water',
    '크림 1.5배': 'tag_cream',
    '자외선 차단 필수': 'tag_sun',
    '사우나·찜질 금지': 'tag_no_sauna',
    '22시 이전 취침': 'tag_sleep',
    '쿨링 찜질': 'tag_cool',
    '화장 24시간 금지': 'tag_no_makeup',
  };

  static List<String> get allTagIds => chipLabels.keys.toList(growable: false);

  static String? chipLabelOf(String tagId) => chipLabels[canonicalize(tagId)];

  static String? directiveOf(String tagId) => directives[canonicalize(tagId)];

  /// 입력값을 정규 tag ID로 변환. 알 수 없으면 null.
  static String? canonicalize(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (directives.containsKey(t)) return t;
    return _legacyToTag[t];
  }

  /// DB 저장용 — 알려진 tag ID만 남긴다 (본문 텍스트 차단).
  static List<String> sanitizeTagIds(Iterable<String>? values) {
    if (values == null) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final id = canonicalize(raw);
      if (id == null || !seen.add(id)) continue;
      out.add(id);
    }
    return out;
  }

  /// 태그 ID 목록 → 화면용 서술형 문장.
  static List<String> resolveDirectives(List<String> tags) {
    final out = <String>[];
    for (final raw in tags) {
      final text = directiveOf(raw);
      if (text != null) out.add(text);
    }
    return out;
  }
}

/// @deprecated Use [HomecareDictionary].
class HomeCarePrescription {
  const HomeCarePrescription({
    required this.id,
    required this.chipLabel,
    required this.directive,
  });

  final String id;
  final String chipLabel;
  final String directive;
}

/// @deprecated Use [HomecareDictionary].
class HomeCarePrescriptionCatalog {
  HomeCarePrescriptionCatalog._();

  static List<HomeCarePrescription> get all => HomecareDictionary.allTagIds
      .map(
        (id) => HomeCarePrescription(
          id: id,
          chipLabel: HomecareDictionary.chipLabels[id]!,
          directive: HomecareDictionary.directives[id]!,
        ),
      )
      .toList(growable: false);

  static HomeCarePrescription? byId(String id) {
    final tag = HomecareDictionary.canonicalize(id);
    if (tag == null) return null;
    return HomeCarePrescription(
      id: tag,
      chipLabel: HomecareDictionary.chipLabels[tag]!,
      directive: HomecareDictionary.directives[tag]!,
    );
  }

  static HomeCarePrescription? byChipLabel(String label) => byId(label);

  static List<String> directivesFor(List<String> tags) =>
      HomecareDictionary.resolveDirectives(tags);
}
