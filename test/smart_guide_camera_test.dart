import 'package:flutter_test/flutter_test.dart';
import 'package:sori/views/smart_guide_camera_page.dart';

void main() {
  test('self presets are face and decollete only', () {
    expect(GuidePreset.face.isSelfPreset, isTrue);
    expect(GuidePreset.decollete.isSelfPreset, isTrue);
    expect(GuidePreset.abdomen.isSelfPreset, isFalse);
    expect(GuidePreset.fullBody.label, '전신');
  });

  test('guide camera kinds distinguish before/after', () {
    expect(GuideCameraKind.before.name, 'before');
    expect(GuideCameraKind.after.name, 'after');
  });
}
