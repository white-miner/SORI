import 'dart:typed_data';

import 'guide_camera_session_stub.dart'
    if (dart.library.html) 'guide_camera_session_web.dart' as impl;

/// 웹 getUserMedia 세션 팩토리 (네이티브는 unsupported stub).
GuideCameraSession createGuideCameraSession() => impl.createGuideCameraSession();

/// 차트 촬영 고정 비율 (세로 3:4). 왜곡 없이 레터박스 표시.
const double kGuideCameraAspectRatio = 3 / 4;

/// DeviceOrientation 기반 기기 자세 (도).
/// [roll] 좌우 기울기(gamma), [pitch] 앞뒤 기울기(beta−90, 세운 상태 기준 0).
class GuideDeviceAttitude {
  const GuideDeviceAttitude({required this.roll, required this.pitch});

  final double roll;
  final double pitch;

  static const none = GuideDeviceAttitude(roll: 0, pitch: 0);
}

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

  /// MediaPipe 등 ML용 비디오 핸들 (웹 HTMLVideoElement). 그 외 null.
  Object? get mlVideoHandle;

  /// [front] true = 전면(user), false = 후면(environment).
  /// [zoom] 저장된/슬라이더 배율.
  Future<void> start({required bool front, double zoom = 1.7});

  /// 프리셋 변경 시 표시 배율만 갱신 (스트림 재시작 없음).
  Future<void> setZoom(double zoom);

  /// 카메라 트랙·비디오 DOM을 즉시 해제한다 (워밍 캐시 없음).
  Future<void> stop();

  /// 현재 비디오 프레임을 JPEG 바이트로 캡처.
  /// 디지털 줌이면 중앙 크롭해 프리뷰와 동일 화각으로 저장.
  Future<Uint8List?> captureJpeg({double quality = 0.92});

  /// DeviceOrientation 자세 스트림. 미지원/거부 시 null 이벤트.
  Stream<GuideDeviceAttitude?> get attitude;

  /// @deprecated [attitude] 사용.
  Stream<double?> get rollDegrees;

  /// iOS Safari: 반드시 **사용자 탭 콜백 안**에서 호출.
  /// `DeviceOrientationEvent.requestPermission()` 후 리스너를 연결한다.
  Future<bool> requestOrientationPermission();

  /// 권한 승인(또는 비-iOS) 후 deviceorientation 리스너 시작.
  Future<bool> enableOrientationListening();

  /// 현재 모션 리스너가 붙어 있는지.
  bool get orientationListening;

  /// iOS 등 requestPermission API가 필요한 환경인지.
  bool get requiresOrientationPermissionPrompt;
}
