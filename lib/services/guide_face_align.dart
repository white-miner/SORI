import 'dart:math' as math;

import 'guide_face_align_stub.dart'
    if (dart.library.html) 'guide_face_align_web.dart' as impl;

/// MediaPipe 얼굴 Pitch/Yaw/Roll + 중심 좌표 + 원형 가이드 정렬 상태.
class GuideFacePose {
  const GuideFacePose({
    required this.detected,
    required this.inCircle,
    required this.pitch,
    required this.yaw,
    required this.roll,
    this.centerX = 0.5,
    this.centerY = 0.5,
    this.faceRadius = 0.18,
  });

  final bool detected;

  /// 눈·코·턱 등 주요 랜드마크가 원형 뷰파인더 안에 온전히 들어옴.
  final bool inCircle;
  final double pitch;
  final double yaw;
  final double roll;

  /// 정규화 얼굴 중심 (0~1). MediaPipe 랜드마크 기준.
  final double centerX;
  final double centerY;

  /// 추적 원 반경 (프레임 짧은 변 대비 정규화).
  final double faceRadius;

  static const none = GuideFacePose(
    detected: false,
    inCircle: false,
    pitch: 0,
    yaw: 0,
    roll: 0,
    centerX: 0.5,
    centerY: 0.5,
    faceRadius: 0,
  );

  /// 고정 가이드 원 중심 — Flutter painter / JS bridge 공통.
  static const guideCenterX = 0.5;
  static const guideCenterY = 0.46;
  static const guideRadiusNorm = 0.36;

  /// 중심(x,y) 오차 허용 — 3:4 프레임 metric 보정.
  static const centerAlignToleranceNorm = 0.055;

  /// 정면 정렬 허용 오차 (도).
  static const alignToleranceDeg = 8.0;

  /// 고정 가이드 원 ↔ 동적 추적 원 중심 거리 (정규화).
  double get centerDistanceNorm {
    if (!detected) return double.infinity;
    final dx = centerX - guideCenterX;
    final dy = (centerY - guideCenterY) * (4 / 3);
    return math.sqrt(dx * dx + dy * dy);
  }

  bool get isCenterAligned =>
      detected && centerDistanceNorm <= centerAlignToleranceNorm;

  /// 3D 자세 + 중심 좌표 모두 허용 범위.
  bool get isAligned {
    if (!isCenterAligned) return false;
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
