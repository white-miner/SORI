import 'dart:typed_data';

import 'guide_camera_session_stub.dart'
    if (dart.library.html) 'guide_camera_session_web.dart' as impl;

/// 웹 getUserMedia 세션 팩토리 (네이티브는 unsupported stub).
GuideCameraSession createGuideCameraSession() => impl.createGuideCameraSession();

/// 차트 촬영 고정 비율 (세로 3:4). 왜곡 없이 레터박스 표시.
const double kGuideCameraAspectRatio = 3 / 4;

abstract class GuideCameraSession {
  /// HtmlElementView 용 viewType. start 이후에만 유효.
  String? get viewType;

  bool get isRunning;
  bool get mirrored;
  int get videoWidth;
  int get videoHeight;

  /// 실제 적용 중인 표시 배율 (HW 또는 디지털).
  double get zoomFactor;

  /// 하드웨어 줌 사용 중이면 true.
  bool get usingHardwareZoom;

  /// [front] true = 전면(user), false = 후면(environment).
  /// [zoom] 1m 거리 인물 화각용 목표 배율 (대략 1.5~2.0).
  Future<void> start({required bool front, double zoom = 1.7});

  /// 프리셋 변경 시 표시 배율만 갱신 (스트림 재시작 없음).
  Future<void> setZoom(double zoom);

  Future<void> stop();

  /// 현재 비디오 프레임을 JPEG 바이트로 캡처.
  /// 디지털 줌이면 중앙 크롭해 프리뷰와 동일 화각으로 저장.
  Future<Uint8List?> captureJpeg({double quality = 0.92});

  /// DeviceOrientation roll(도). 미지원/거부 시 null.
  Stream<double?> get rollDegrees;

  Future<bool> requestOrientationPermission();
}
