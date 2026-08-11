/// 원장 차트 칩 ↔ 고객 화면용 Why/How 서술형 처방 사전.
class HomeCarePrescription {
  const HomeCarePrescription({
    required this.id,
    required this.chipLabel,
    required this.directive,
  });

  final String id;
  final String chipLabel;

  /// 이유 + 실행 방안이 담긴 개조식 문장.
  final String directive;
}

class HomeCarePrescriptionCatalog {
  HomeCarePrescriptionCatalog._();

  static const List<HomeCarePrescription> all = [
    HomeCarePrescription(
      id: 'gentle_cleanse',
      chipLabel: '무마찰 세안',
      directive:
          '시술 직후 피부 장벽이 열려 있어요. 거품을 손끝으로 살살 굴리듯 씻고, 수건으로 문지르지 말고 톡톡 눌러 물기를 제거하세요.',
    ),
    HomeCarePrescription(
      id: 'moisture_pack_3d',
      chipLabel: '수분팩 3일',
      directive:
          '수분 증발을 막기 위해 앞으로 3일간 저녁에 수분팩을 10~15분 올려 주세요. 제거 후 크림을 바로 덮어 수분을 가둡니다.',
    ),
    HomeCarePrescription(
      id: 'no_exfoliation',
      chipLabel: '각질제거 금지',
      directive:
          '턴오버가 아직 안정되지 않았어요. 스크럽·필링·각질패드는 최소 7일 쉬고, 당김이 있어도 억지로 벗기지 마세요.',
    ),
    HomeCarePrescription(
      id: 'water_2l',
      chipLabel: '물 2L 섭취',
      directive:
          '피부 속 수분 순환을 돕기 위해 하루 물 2L를 목표로 하세요. 한 번에 많이 마시기보다 1~2시간마다 한 컵씩 나눠 드세요.',
    ),
    HomeCarePrescription(
      id: 'cream_1_5x',
      chipLabel: '크림 1.5배',
      directive:
          '피부 장벽 재건을 위해 크림을 평소보다 1.5배 듬뿍 도포하세요. 볼·입가·턱선을 손바닥 온기로 30초 눌러 흡수시킵니다.',
    ),
    HomeCarePrescription(
      id: 'spf_reapply',
      chipLabel: '자외선 차단 필수',
      directive:
          '색소·홍조 재발을 막기 위해 외출 시 SPF50 이상을 바르고, 2~3시간마다 얇게 덧발라 주세요. 모자·그늘도 함께 활용하세요.',
    ),
    HomeCarePrescription(
      id: 'no_sauna',
      chipLabel: '사우나·찜질 금지',
      directive:
          '열감이 염증을 키울 수 있어요. 3일간 사우나·찜질방·뜨거운 샤워는 피하고, 미지근한 물로 짧게 씻으세요.',
    ),
    HomeCarePrescription(
      id: 'sleep_early',
      chipLabel: '22시 이전 취침',
      directive:
          '야간 재생 호르몬이 활발한 시간대를 쓰려면 22시 전 취침을 목표로 하세요. 취침 전 보습을 마무리하면 효과가 배가됩니다.',
    ),
    HomeCarePrescription(
      id: 'cool_compress',
      chipLabel: '쿨링 찜질',
      directive:
          '열감·붓기가 있을 때 깨끗하고 차갑게 적신 패드를 3~5분 올려 주세요. 얼음을 직접 피부에 대지 마세요.',
    ),
    HomeCarePrescription(
      id: 'no_makeup_24h',
      chipLabel: '화장 24시간 금지',
      directive:
          '시술 직후 모공·장벽이 예민합니다. 24시간은 메이크업·쿠션을 쉬고, 톤업이 필요하면 선크림만 가볍게 올려 주세요.',
    ),
  ];

  static HomeCarePrescription? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static HomeCarePrescription? byChipLabel(String label) {
    final t = label.trim();
    for (final p in all) {
      if (p.chipLabel == t || p.id == t) return p;
    }
    return null;
  }

  /// 저장된 태그(ID 또는 라벨) → 서술형 문장 목록.
  static List<String> directivesFor(List<String> tags) {
    final out = <String>[];
    for (final raw in tags) {
      final p = byId(raw.trim()) ?? byChipLabel(raw);
      if (p != null) {
        out.add(p.directive);
      } else if (raw.trim().isNotEmpty) {
        out.add(raw.trim());
      }
    }
    return out;
  }
}
