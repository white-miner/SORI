import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No.N · vN 끝자리 인덱스 색상 시스템 — 기본 팔레트.
/// 0=흰색 1=빨강 2=노랑 3=주황 4=초록 5=하늘색 6=파랑 7=보라 8=분홍 9=회색.
/// 순서 변경·항목 추가 금지 — 사용자 재정의는 [ChartIndexPaletteStore]에서.
const Map<int, Color> kDefaultChartIndexPalette = {
  0: Color(0xFFFFFFFF),
  1: Color(0xFFE53935),
  2: Color(0xFFFDD835),
  3: Color(0xFFFB8C00),
  4: Color(0xFF43A047),
  5: Color(0xFF29B6F6),
  6: Color(0xFF1E88E5),
  7: Color(0xFF8B5CF6),
  8: Color(0xFFEC407A),
  9: Color(0xFF757575),
};

/// 신규 · 신규 작성처럼 숫자가 없는 탭의 고정색. 끝자리 팔레트와 무관하며
/// 사용자가 편집할 수 없다 — SoriTokens.brand와 동일 값을 이 파일에 상수로
/// 복제해 chart_index 계열이 theme 계층에만 의존하도록 유지한다.
const Color kChartIndexNoNumberColor = Color(0xFF8B5CF6);

/// 여러 자리 번호의 끝자리. No.21 → 1, v130 → 0.
int chartIndexLastDigit(int number) => number.abs() % 10;

/// No.N · vN rail 라벨의 끝자리 색상 팔레트. 기기 로컬 저장(SharedPreferences)
/// — 서버 동기화·DB 컬럼 없음. No와 v가 같은 팔레트를 공유한다.
///
/// 앱 전역에서 [instance] 하나만 쓴다 (VisitTimerStore와 동일한 싱글톤 문법).
/// Chart 화면들은 이 store를 리스닝해 팔레트가 바뀌면 즉시 다시 그린다.
class ChartIndexPaletteStore extends ChangeNotifier {
  ChartIndexPaletteStore._() {
    unawaited(_load());
  }

  static final ChartIndexPaletteStore instance = ChartIndexPaletteStore._();

  static const _prefsKey = 'sori_chart_index_palette_v1';

  Map<int, Color> _palette = Map.of(kDefaultChartIndexPalette);
  bool _loaded = false;

  /// 현재 팔레트 스냅샷(읽기 전용 복사본).
  Map<int, Color> get palette => Map.unmodifiable(_palette);

  /// 기기 저장값 로드가 끝났는지. 로드 전에는 기본 팔레트로 그리다가,
  /// 로드가 끝나면 notifyListeners()로 실제 저장값을 반영한다.
  bool get isLoaded => _loaded;

  Color colorForDigit(int digit) =>
      _palette[digit] ?? kDefaultChartIndexPalette[digit]!;

  Color colorForNumber(int number) =>
      colorForDigit(chartIndexLastDigit(number));

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final next = Map.of(kDefaultChartIndexPalette);
          for (final entry in decoded.entries) {
            final digit = int.tryParse('${entry.key}');
            final value = entry.value;
            if (digit == null || digit < 0 || digit > 9) continue;
            if (value is! int) continue;
            next[digit] = Color(value);
          }
          _palette = next;
        }
      }
    } catch (e) {
      debugPrint('ChartIndexPaletteStore.load failed: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// digit(0~9) 하나의 색을 바꾼다. 즉시 반영 + 기기 저장.
  Future<void> setColor(int digit, Color color) async {
    if (digit < 0 || digit > 9) return;
    _palette = Map.of(_palette)..[digit] = color;
    notifyListeners();
    await _persist();
  }

  /// 기본 팔레트로 되돌린다.
  Future<void> resetToDefault() async {
    _palette = Map.of(kDefaultChartIndexPalette);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint('ChartIndexPaletteStore.resetToDefault failed: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _palette.map((digit, color) => MapEntry('$digit', color.toARGB32())),
      );
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      debugPrint('ChartIndexPaletteStore.persist failed: $e');
    }
  }

  /// 테스트 전용 — 싱글톤이라 테스트 간 상태가 새지 않도록 초기화한다.
  @visibleForTesting
  void debugResetForTest() {
    _palette = Map.of(kDefaultChartIndexPalette);
    _loaded = true;
  }
}

/// 끝자리 색 하나(`base`)로부터 파일 탭의 선택/비선택 배경·테두리·글자색을
/// 계산한다. 선택 여부와 무관하게 항상 같은 색 계열을 유지하고, 선택 시엔
/// 더 진하고 선명하게, 비선택 시엔 옅은 종이 색조로 가라앉힌다.
///
/// 채도가 거의 없는 흰색(끝자리 0 기본값) 같은 경우 흰 배경 위에서 완전히
/// 사라지지 않도록 중성 회색 계열로 안전하게 보정한다.
abstract final class ChartIndexColor {
  ChartIndexColor._();

  static bool _isNearWhite(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.saturation < 0.08 && hsl.lightness > 0.88;
  }

  /// 비선택 탭의 옅은 배경(종이 위 옅은 색조).
  static Color tint(Color base) {
    if (_isNearWhite(base)) return const Color(0xFFF1EFEC);
    return Color.lerp(base, Colors.white, 0.86)!;
  }

  /// 비선택 탭의 테두리 — 배경보다 한 단계 진한 같은 계열.
  static Color border(Color base) {
    if (_isNearWhite(base)) return const Color(0xFFBFBAB1);
    final hsl = HSLColor.fromColor(base);
    final l = hsl.lightness.clamp(0.0, 1.0) > 0.5
        ? 0.62
        : hsl.lightness.clamp(0.35, 0.62);
    return hsl.withLightness(l.toDouble()).toColor();
  }

  /// 비선택 탭의 글자색 — 읽히도록 어둡게 낮춘 같은 계열.
  static Color quietText(Color base) {
    if (_isNearWhite(base)) return const Color(0xFF6B665F);
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness(0.30)
        .withSaturation(hsl.saturation.clamp(0.35, 1.0))
        .toColor();
  }

  /// 선택 탭의 채움색 — 같은 색 계열을 유지한 채 더 진하고 선명하게.
  static Color fill(Color base) {
    if (_isNearWhite(base)) return const Color(0xFFFAFAF8);
    final hsl = HSLColor.fromColor(base);
    final l = (hsl.lightness * 0.88).clamp(0.28, 0.92);
    final s = hsl.saturation.clamp(0.55, 1.0);
    return hsl.withLightness(l.toDouble()).withSaturation(s.toDouble()).toColor();
  }

  /// 선택 탭 테두리 — 채움과 동일 색으로 경계 없이 이어 보이게 한다.
  static Color fillBorder(Color base) {
    if (_isNearWhite(base)) return const Color(0xFF3A3632);
    return fill(base);
  }

  /// 채움 위 글자색 — 명도에 따라 흰/검 자동 선택.
  static Color onFill(Color base) {
    if (_isNearWhite(base)) return const Color(0xFF2C2A26);
    final filled = fill(base);
    return ThemeData.estimateBrightnessForColor(filled) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1712);
  }
}
