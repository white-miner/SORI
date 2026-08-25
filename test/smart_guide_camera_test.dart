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

  test('face/decollete use MediaPipe align', () {
    expect(GuidePreset.face.usesFaceAlign, isTrue);
    expect(GuidePreset.decollete.usesFaceAlign, isTrue);
    expect(GuidePreset.abdomen.usesFaceAlign, isFalse);
  });

  test('guide camera uses fixed 3:4 aspect', () {
    expect(kGuideCameraAspectRatio, closeTo(0.75, 0.001));
  });

  test('zoom memory clamps range', () {
    expect(GuideCameraZoomMemory.defaultZoom, inInclusiveRange(1.0, 2.6));
    expect(GuideCameraZoomMemory.minZoom, lessThan(GuideCameraZoomMemory.maxZoom));
  });

  test('face pose alignment requires inCircle + pose tolerance', () {
    expect(
      const GuideFacePose(
        detected: true,
        inCircle: true,
        pitch: 3,
        yaw: -4,
        roll: 2,
      ).isAligned,
      isTrue,
    );
    expect(
      const GuideFacePose(
        detected: true,
        inCircle: false,
        pitch: 0,
        yaw: 0,
        roll: 0,
      ).isAligned,
      isFalse,
      reason: 'face outside circle must not align',
    );
    expect(
      const GuideFacePose(
        detected: true,
        inCircle: true,
        pitch: 20,
        yaw: 0,
        roll: 0,
      ).isAligned,
      isFalse,
    );
    expect(GuideFacePose.none.isAligned, isFalse);
  });
}
