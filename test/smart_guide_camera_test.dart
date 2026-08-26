import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/guide_camera_session.dart';
import 'package:sori/services/guide_camera_zoom_memory.dart';
import 'package:sori/services/guide_face_align.dart';
import 'package:sori/views/smart_guide_camera_page.dart';

void main() {
  test('self presets are face and decollete only', () {
    expect(GuidePreset.face.isSelfPreset, isTrue);
    expect(GuidePreset.decollete.isSelfPreset, isTrue);
    expect(GuidePreset.abdomen.isSelfPreset, isFalse);
    expect(GuidePreset.fullBody.label, '전신');
  });

  test('face preset uses MediaPipe align', () {
    expect(GuidePreset.face.usesFaceAlign, isTrue);
    expect(GuidePreset.decollete.usesFaceAlign, isFalse);
    expect(GuidePreset.abdomen.usesFaceAlign, isFalse);
  });

  test('guide camera uses fixed 3:4 aspect', () {
    expect(kGuideCameraAspectRatio, closeTo(0.75, 0.001));
  });

  test('zoom memory clamps range', () {
    expect(GuideCameraZoomMemory.defaultZoom, inInclusiveRange(1.0, 2.6));
    expect(GuideCameraZoomMemory.minZoom, lessThan(GuideCameraZoomMemory.maxZoom));
  });

  test('face pose alignment requires position and scale match', () {
    const frame = GuideFacePose.referenceFrame;
    const targetR = GuideFacePose.innerTargetRadiusNorm;

    expect(
      const GuideFacePose(
        detected: true,
        inCircle: true,
        pitch: 0,
        yaw: 0,
        roll: 0,
        centerX: 0.5,
        centerY: 0.46,
        faceRadius: targetR,
      ).computeAligned(frame),
      isTrue,
    );
    expect(
      const GuideFacePose(
        detected: true,
        inCircle: true,
        pitch: 0,
        yaw: 0,
        roll: 0,
        centerX: 0.62,
        centerY: 0.46,
        faceRadius: targetR,
      ).isPositionAligned(frame),
      isFalse,
      reason: 'center offset beyond 15px must not align',
    );
    expect(
      const GuideFacePose(
        detected: true,
        inCircle: true,
        pitch: 0,
        yaw: 0,
        roll: 0,
        centerX: 0.5,
        centerY: 0.46,
        faceRadius: targetR * 1.25,
      ).isScaleAligned(frame),
      isFalse,
      reason: 'face too large (too close) must not align',
    );
    expect(GuideFacePose.none.isAligned, isFalse);
  });
}
