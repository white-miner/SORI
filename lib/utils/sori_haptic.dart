import 'sori_haptic_stub.dart'
    if (dart.library.html) 'sori_haptic_web.dart' as impl;

/// 짧은 햅틱(웹: Vibration API / 네이티브: HapticFeedback).
void soriLightHaptic() => impl.soriLightHaptic();
