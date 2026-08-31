import 'package:flutter/material.dart';

/// iOS native tint palette for care preset slot buttons.
enum PresetSlotTint {
  red,
  green,
  orange,
  purple,
  blue;

  static const iosRed = Color(0xFFFF3B30);
  static const iosGreen = Color(0xFF34C759);
  static const iosOrange = Color(0xFFFF9500);
  static const iosPurple = Color(0xFFAF52DE);
  static const iosBlue = Color(0xFF007AFF);

  Color get color => switch (this) {
        PresetSlotTint.red => iosRed,
        PresetSlotTint.green => iosGreen,
        PresetSlotTint.orange => iosOrange,
        PresetSlotTint.purple => iosPurple,
        PresetSlotTint.blue => iosBlue,
      };

  String get label => switch (this) {
        PresetSlotTint.red => '빨강',
        PresetSlotTint.green => '초록',
        PresetSlotTint.orange => '주황',
        PresetSlotTint.purple => '보라',
        PresetSlotTint.blue => '파랑',
      };

  String get storageKey => name;

  static List<PresetSlotTint> get palette => PresetSlotTint.values;

  static PresetSlotTint defaultForSlot(int slotIndex) =>
      palette[slotIndex.clamp(0, 4) % palette.length];

  static PresetSlotTint fromKey(String? key, {required int fallbackIndex}) {
    if (key == null || key.isEmpty) {
      return defaultForSlot(fallbackIndex);
    }
    for (final tint in PresetSlotTint.values) {
      if (tint.storageKey == key) return tint;
    }
    return defaultForSlot(fallbackIndex);
  }
}
