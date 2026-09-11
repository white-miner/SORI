import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// C.S1 후보 — SORI Local Bloom 방향 (A 채택 철회 후).
enum RegionMapTileId {
  osmBaseline,
  stadiaAlidadeSmooth,
  maptilerBaseLight,
  maptilerDatavizLight,
  maptilerStreetsPastel,
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

/// 운영 기본은 PO 재채택 전까지 OSM. Pastel/A는 비교만(키·도메인 필요 시).
abstract final class RegionMapTileCatalog {
  RegionMapTileCatalog._();

  static const _maptilerDefine = String.fromEnvironment('MAPTILER_API_KEY');

  /// A 채택 철회 → 재선정 전 기준선.
  static const RegionMapTileId productionDefault = RegionMapTileId.osmBaseline;

  static const RegionMapTileId rollbackBaseline = RegionMapTileId.osmBaseline;

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
          rankNote: '운영 임시 · 기준선',
        );
      case RegionMapTileId.stadiaAlidadeSmooth:
        return const RegionMapTileSpec(
          id: RegionMapTileId.stadiaAlidadeSmooth,
          code: 'A',
          label: 'Alidade Smooth',
          urlTemplate:
              'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png',
          attribution:
              '© Stadia Maps · © OpenMapTiles · © OpenStreetMap contributors',
          needsKey: false,
          rankNote: '채택 철회 · 보류(저채도)',
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
          rankNote: '비교 유지',
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
          rankNote: '보조 비교 · 우선↓',
        );
      case RegionMapTileId.maptilerStreetsPastel:
        final key = maptilerKey;
        final has = key.isNotEmpty;
        return RegionMapTileSpec(
          id: RegionMapTileId.maptilerStreetsPastel,
          code: 'D',
          label: 'Streets Pastel',
          // MapTiler streets-v2-pastel raster.
          urlTemplate: has
              ? 'https://api.maptiler.com/maps/streets-v2-pastel/{z}/{x}/{y}.png?key=$key'
              : '',
          attribution: '© MapTiler © OpenStreetMap',
          needsKey: true,
          keyPresent: has,
          keyHint: 'MAPTILER_API_KEY',
          rankNote: 'Local Bloom 1순위 후보',
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
          rankNote: '비교 · 비채택',
        );
    }
  }

  /// 비교 칩 순서: 0 · D · B · A · C · T
  static List<RegionMapTileSpec> compareSet() => [
        spec(RegionMapTileId.osmBaseline),
        spec(RegionMapTileId.maptilerStreetsPastel),
        spec(RegionMapTileId.maptilerBaseLight),
        spec(RegionMapTileId.stadiaAlidadeSmooth),
        spec(RegionMapTileId.maptilerDatavizLight),
        spec(RegionMapTileId.cartoLightTemp),
      ];

  static void debugLogKeyPresence() {
    if (!kDebugMode) return;
    debugPrint(
      'C.S1 Local Bloom: production=OSM until re-adopt. '
      'maptilerKey=${maptilerKey.isNotEmpty}',
    );
  }
}
