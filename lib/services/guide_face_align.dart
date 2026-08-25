import 'guide_face_align_stub.dart'
    if (dart.library.html) 'guide_face_align_web.dart' as impl;

/// MediaPipe 얼굴 Pitch/Yaw/Roll 정렬 상태.
class GuideFacePose {
  const GuideFacePose({
    required this.detected,
    required this.pitch,
    required this.yaw,
    required this.roll,
  });

  final bool detected;
  final double pitch;
  final double yaw;
  final double roll;

  static const none = GuideFacePose(
    detected: false,
    pitch: 0,
    yaw: 0,
    roll: 0,
  );

  /// 정면 정렬 허용 오차 (도).
  static const alignToleranceDeg = 10.0;

  bool get isAligned {
    if (!detected) return false;
    return pitch.abs() <= alignToleranceDeg &&
        yaw.abs() <= alignToleranceDeg &&
        roll.abs() <= alignToleranceDeg;
  }
}

/// 웹 MediaPipe FaceLandmarker 세션. 네이티브는 no-op.
abstract class GuideFaceAlign {
  Stream<GuideFacePose> get poses;

  Future<void> start(Object videoElement);

  Future<void> stop();

  void dispose();
}

GuideFaceAlign createGuideFaceAlign() => impl.createGuideFaceAlign();
