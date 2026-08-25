import 'dart:async';
import 'dart:typed_data';

import 'guide_camera_session.dart';

GuideCameraSession createGuideCameraSession() => _StubGuideCameraSession();

class _StubGuideCameraSession implements GuideCameraSession {
  @override
  String? get viewType => null;

  @override
  bool get isRunning => false;

  @override
  bool get mirrored => false;

  @override
  int get videoWidth => 0;

  @override
  int get videoHeight => 0;

  @override
  double get zoomFactor => 1;

  @override
  bool get usingHardwareZoom => false;

  @override
  Stream<double?> get rollDegrees => const Stream.empty();

  @override
  Future<bool> requestOrientationPermission() async => false;

  @override
  Future<void> start({required bool front, double zoom = 1.7}) async {
    throw UnsupportedError('Guide camera is web-only');
  }

  @override
  Future<void> setZoom(double zoom) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<Uint8List?> captureJpeg({double quality = 0.92}) async => null;
}
