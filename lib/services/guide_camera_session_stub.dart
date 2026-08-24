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
  Stream<double?> get rollDegrees => const Stream.empty();

  @override
  Future<void> start({required bool front}) async {
    throw UnsupportedError(
      '스마트 가이드 카메라는 웹(태블릿 브라우저/PWA)에서만 사용할 수 있어요.',
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<Uint8List?> captureJpeg({double quality = 0.92}) async => null;

  @override
  Future<bool> requestOrientationPermission() async => false;
}
