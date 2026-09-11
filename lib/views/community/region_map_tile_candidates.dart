import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// C.S1 Quiet Local Canvas 후보.
/// PO 잠금 전 운영 기본은 [RegionMapTileId.osmBaseline]만.
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

/// 키는 dart-define / .env만. 값 커밋·채팅 출력 금지.
abstract final class RegionMapTileCatalog {
  RegionMapTileCatalog._();

  static const _stadiaDefine = String.fromEnvironment('STADIA_MAPS_API_KEY');
  static const _maptilerDefine = String.fromEnvironment('MAPTILER_API_KEY');

  /// 운영 기본(PO 잠금 전). Carto 임시 적용 롤백.
  static const RegionMapTileId productionDefault = RegionMapTileId.osmBaseline;

  static String _env(String name, String fromDefine) {
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    try {
      return dotenv.maybeGet(name)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get stadiaKey => _env('STADIA_MAPS_API_KEY', _stadiaDefine);
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
          rankNote: '기준선 · 채택 비목표',
        );
      case RegionMapTileId.stadiaAlidadeSmooth:
        final key = stadiaKey;
        final has = key.isNotEmpty;
        return RegionMapTileSpec(
          id: RegionMapTileId.stadiaAlidadeSmooth,
          code: 'A',
          label: 'Alidade Smooth',
          urlTemplate: has
              ? 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png?api_key=$key'
              : '',
          attribution: '© Stadia Maps © OpenMapTiles © OpenStreetMap',
          needsKey: true,
          keyPresent: has,
          keyHint: 'STADIA_MAPS_API_KEY',
          rankNote: 'C.S1 1순위 후보',
        );
      case RegionMapTileId.maptilerBaseLight:
        final key = maptilerKey;
        final has = key.isNotEmpty;
        return RegionMapTileSpec(
          id: RegionMapTileId.maptilerBaseLight,
          code: 'B',
          label: 'Base Light',
          // MapTiler basic-v2 ≈ light base; 키 있을 때만 URL 생성.
          urlTemplate: has
              ? 'https://api.maptiler.com/maps/basic-v2/{z}/{x}/{y}.png?key=$key'
              : '',
          attribution: '© MapTiler © OpenStreetMap',
          needsKey: true,
          keyPresent: has,
          keyHint: 'MAPTILER_API_KEY',
          rankNote: 'C.S1 2순위 후보',
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
          rankNote: 'C.S1 3순위 후보',
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
          rankNote: '이전 임시 · 공식 후보 아님',
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
      'C.S1 keys present: stadia=${stadiaKey.isNotEmpty} '
      'maptiler=${maptilerKey.isNotEmpty}',
    );
  }
}
