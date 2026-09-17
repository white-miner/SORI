import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/views/smart_guide_camera_page.dart';

void main() {
  test('다섯 모드는 같은 실루엣에서 다른 구간만 강조한다', () {
    expect(GuidePreset.face.highlightZoneY, (2, 40));
    expect(GuidePreset.decollete.highlightZoneY, (30, 72));
    expect(GuidePreset.abdomen.highlightZoneY, (44, 100));
    expect(GuidePreset.lowerBody.highlightZoneY, (99, 158));
    expect(GuidePreset.fullBody.highlightZoneY, (2, 158));
  });

  test('데콜테 강조는 얼굴 구간과 겹치지 않고 목~어깨만 덮는다', () {
    final face = GuidePreset.face.highlightZoneY;
    final decollete = GuidePreset.decollete.highlightZoneY;
    expect(decollete.$1, greaterThan(face.$1));
    expect(decollete.$2, lessThan(GuidePreset.abdomen.highlightZoneY.$2));
  });

  testWidgets('프리셋 아이콘은 Material 아이콘이 아니라 실루엣 페인터다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              GuidePresetZoneIcon(preset: GuidePreset.face, selected: true),
              GuidePresetZoneIcon(
                preset: GuidePreset.decollete,
                selected: false,
              ),
              GuidePresetZoneIcon(preset: GuidePreset.fullBody, selected: false),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(GuidePresetZoneIcon), findsNWidgets(3));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byIcon(Icons.portrait), findsNothing);
    expect(find.byIcon(Icons.accessibility_new), findsNothing);
  });
}
