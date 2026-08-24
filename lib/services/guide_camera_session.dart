import 'dart:typed_data';

import 'guide_camera_session_stub.dart'
    if (dart.library.html) 'guide_camera_session_web.dart' as impl;

/// 웹 getUserMedia 세션 팩토리 (네이티브는 unsupported stub).
GuideCameraSession createGuideCameraSession() => impl.createGuideCameraSession();

abstract class GuideCameraSession {
  /// HtmlElementView 용 viewType. start 이후에만 유효.
  String? get viewType;

  bool get isRunning;
  bool get mirrored;
  int get videoWidth;
  int get videoHeight;

  /// [front] true = 전면(user), false = 후면(environment).
  Future<void> start({required bool front});

  Future<void> stop();

  /// 현재 비디오 프레임을 JPEG 바이트로 캡처 (미러 없이 원본 센서 방향).
  Future<Uint8List?> captureJpeg({double quality = 0.92});

  /// DeviceOrientation roll(도). 미지원/거부 시 null.
  Stream<double?> get rollDegrees;

  Future<bool> requestOrientationPermission();
}
