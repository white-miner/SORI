/// PRD v5.3 — care timer fullscreen entry routing SSOT.
enum CareTimerEntryMode {
  /// Toolbox timer icon — standalone utility, manual start in field.
  standalone,

  /// Home [케어 시작] — preset not armed; pick program inside timer field.
  careStartManual,

  /// Home [케어 시작] — preset armed on home; 3s + TTS auto-start.
  careStartQuick,
}

extension CareTimerEntryModeX on CareTimerEntryMode {
  bool get showCareEndImmediately =>
      this == CareTimerEntryMode.careStartQuick;

  bool get showCareStartButton =>
      this == CareTimerEntryMode.standalone ||
      this == CareTimerEntryMode.careStartManual;

  bool get autoStartPipeline => this == CareTimerEntryMode.careStartQuick;
}
