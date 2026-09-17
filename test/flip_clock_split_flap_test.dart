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
    final corners = tester.widgetList<Text>(
      find.byKey(const Key('dark-glass-corner-digit')),
    );
    expect(corners, isNotEmpty);
    for (final text in corners) {
      expect(text.style?.fontWeight, kDarkGlassDigitWeight);
    }
    expect(kDarkGlassDigitWeight, FontWeight.w700);
  });

  testWidgets('힌지 라인은 3px 두께다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlipClockDisplay(
            totalSeconds: 65,
            style: FlipClockStyle.darkGlass,
          ),
        ),
      ),
    );

    final hinges = tester.widgetList<Container>(
      find.byKey(const Key('split-flap-hinge')),
    );
    expect(hinges, isNotEmpty);
    for (final hinge in hinges) {
      expect(hinge.constraints?.maxHeight, kSplitFlapHingeThickness);
    }
    expect(kSplitFlapHingeThickness, 3.0);
  });

  testWidgets('절반을 넘기기 전에는 새 숫자가 아래 카드에 미리 보이지 않는다', (tester) async {
    Widget clock(int seconds) => MaterialApp(
          home: Scaffold(
            body: FlipClockDisplay(
              totalSeconds: seconds,
              style: FlipClockStyle.darkGlass,
              showSeconds: true,
            ),
          ),
        );

    await tester.pumpWidget(clock(0));
    expect(find.text('1'), findsNothing);

    await tester.pumpWidget(clock(1));
    // t < 0.5 — 위·아래·플랩이 모두 이전 숫자라 겹쳐 보이지 않는다.
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('1'), findsNothing);

    // t > 0.5 — 아래 카드와 플랩이 함께 새 숫자로 넘어간다.
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('1'), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('구석 초도 같은 스플릿플랩으로 접힌다', (tester) async {
    Widget clock(int seconds) => MaterialApp(
          home: Scaffold(
            body: FlipClockDisplay(
              totalSeconds: seconds,
              style: FlipClockStyle.darkGlass,
              showCornerSeconds: true,
            ),
          ),
        );

    await tester.pumpWidget(clock(65));
    expect(find.byKey(const Key('split-flap-leaf')), findsNothing);

    // 분은 그대로고 초만 바뀐다 → 접히는 건 구석 초 타일뿐이다.
    await tester.pumpWidget(clock(66));
    await tester.pump(const Duration(milliseconds: 210));

    final leaf = tester.widget<Transform>(find.byKey(const Key('split-flap-leaf')));
    expect(leaf.transform.storage[5].abs(), lessThan(0.2));

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('split-flap-leaf')), findsNothing);
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
