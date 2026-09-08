import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/widgets/floating_pill_nav.dart';
import 'package:sori/widgets/glass/sori_glass_overlay.dart';
import 'package:sori/widgets/glass/sori_glass_tokens.dart';

void main() {
  Future<void> pumpNav(WidgetTester tester, {required int index}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: FloatingPillNav(
            currentIndex: index,
            isDirector: true,
            reviewLabel: '리뷰',
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('탭바는 모달보다 투명해 뒤가 비친다', (tester) async {
    await pumpNav(tester, index: 0);

    final overlay = tester.widget<SoriGlassOverlay>(
      find.byType(SoriGlassOverlay),
    );
    expect(overlay.fill, SoriGlassTokens.navBarFill());
    expect(overlay.fill!.a, lessThan(0.7));
    // 모달 등 공용 값은 그대로 둔다.
    expect(SoriGlassTokens.fillColor(SoriGlassTier.l3Overlay).a, 0.82);
  });

  testWidgets('선택 알약은 가짜 그라데이션이 아니라 실제 블러다', (tester) async {
    await pumpNav(tester, index: 0);

    final highlight = find.byKey(const Key('nav-glass-highlight'));
    expect(highlight, findsOneWidget);
    expect(
      find.descendant(of: highlight, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
  });

  test('선택 알약 그림자는 짧아 탭바 가장자리에서 잘리지 않는다', () {
    final shadow = SoriGlassTokens.navHighlightDecoration(radius: 24)
        .boxShadow!
        .single;
    expect(shadow.blurRadius, lessThanOrEqualTo(16));
    expect(shadow.offset.dy, lessThanOrEqualTo(4));
  });

  testWidgets('탭을 바꾸면 알약이 부풀었다 제자리로 돌아온다', (tester) async {
    await pumpNav(tester, index: 0);

    double pillScale() {
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byKey(const Key('nav-glass-highlight')),
              matching: find.byType(Transform),
            )
            .first,
      );
      return transform.transform.storage[0];
    }

    expect(pillScale(), closeTo(1, 0.001));

    final bar = tester.getRect(find.byType(FloatingPillNav));
    await tester.tapAt(Offset(bar.left + bar.width * 0.7, bar.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(pillScale(), greaterThan(1.02));

    await tester.pumpAndSettle();
    expect(pillScale(), closeTo(1, 0.001));
  });
}
