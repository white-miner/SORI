import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// C.S1 Quiet Local Canvas 후보.
enum RegionMapTileId {
  osmBaseline,
  stadiaAlidadeSmooth,
  maptilerBaseLight,
  maptilerDatavizLight,
  cartoLightTemp,
}

class RegionMapTileSpec {
  const RegionMapTileSpec({
    required this.id,
    required this.code,
    required this.label,
    required this.urlTemplate,
    required this.attribution,
    this.subdomains = const [],
    this.needsKey = false,
    this.keyPresent = true,
    this.keyHint = '',
    this.isOfficialCs1Candidate = true,
    this.rankNote = '',
  });

  final RegionMapTileId id;
  final String code;
  final String label;
  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;
  final bool needsKey;
  final bool keyPresent;
  final String keyHint;
  final bool isOfficialCs1Candidate;
  final String rankNote;

  bool get canRender => urlTemplate.isNotEmpty && (!needsKey || keyPresent);
}

/// 운영 A(Stadia)는 **domain auth 전용** — URL/번들에 api_key 금지.
abstract final class RegionMapTileCatalog {
  RegionMapTileCatalog._();

  static const _maptilerDefine = String.fromEnvironment('MAPTILER_API_KEY');

  /// C.S1 채택: Alidade Smooth (키리스 · Stadia Property 도메인 인증 필수).
  static const RegionMapTileId productionDefault =
      RegionMapTileId.stadiaAlidadeSmooth;

  /// 롤백/기준선.
  static const RegionMapTileId rollbackBaseline = RegionMapTileId.osmBaseline;

  /// Domain auth 래스터 (키 query 없음).
  static const String stadiaAlidadeSmoothUrl =
      'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png';

  static const String stadiaAttribution =
      '© Stadia Maps · © OpenMapTiles · © OpenStreetMap contributors';

  static String _env(String name, String fromDefine) {
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    try {
      return dotenv.maybeGet(name)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get maptilerKey => _env('MAPTILER_API_KEY', _maptilerDefine);

  static RegionMapTileSpec spec(RegionMapTileId id) {
    switch (id) {
      case RegionMapTileId.osmBaseline:
        return const RegionMapTileSpec(
          id: RegionMapTileId.osmBaseline,
          code: '0',
          label: 'OSM 기준선',
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          attribution: '© OpenStreetMap',
          rankNote: '롤백·기준선',
        );
      case RegionMapTileId.stadiaAlidadeSmooth:
        return const RegionMapTileSpec(
          id: RegionMapTileId.stadiaAlidadeSmooth,
          code: 'A',
          label: 'Alidade Smooth',
          urlTemplate: stadiaAlidadeSmoothUrl,
          attribution: stadiaAttribution,
          needsKey: false,
          rankNote: 'C.S1 채택 · domain auth',
        );
      case RegionMapTileId.maptilerBaseLight:
        final key = maptilerKey;
        final has = key.isNotEmpty;
        return RegionMapTileSpec(
          id: RegionMapTileId.maptilerBaseLight,
          code: 'B',
          label: 'Base Light',
          urlTemplate: has
              ? 'https://api.maptiler.com/maps/basic-v2/{z}/{x}/{y}.png?key=$key'
              : '',
          attribution: '© MapTiler © OpenStreetMap',
          needsKey: true,
          keyPresent: has,
          keyHint: 'MAPTILER_API_KEY',
          rankNote: '보류 · 비교용',
        );
      case RegionMapTileId.maptilerDatavizLight:
        final key = maptilerKey;
        final has = key.isNotEmpty;
        return RegionMapTileSpec(
          id: RegionMapTileId.maptilerDatavizLight,
          code: 'C',
          label: 'Dataviz Light',
          urlTemplate: has
              ? 'https://api.maptiler.com/maps/dataviz-light/{z}/{x}/{y}.png?key=$key'
              : '',
          attribution: '© MapTiler © OpenStreetMap',
          needsKey: true,
          keyPresent: has,
          keyHint: 'MAPTILER_API_KEY',
          rankNote: '보류 · 비교용',
        );
      case RegionMapTileId.cartoLightTemp:
        return const RegionMapTileSpec(
          id: RegionMapTileId.cartoLightTemp,
          code: 'T',
          label: 'Carto Light(임시)',
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c', 'd'],
          attribution: '© CARTO © OpenStreetMap',
          isOfficialCs1Candidate: false,
          rankNote: '비교 기준 · 비채택',
        );
    }
  }

  static List<RegionMapTileSpec> compareSet() => [
        spec(RegionMapTileId.osmBaseline),
        spec(RegionMapTileId.stadiaAlidadeSmooth),
        spec(RegionMapTileId.maptilerBaseLight),
        spec(RegionMapTileId.maptilerDatavizLight),
        spec(RegionMapTileId.cartoLightTemp),
      ];

  static void debugLogKeyPresence() {
    if (!kDebugMode) return;
    debugPrint(
      'C.S1: production=A Alidade Smooth (domain auth, no key in URL). '
      'maptilerCompareKey=${maptilerKey.isNotEmpty}',
    );
  }
}
