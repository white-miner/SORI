import 'dart:async';

import 'package:flutter/material.dart';

import '../../operation/widgets/care_timer_fullscreen_page.dart';
import '../../operation/widgets/flip_clock_display.dart';

/// My Feed 벽시계. 1초 틱의 setState 는 이 위젯 밖으로 새지 않는다.
class HomeWallClock extends StatefulWidget {
  const HomeWallClock({super.key, this.now});

  /// 운영은 [DateTime.now]. 위젯 테스트에서만 주입한다.
  final DateTime Function()? now;

  @override
  State<HomeWallClock> createState() => _HomeWallClockState();
}

class _HomeWallClockState extends State<HomeWallClock>
    with WidgetsBindingObserver {
  Timer? _tick;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  int _totalSeconds() {
    final n = _now();
    return n.hour * 3600 + n.minute * 60 + n.second;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTick() {
    _tick?.cancel();
    _tick = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _stopTick();
      case AppLifecycleState.resumed:
        if (mounted) setState(() {});
        _startTick();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTick();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlipClockDisplay(
      key: const Key('home-wall-clock'),
      totalSeconds: _totalSeconds(),
      hero: true,
      homeHero: true,
      showSeconds: false,
      showCornerSeconds: true,
      heroTag: CareTimerFullscreenPage.flipHeroTag,
      style: FlipClockStyle.darkGlass,
    );
  }
}
