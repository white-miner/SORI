import 'dart:async';

import 'guide_face_align.dart';

GuideFaceAlign createGuideFaceAlign() => _StubGuideFaceAlign();

class _StubGuideFaceAlign implements GuideFaceAlign {
  final _ctrl = StreamController<GuideFacePose>.broadcast();

  @override
  Stream<GuideFacePose> get poses => _ctrl.stream;

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
