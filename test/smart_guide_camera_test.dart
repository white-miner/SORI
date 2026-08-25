import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/guide_camera_session.dart';
import 'package:sori/views/smart_guide_camera_page.dart';

void main() {
  test('self presets are face and decollete only', () {
    expect(GuidePreset.face.isSelfPreset, isTrue);
    expect(GuidePreset.decollete.isSelfPreset, isTrue);
    expect(GuidePreset.abdomen.isSelfPreset, isFalse);
    expect(GuidePreset.fullBody.label, '전신');
  });

  test('preset target zoom favors portrait FOV at ~1m', () {
    expect(GuidePreset.face.targetZoom, greaterThanOrEqualTo(1.5));
    expect(GuidePreset.face.targetZoom, lessThanOrEqualTo(2.0));
    expect(GuidePreset.decollete.targetZoom, lessThan(GuidePreset.face.targetZoom));
    expect(GuidePreset.fullBody.targetZoom, lessThan(GuidePreset.decollete.targetZoom));
  });

  test('guide camera uses fixed 3:4 aspect', () {
    expect(kGuideCameraAspectRatio, closeTo(0.75, 0.001));
  });
}