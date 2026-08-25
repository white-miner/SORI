import 'guide_face_align_stub.dart'
    if (dart.library.html) 'guide_face_align_web.dart' as impl;

/// MediaPipe 얼굴 Pitch/Yaw/Roll + 원형 가이드 내부 안착 상태.
class GuideFacePose {
  const GuideFacePose({
    required this.detected,
    required this.inCircle,
    required this.pitch,
    required this.yaw,
    required this.roll,
  });

  final bool detected;

  /// 눈·코·턱 등 주요 랜드마크가 원형 뷰파인더 안에 온전히 들어옴.
  final bool inCircle;
  final double pitch;
  final double yaw;
  final double roll;

  static const none = GuideFacePose(
    detected: false,
    inCircle: false,
    pitch: 0,
    yaw: 0,
    roll: 0,
  );

  /// 정면 정렬 허용 오차 (도) — 원 내부 조건과 AND.
  static const alignToleranceDeg = 8.0;

  bool get isAligned {
    if (!detected || !inCircle) return false;
    return pitch.abs() <= alignToleranceDeg &&
        yaw.abs() <= alignToleranceDeg &&
        roll.abs() <= alignToleranceDeg;
  }
}

/// 웹 MediaPipe FaceLandmarker 세션. 네이티브는 no-op.
abstract class GuideFaceAlign {
  Stream<GuideFacePose> get poses;

  /// CDN/WASM 모델만 미리 로드 (추론 루프는 시작하지 않음).
  Future<void> prepare();

  /// 모델 준비 후 비디오에 추론 루프 연결.
  Future<void> start(Object videoElement);

  Future<void> stop();

  void dispose();
}

GuideFaceAlign createGuideFaceAlign() => impl.createGuideFaceAlign();
