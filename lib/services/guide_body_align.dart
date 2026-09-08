import 'dart:math' as math;
import 'dart:ui';

import 'guide_body_align_stub.dart'
    if (dart.library.html) 'guide_body_align_web.dart' as impl;

/// 몸 정렬이 필요한 프리셋. 화면 enum(`GuidePreset`)과 분리해 두어
/// 서비스가 뷰를 거꾸로 참조하지 않게 한다.
enum GuideBodyTarget { decollete, abdomen, lowerBody, fullBody }

/// MediaPipe Pose 33포인트 중 이 앱이 쓰는 지점.
class GuideBodyLandmark {
  const GuideBodyLandmark({
    required this.x,
    required this.y,
    required this.visibility,
  });

  /// 정규화 좌표 (0~1). 원본 프레임 기준.
  final double x;
  final double y;

  /// MediaPipe visibility (0~1). 가려지거나 프레임 밖이면 낮아진다.
  final double visibility;

  bool get isVisible => visibility >= GuideBodyPose.visibilityThreshold;

  Offset toPx(Size frameSize, {bool mirrored = false}) {
    final nx = mirrored ? 1.0 - x : x;
    return Offset(nx * frameSize.width, y * frameSize.height);
  }
}

/// 포즈 랜드마크 1프레임. 프로토타입 단계에서는 판정 없이 좌표만 실어 나른다.
class GuideBodyPose {
  const GuideBodyPose({
    required this.detected,
    this.leftShoulder,
    this.rightShoulder,
    this.leftHip,
    this.rightHip,
    this.leftKnee,
    this.rightKnee,
    this.leftAnkle,
    this.rightAnkle,
    this.error,
  });

  final bool detected;
  final GuideBodyLandmark? leftShoulder;
  final GuideBodyLandmark? rightShoulder;
  final GuideBodyLandmark? leftHip;
  final GuideBodyLandmark? rightHip;
  final GuideBodyLandmark? leftKnee;
  final GuideBodyLandmark? rightKnee;
  final GuideBodyLandmark? leftAnkle;
  final GuideBodyLandmark? rightAnkle;
  final String? error;

  static const none = GuideBodyPose(detected: false);

  /// 이 값 아래면 "못 봤다"로 친다. 프로토타입 결과로 조정한다.
  static const visibilityThreshold = 0.5;

  /// 테스트·폴백용 3:4 프레임.
  static const referenceFrame = Size(360, 480);

  /// 데콜테 정적 목표 — 예전 얼굴 추정과 같은 화면 좌표·허용오차.
  static const decolleteGuideCenterX = 0.5;
  static const decolleteGuideCenterY = 0.38;
  static const decolleteTargetRadiusNorm = 0.40;
  static const decolleteCenterAlignTolerancePx = 15.0;
  static const decolleteScaleAlignToleranceRatio = 0.10;
  static const decolleteSnapPositionTolerancePx = 22.0;
  static const decolleteSnapScaleToleranceRatio = 0.14;

  /// 어깨 중점을 목 쪽으로 올리는 정규화 오프셋.
  static const decolleteNeckLiftNorm = 0.04;

  /// 어깨가 프레임 폭의 50%일 때 정적 링(0.40)과 크기가 같아진다.
  static const decolleteRingFromShoulderScale = 0.80;

  /// 라벨 붙은 지점 — 디버그 점 찍기와 통계에 쓴다.
  List<(String, GuideBodyLandmark)> get labeled => [
        if (leftShoulder != null) ('어깨L', leftShoulder!),
        if (rightShoulder != null) ('어깨R', rightShoulder!),
        if (leftHip != null) ('골반L', leftHip!),
        if (rightHip != null) ('골반R', rightHip!),
        if (leftKnee != null) ('무릎L', leftKnee!),
        if (rightKnee != null) ('무릎R', rightKnee!),
        if (leftAnkle != null) ('발목L', leftAnkle!),
        if (rightAnkle != null) ('발목R', rightAnkle!),
      ];

  /// 프리셋이 쓰는 지점이 전부 보이는지.
  bool hasPointsFor(GuideBodyTarget target) {
    if (!detected) return false;
    return switch (target) {
      GuideBodyTarget.decollete => _visible([leftShoulder, rightShoulder]),
      GuideBodyTarget.abdomen => _visible([
          leftShoulder,
          rightShoulder,
          leftHip,
          rightHip,
        ]),
      GuideBodyTarget.lowerBody => _visible([
          leftHip,
          rightHip,
          leftAnkle,
          rightAnkle,
        ]),
      GuideBodyTarget.fullBody => _visible([
          leftShoulder,
          rightShoulder,
          leftAnkle,
          rightAnkle,
        ]),
    };
  }

  /// 프리셋별 몸통 중심 (정규화). 지점이 모자라면 null.
  Offset? centerNorm(GuideBodyTarget target) {
    if (!hasPointsFor(target)) return null;
    final shoulder = _mid(leftShoulder, rightShoulder);
    final hip = _mid(leftHip, rightHip);
    final ankle = _mid(leftAnkle, rightAnkle);
    return switch (target) {
      // 어깨 중점, 목 쪽으로 살짝 위.
      GuideBodyTarget.decollete => shoulder == null
          ? null
          : Offset(
              shoulder.dx,
              (shoulder.dy - decolleteNeckLiftNorm).clamp(0.0, 1.0),
            ),
      // 어깨 중점과 골반 중점의 중간.
      GuideBodyTarget.abdomen => _between(shoulder, hip),
      // 골반 중점.
      GuideBodyTarget.lowerBody => hip,
      // 어깨 중점과 발목 중점의 중간.
      GuideBodyTarget.fullBody => _between(shoulder, ankle),
    };
  }

  /// 프리셋별 크기 기준 — 세로 거리(정규화). 거리(카메라와의 간격)의 대용값.
  double? scaleNorm(GuideBodyTarget target) {
    if (!hasPointsFor(target)) return null;
    final shoulder = _mid(leftShoulder, rightShoulder);
    final hip = _mid(leftHip, rightHip);
    final ankle = _mid(leftAnkle, rightAnkle);
    final span = switch (target) {
      GuideBodyTarget.decollete => _horizontal(leftShoulder, rightShoulder),
      GuideBodyTarget.abdomen => _vertical(shoulder, hip),
      GuideBodyTarget.lowerBody => _vertical(hip, ankle),
      GuideBodyTarget.fullBody => _vertical(shoulder, ankle),
    };
    if (span == null || span <= 0) return null;
    return span;
  }

  Offset? centerPx(
    GuideBodyTarget target,
    Size frameSize, {
    bool mirrored = false,
  }) {
    final c = centerNorm(target);
    if (c == null) return null;
    final nx = mirrored ? 1.0 - c.dx : c.dx;
    return Offset(nx * frameSize.width, c.dy * frameSize.height);
  }

  double? scalePx(GuideBodyTarget target, Size frameSize) {
    final s = scaleNorm(target);
    if (s == null) return null;
    if (target == GuideBodyTarget.decollete) {
      return s * frameSize.width;
    }
    return s * frameSize.height;
  }

  Offset decolleteTargetCenterPx(Size frameSize) => Offset(
        frameSize.width * decolleteGuideCenterX,
        frameSize.height * decolleteGuideCenterY,
      );

  double decolleteTargetRadiusPx(Size frameSize) =>
      math.min(frameSize.width, frameSize.height) * decolleteTargetRadiusNorm;

  /// 동적 링 반지름 — 어깨 폭으로 카메라 거리를 읽는다.
  double decolleteDynamicRadiusPx(Size frameSize) {
    final span = scalePx(GuideBodyTarget.decollete, frameSize);
    if (span == null || span <= 0) return 0;
    return span * decolleteRingFromShoulderScale;
  }

  bool isDecolletePositionAligned(Size frameSize, {bool mirrored = false}) {
    final center = centerPx(
      GuideBodyTarget.decollete,
      frameSize,
      mirrored: mirrored,
    );
    if (center == null) return false;
    return (center - decolleteTargetCenterPx(frameSize)).distance <=
        decolleteCenterAlignTolerancePx;
  }

  bool isDecolleteScaleAligned(Size frameSize) {
    final targetR = decolleteTargetRadiusPx(frameSize);
    final dynR = decolleteDynamicRadiusPx(frameSize);
    if (targetR <= 0 || dynR <= 0) return false;
    final err = (dynR - targetR).abs() / targetR;
    return err <= decolleteScaleAlignToleranceRatio;
  }

  bool computeDecolleteAligned(Size frameSize, {bool mirrored = false}) {
    return isDecolletePositionAligned(frameSize, mirrored: mirrored) &&
        isDecolleteScaleAligned(frameSize);
  }

  bool isDecolleteInSnapZone(Size frameSize, {bool mirrored = false}) {
    final center = centerPx(
      GuideBodyTarget.decollete,
      frameSize,
      mirrored: mirrored,
    );
    if (center == null) return false;
    final posOk = (center - decolleteTargetCenterPx(frameSize)).distance <=
        decolleteSnapPositionTolerancePx;
    final targetR = decolleteTargetRadiusPx(frameSize);
    final dynR = decolleteDynamicRadiusPx(frameSize);
    if (targetR <= 0 || dynR <= 0) return false;
    final scaleOk =
        ((dynR - targetR).abs() / targetR) <= decolleteSnapScaleToleranceRatio;
    return posOk && scaleOk;
  }

  int decolleteScaleDirection(Size frameSize) {
    final targetR = decolleteTargetRadiusPx(frameSize);
    final dynR = decolleteDynamicRadiusPx(frameSize);
    if (targetR <= 0 || dynR <= 0) return 0;
    final err = (dynR - targetR) / targetR;
    if (err > decolleteScaleAlignToleranceRatio) return -1;
    if (err < -decolleteScaleAlignToleranceRatio) return 1;
    return 0;
  }

  /// 어깨선 기울기(도). 좌우 대칭·수평 확인용.
  double? get shoulderTiltDegrees {
    final l = leftShoulder;
    final r = rightShoulder;
    if (l == null || r == null || !l.isVisible || !r.isVisible) return null;
    return math.atan2(r.y - l.y, r.x - l.x) * 180 / math.pi;
  }

  /// 보이는 지점들의 평균 visibility. 프로토타입 안정성 보고용.
  double get averageVisibility {
    final points = labeled;
    if (points.isEmpty) return 0;
    var sum = 0.0;
    for (final (_, p) in points) {
      sum += p.visibility;
    }
    return sum / points.length;
  }

  static bool _visible(List<GuideBodyLandmark?> points) {
    for (final p in points) {
      if (p == null || !p.isVisible) return false;
    }
    return true;
  }

  static Offset? _mid(GuideBodyLandmark? a, GuideBodyLandmark? b) {
    if (a == null || b == null) return null;
    return Offset((a.x + b.x) / 2, (a.y + b.y) / 2);
  }

  static Offset? _between(Offset? a, Offset? b) {
    if (a == null || b == null) return null;
    return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  }

  static double? _vertical(Offset? a, Offset? b) {
    if (a == null || b == null) return null;
    return (b.dy - a.dy).abs();
  }

  static double? _horizontal(GuideBodyLandmark? a, GuideBodyLandmark? b) {
    if (a == null || b == null) return null;
    return (a.x - b.x).abs();
  }
}

/// 웹 MediaPipe PoseLandmarker 세션. 네이티브는 no-op.
///
/// 얼굴 세션(`GuideFaceAlign`)과 완전히 별개다. 데콜테/복부/하체/전신
/// 프리셋을 고를 때만 [prepare]를 부른다 — 모델을 미리 받지 않는다.
abstract class GuideBodyAlign {
  Stream<GuideBodyPose> get poses;

  Future<void> prepare();
  Future<void> start(Object videoElement);
  Future<void> stop();
  void dispose();
}

GuideBodyAlign createGuideBodyAlign() => impl.createGuideBodyAlign();
