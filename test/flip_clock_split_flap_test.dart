import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/operation/widgets/flip_clock_display.dart';

void main() {
  testWidgets('다크 글래스 메인 숫자와 구석 초는 같은 굵기(w700)다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlipClockDisplay(
            totalSeconds: 65,
            style: FlipClockStyle.darkGlass,
            showCornerSeconds: true,
          ),
        ),
      ),
    );

    final mains = tester.widgetList<Text>(find.byKey(const Key('dark-glass-digit')));
    expect(mains, isNotEmpty);
    for (final text in mains) {
      expect(text.style?.fontWeight, kDarkGlassDigitWeight);
    }
    final corner = tester.widget<Text>(find.byKey(const Key('dark-glass-corner-digit')));
    expect(corner.style?.fontWeight, kDarkGlassDigitWeight);
    expect(kDarkGlassDigitWeight, FontWeight.w700);
  });

  testWidgets('숫자가 바뀌면 50% 지점에서 윗조각이 접혀 있고 끝나면 새 숫자로 고정된다',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlipClockDisplay(
            totalSeconds: 0,
            style: FlipClockStyle.darkGlass,
            showSeconds: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('split-flap-leaf')), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlipClockDisplay(
            totalSeconds: 1,
            style: FlipClockStyle.darkGlass,
            showSeconds: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 210));

    final leaf = tester.widget<Transform>(find.byKey(const Key('split-flap-leaf')));
    // rotateX(90°)면 cos≈0 — 옆에서 보여 폭이 사라진다.
    expect(leaf.transform.storage[5].abs(), lessThan(0.2));

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('split-flap-leaf')), findsNothing);
    expect(find.text('1'), findsWidgets);
  });
}
