import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../visit_kernel/models/care_program_template.dart';
import '../../visit_kernel/models/preset_slot_tint.dart';
import '../../visit_kernel/models/visit_operation_timer.dart';

/// PRD v4.5 — SharedPreferences cache for timer state (background survival).
abstract final class VisitTimerLocalCache {
  static String _presetKey(String shopId) => 'v45_timer_presets_$shopId';
  static String _activeKey(String shopId) => 'v45_active_timer_$shopId';
  static String _slotTintKey(String shopId) => 'v45_slot_tints_$shopId';

  static Future<List<CareProgramTemplate>> loadPresets(String shopId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_presetKey(shopId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map(
            (e) => CareProgramTemplate.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> savePresets(
    String shopId,
    List<CareProgramTemplate> presets,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _presetKey(shopId),
      jsonEncode(presets.map((p) => p.toMap()).toList()),
    );
  }

  static Future<VisitOperationTimer?> loadActiveTimer(String shopId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeKey(shopId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return VisitOperationTimer.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveActiveTimer(
    String shopId,
    VisitOperationTimer? timer,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (timer == null) {
      await prefs.remove(_activeKey(shopId));
      return;
    }
    await prefs.setString(
      _activeKey(shopId),
      jsonEncode(timer.toLocalJson()),
    );
  }

  static Future<List<PresetSlotTint>> loadSlotTints(String shopId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_slotTintKey(shopId));
    if (raw == null || raw.length != 5) {
      return List.generate(5, PresetSlotTint.defaultForSlot);
    }
    return List.generate(
      5,
      (i) => PresetSlotTint.fromKey(raw[i], fallbackIndex: i),
    );
  }

  static Future<void> saveSlotTints(
    String shopId,
    List<PresetSlotTint> tints,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _slotTintKey(shopId),
      tints.map((t) => t.storageKey).toList(),
    );
  }
}
