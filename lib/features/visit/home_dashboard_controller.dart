import 'dart:async';

import 'package:flutter/foundation.dart';

/// PRD v5.3 — home hero + toolbox interaction SSOT.
enum HomeHeroMode {
  wallClock,
  calendarExpanded,
  countSetup,
  countRunning,
  countComplete,
}

enum HomeToolboxTool {
  none,
  timer,
  count,
  calculator,
  weather,
}

class HomeDashboardController extends ChangeNotifier {
  HomeHeroMode heroMode = HomeHeroMode.wallClock;
  HomeToolboxTool activeTool = HomeToolboxTool.none;
  bool calculatorOpen = false;

  int countTotalSeconds = 0;
  int countRemainingSeconds = 0;
  int countBlinkTicks = 0;

  Timer? _countIdleTimer;
  Timer? _countTickTimer;
  Timer? _blinkTimer;

  DateTime selectedDay = DateTime.now();
  bool memoStackExpanded = false;

  void selectDay(DateTime day) {
    selectedDay = DateTime(day.year, day.month, day.day);
    notifyListeners();
  }

  void toggleCalendar() {
    heroMode = heroMode == HomeHeroMode.calendarExpanded
        ? HomeHeroMode.wallClock
        : HomeHeroMode.calendarExpanded;
    notifyListeners();
  }

  void collapseCalendar() {
    if (heroMode == HomeHeroMode.calendarExpanded) {
      heroMode = HomeHeroMode.wallClock;
      notifyListeners();
    }
  }

  void toggleMemoStack() {
    memoStackExpanded = !memoStackExpanded;
    notifyListeners();
  }

  void toggleCountTool() {
    if (activeTool == HomeToolboxTool.count &&
        (heroMode == HomeHeroMode.countSetup ||
            heroMode == HomeHeroMode.countRunning)) {
      _cancelCount();
      return;
    }
    _cancelCount(silent: true);
    calculatorOpen = false;
    activeTool = HomeToolboxTool.count;
    heroMode = HomeHeroMode.countSetup;
    countTotalSeconds = 0;
    countRemainingSeconds = 0;
    _armCountIdleTimer();
    notifyListeners();
  }

  void selectTimerTool() {
    resetToTimerStandby();
  }

  /// 타이머 아이콘 — 계산기/카운트 등 부가기능을 모두 닫고 스탠바이.
  void resetToTimerStandby() {
    _cancelCount(silent: true);
    calculatorOpen = false;
    activeTool = HomeToolboxTool.timer;
    heroMode = HomeHeroMode.wallClock;
    notifyListeners();
  }

  void toggleCalculator() {
    if (calculatorOpen) {
      calculatorOpen = false;
      activeTool = HomeToolboxTool.none;
    } else {
      _cancelCount(silent: true);
      calculatorOpen = true;
      activeTool = HomeToolboxTool.calculator;
    }
    notifyListeners();
  }

  void openWeatherTool() {
    activeTool = HomeToolboxTool.weather;
    notifyListeners();
  }

  void clearToolHighlight() {
    if (activeTool != HomeToolboxTool.count) {
      activeTool = HomeToolboxTool.none;
    }
    notifyListeners();
  }

  void onCountDigitTap(int digitIndex, int newDigit) {
    if (heroMode != HomeHeroMode.countSetup) return;
    final digits = _mmssDigits(countTotalSeconds);
    digits[digitIndex.clamp(0, 3)] = newDigit.clamp(0, 9);
    countTotalSeconds = _fromMmssDigits(digits);
    countRemainingSeconds = countTotalSeconds;
    _armCountIdleTimer();
    notifyListeners();
  }

  void _armCountIdleTimer() {
    _countIdleTimer?.cancel();
    _countIdleTimer = Timer(const Duration(seconds: 5), _autoStartCountdown);
  }

  void _autoStartCountdown() {
    if (heroMode != HomeHeroMode.countSetup) return;
    if (countTotalSeconds <= 0) return;
    heroMode = HomeHeroMode.countRunning;
    countRemainingSeconds = countTotalSeconds;
    _countTickTimer?.cancel();
    _countTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (countRemainingSeconds <= 1) {
        countRemainingSeconds = 0;
        _countTickTimer?.cancel();
        _onCountComplete();
      } else {
        countRemainingSeconds--;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<void> _onCountComplete() async {
    heroMode = HomeHeroMode.countComplete;
    countBlinkTicks = 0;
    notifyListeners();
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      countBlinkTicks++;
      notifyListeners();
      if (countBlinkTicks >= 3) {
        t.cancel();
        _cancelCount();
      }
    });
  }

  void _cancelCount({bool silent = false}) {
    _countIdleTimer?.cancel();
    _countTickTimer?.cancel();
    _blinkTimer?.cancel();
    countTotalSeconds = 0;
    countRemainingSeconds = 0;
    countBlinkTicks = 0;
    heroMode = HomeHeroMode.wallClock;
    if (activeTool == HomeToolboxTool.count) {
      activeTool = HomeToolboxTool.none;
    }
    if (!silent) notifyListeners();
  }

  static List<int> _mmssDigits(int totalSeconds) {
    final m = (totalSeconds ~/ 60).clamp(0, 99);
    final s = (totalSeconds % 60).clamp(0, 59);
    return [m ~/ 10, m % 10, s ~/ 10, s % 10];
  }

  static int _fromMmssDigits(List<int> d) {
    final mm = (d[0] * 10 + d[1]).clamp(0, 99);
    final ss = (d[2] * 10 + d[3]).clamp(0, 59);
    return mm * 60 + ss;
  }

  List<int> get countDigits =>
      _mmssDigits(
        heroMode == HomeHeroMode.countRunning ||
                heroMode == HomeHeroMode.countComplete
            ? countRemainingSeconds
            : countTotalSeconds,
      );

  bool get countBlinkVisible =>
      heroMode == HomeHeroMode.countComplete && countBlinkTicks.isOdd;

  @override
  void dispose() {
    _countIdleTimer?.cancel();
    _countTickTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }
}
