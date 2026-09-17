import 'dart:async';

import 'guide_body_align.dart';

GuideBodyAlign createGuideBodyAlign() => _StubGuideBodyAlign();

class _StubGuideBodyAlign implements GuideBodyAlign {
  final _ctrl = StreamController<GuideBodyPose>.broadcast();

  @override
  Stream<GuideBodyPose> get poses => _ctrl.stream;

  @override
  Future<void> prepare() async {}

  @override
  Future<void> start(Object videoElement) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {
    unawaited(_ctrl.close());
  }
}
