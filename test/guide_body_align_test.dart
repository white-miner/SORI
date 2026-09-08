import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/guide_body_align.dart';

GuideBodyLandmark lm(double x, double y, [double v = 0.95]) =>
    GuideBodyLandmark(x: x, y: y, visibility: v);

/// 정면으로 선 사람 — 어깨 y=0.2, 골반 y=0.5, 무릎 y=0.7, 발목 y=0.9.
GuideBodyPose standing({double visibility = 0.95}) => GuideBodyPose(
      detected: true,
      leftShoulder: lm(0.4, 0.2, visibility),
      rightShoulder: lm(0.6, 0.2, visibility),
      leftHip: lm(0.44, 0.5, visibility),
      rightHip: lm(0.56, 0.5, visibility),
      leftKnee: lm(0.45, 0.7, visibility),
      rightKnee: lm(0.55, 0.7, visibility),
      leftAnkle: lm(0.46, 0.9, visibility),
      rightAnkle: lm(0.54, 0.9, visibility),
    );

void main() {
  const frame = GuideBodyPose.referenceFrame; // 360 x 480

  group('프리셋별 중심', () {
    test('복부는 어깨 중점과 골반 중점의 중간', () {
      final c = standing().centerNorm(GuideBodyTarget.abdomen)!;
      expect(c.dx, closeTo(0.5, 0.001));
      expect(c.dy, closeTo(0.35, 0.001));
    });

    test('하체는 골반 중점', () {
      final c = standing().centerNorm(GuideBodyTarget.lowerBody)!;
      expect(c.dy, closeTo(0.5, 0.001));
    });

    test('전신은 어깨 중점과 발목 중점의 중간', () {
      final c = standing().centerNorm(GuideBodyTarget.fullBody)!;
      expect(c.dy, closeTo(0.55, 0.001));
    });
  });

  group('프리셋별 크기 기준(세로 거리)', () {
    test('복부는 어깨~골반, 하체는 골반~발목, 전신은 어깨~발목', () {
      final pose = standing();
      expect(pose.scaleNorm(GuideBodyTarget.abdomen), closeTo(0.30, 0.001));
      expect(pose.scaleNorm(GuideBodyTarget.lowerBody), closeTo(0.40, 0.001));
      expect(pose.scaleNorm(GuideBodyTarget.fullBody), closeTo(0.70, 0.001));
    });

    test('픽셀 크기는 프레임 높이에 비례한다 — 멀어지면 작아진다', () {
      expect(
        standing().scalePx(GuideBodyTarget.fullBody, frame),
        closeTo(0.70 * frame.height, 0.5),
      );
    });
  });

  test('전면 카메라는 좌우를 뒤집어 그린다', () {
    final pose = GuideBodyPose(
      detected: true,
      leftShoulder: lm(0.3, 0.2),
      rightShoulder: lm(0.5, 0.2),
      leftAnkle: lm(0.3, 0.9),
      rightAnkle: lm(0.5, 0.9),
    );
    final plain = pose.centerPx(GuideBodyTarget.fullBody, frame)!;
    final mirrored =
        pose.centerPx(GuideBodyTarget.fullBody, frame, mirrored: true)!;
    expect(plain.dx + mirrored.dx, closeTo(frame.width, 0.5));
    expect(plain.dy, closeTo(mirrored.dy, 0.001));
  });

  group('지점이 모자라면 판정하지 않는다', () {
    test('가려져 신뢰도가 낮으면 좌표를 내지 않는다', () {
      final dim = standing(visibility: 0.2);
      expect(dim.hasPointsFor(GuideBodyTarget.fullBody), isFalse);
      expect(dim.centerNorm(GuideBodyTarget.fullBody), isNull);
      expect(dim.scaleNorm(GuideBodyTarget.fullBody), isNull);
    });

    test('발목이 없으면 전신·하체는 못 쓰고 복부는 쓴다', () {
      final noAnkle = GuideBodyPose(
        detected: true,
        leftShoulder: lm(0.4, 0.2),
        rightShoulder: lm(0.6, 0.2),
        leftHip: lm(0.44, 0.5),
        rightHip: lm(0.56, 0.5),
      );
      expect(noAnkle.hasPointsFor(GuideBodyTarget.abdomen), isTrue);
      expect(noAnkle.hasPointsFor(GuideBodyTarget.lowerBody), isFalse);
      expect(noAnkle.hasPointsFor(GuideBodyTarget.fullBody), isFalse);
    });

    test('사람을 못 찾으면 전부 null', () {
      expect(GuideBodyPose.none.hasPointsFor(GuideBodyTarget.fullBody), isFalse);
      expect(GuideBodyPose.none.centerNorm(GuideBodyTarget.abdomen), isNull);
    });
  });

  test('어깨 기울기는 좌우 높이 차이로 나온다', () {
    final tilted = GuideBodyPose(
      detected: true,
      leftShoulder: lm(0.4, 0.20),
      rightShoulder: lm(0.6, 0.25),
    );
    expect(tilted.shoulderTiltDegrees, isNotNull);
    expect(tilted.shoulderTiltDegrees!, greaterThan(0));
    expect(standing().shoulderTiltDegrees, closeTo(0, 0.001));
  });

  test('네이티브/테스트 환경에서는 no-op 세션이 나온다', () async {
    final align = createGuideBodyAlign();
    await align.prepare();
    await align.start(Object());
    await align.stop();
    align.dispose();
    expect(align.poses, isA<Stream<GuideBodyPose>>());
  });

  test('라벨 목록은 보이는 지점만 담는다', () {
    expect(standing().labeled.length, 8);
    expect(
      const GuideBodyPose(detected: true, leftShoulder: null).labeled,
      isEmpty,
    );
  });

  test('평균 신뢰도는 지점들의 평균이다', () {
    expect(standing(visibility: 0.8).averageVisibility, closeTo(0.8, 0.001));
    expect(GuideBodyPose.none.averageVisibility, 0);
  });

  test('참조 프레임은 카메라와 같은 3:4다', () {
    expect(
      GuideBodyPose.referenceFrame.width / GuideBodyPose.referenceFrame.height,
      closeTo(0.75, 0.001),
    );
    expect(GuideBodyPose.referenceFrame, isA<Size>());
  });

  group('데콜테는 어깨 두 점만 쓴다', () {
    test('중심은 좌우 어깨 중점이다', () {
      final c = standing().centerNorm(GuideBodyTarget.decollete)!;
      expect(c.dx, closeTo(0.5, 0.001));
      expect(c.dy, closeTo(0.2, 0.001));
    });

    test('크기는 좌우 어깨 가로 거리이다', () {
      expect(
        standing().scaleNorm(GuideBodyTarget.decollete),
        closeTo(0.2, 0.001),
      );
    });

    test('어깨만 있으면 데콜테는 쓰고 전신은 못 쓴다', () {
      final shoulders = GuideBodyPose(
        detected: true,
        leftShoulder: lm(0.4, 0.2),
        rightShoulder: lm(0.6, 0.2),
      );
      expect(shoulders.hasPointsFor(GuideBodyTarget.decollete), isTrue);
      expect(shoulders.hasPointsFor(GuideBodyTarget.fullBody), isFalse);
    });

    test('어깨가 안 보이면 데콜테 점을 찍지 않는다', () {
      expect(
        GuideBodyPose.none.hasPointsFor(GuideBodyTarget.decollete),
        isFalse,
      );
    });
  });
}
