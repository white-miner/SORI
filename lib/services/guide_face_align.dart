import 'dart:math' as math;
import 'dart:ui';

import 'guide_face_align_stub.dart'
    if (dart.library.html) 'guide_face_align_web.dart' as impl;

/// MediaPipe 얼굴 bbox 중심·반경 + B/A 임상 정렬 판정.
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

  /// 레거시 — UI/힌트 보조. 정렬 판정에는 사용하지 않음.
  final bool inCircle;
  final double pitch;
  final double yaw;
  final double roll;

  /// 정규화 얼굴 중심 (0~1). bbox 기준.
  final double centerX;
  final double centerY;

  /// bbox circumscribed 반경 (프레임 짧은 변 대비 정규화).
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

  /// 고정 가이드 원 — Flutter painter / JS bridge 공통.
  static const guideCenterX = 0.5;
  static const guideCenterY = 0.46;
  static const outerRadiusNorm = 0.36;

  /// 내부 Target Scale 점선 원 = 외부의 75%.
  static const innerTargetRadiusRatio = 0.75;

  static const innerTargetRadiusNorm =
      outerRadiusNorm * innerTargetRadiusRatio;

  /// 조건 A: 중심 위치 허용 오차 (px) — 사용성 위해 완화.
  static const centerAlignTolerancePx = 30.0;

  /// 조건 B: 반경(거리) 허용 오차 ±20%.
  static const scaleAlignToleranceRatio = 0.20;

  /// Soft magnet snap zone (slightly wider than hard align).
  static const snapPositionTolerancePx = 42.0;
  static const snapScaleToleranceRatio = 0.28;

  /// 테스트·폴백용 3:4 프레임.
  static const referenceFrame = Size(360, 480);

  Offset faceCenterPx(Size frameSize, {bool mirrored = false}) {
    final nx = mirrored ? 1.0 - centerX : centerX;
    return Offset(nx * frameSize.width, centerY * frameSize.height);
  }

  Offset targetCenterPx(Size frameSize) => Offset(
        frameSize.width * guideCenterX,
        frameSize.height * guideCenterY,
      );

  double outerRadiusPx(Size frameSize) =>
      math.min(frameSize.width, frameSize.height) * outerRadiusNorm;

  double innerTargetRadiusPx(Size frameSize) =>
      outerRadiusPx(frameSize) * innerTargetRadiusRatio;

  double faceRadiusPx(Size frameSize) {
    if (faceRadius <= 0) return 0;
    return math.min(frameSize.width, frameSize.height) * faceRadius;
  }

  /// 조건 A — Position Match.
  bool isPositionAligned(Size frameSize, {bool mirrored = false}) {
    if (!detected) return false;
    final dist = (faceCenterPx(frameSize, mirrored: mirrored) -
            targetCenterPx(frameSize))
        .distance;
    return dist <= centerAlignTolerancePx;
  }

  /// 조건 B — Scale/Distance Match.
  bool isScaleAligned(Size frameSize) {
    if (!detected || faceRadius <= 0) return false;
    final targetR = innerTargetRadiusPx(frameSize);
    if (targetR <= 0) return false;
    final err = (faceRadiusPx(frameSize) - targetR).abs() / targetR;
    return err <= scaleAlignToleranceRatio;
  }

  /// A + B 동시 충족 시에만 정렬.
  bool computeAligned(Size frameSize, {bool mirrored = false}) {
    return isPositionAligned(frameSize, mirrored: mirrored) &&
        isScaleAligned(frameSize);
  }

  bool get isAligned => computeAligned(referenceFrame);

  bool get isCenterAligned => isPositionAligned(referenceFrame);

  /// 0 = perfect, 1+ = far — combined position + scale error for hot/cold UI.
  double alignmentDistance(Size frameSize, {bool mirrored = false}) {
    if (!detected || faceRadius <= 0) return 1.0;
    final posErr = (faceCenterPx(frameSize, mirrored: mirrored) -
            targetCenterPx(frameSize))
        .distance;
    final posNorm = (posErr / centerAlignTolerancePx).clamp(0.0, 3.0);
    final targetR = innerTargetRadiusPx(frameSize);
    final scaleErr = targetR <= 0
        ? 1.0
        : ((faceRadiusPx(frameSize) - targetR).abs() / targetR);
    final scaleNorm =
        (scaleErr / scaleAlignToleranceRatio).clamp(0.0, 3.0);
    return math.max(posNorm, scaleNorm);
  }

  /// Soft snap — within magnet zone (wider than hard align).
  bool isInSnapZone(Size frameSize, {bool mirrored = false}) {
    if (!detected || faceRadius <= 0) return false;
    final posOk = (faceCenterPx(frameSize, mirrored: mirrored) -
                targetCenterPx(frameSize))
            .distance <=
        snapPositionTolerancePx;
    final targetR = innerTargetRadiusPx(frameSize);
    if (targetR <= 0) return false;
    final scaleOk =
        ((faceRadiusPx(frameSize) - targetR).abs() / targetR) <=
            snapScaleToleranceRatio;
    return posOk && scaleOk;
  }

  /// -1 too close (face too big), +1 too far, 0 ok.
  int scaleDirection(Size frameSize) {
    if (!detected || faceRadius <= 0) return 0;
    final targetR = innerTargetRadiusPx(frameSize);
    if (targetR <= 0) return 0;
    final r = faceRadiusPx(frameSize);
    final err = (r - targetR) / targetR;
    if (err > scaleAlignToleranceRatio) return -1;
    if (err < -scaleAlignToleranceRatio) return 1;
    return 0;
  }
}

/// 웹 MediaPipe FaceLandmarker 세션. 네이티브는 no-op.
abstract class GuideFaceAlign {
  Stream<GuideFacePose> get poses;

  Future<void> prepare();
  Future<void> start(Object videoElement);
  Future<void> stop();
  void dispose();
}

GuideFaceAlign createGuideFaceAlign() => impl.createGuideFaceAlign();
