import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/sori_shell_insets.dart';

/// 플립 시계가 반복 타이머를 돌리므로 pumpAndSettle은 쓰지 않는다.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _openTimerTab(WidgetTester tester) async {
  await tester.tap(find.text('타이머').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    if (find.byKey(const Key('home-timer-stage')).evaluate().isNotEmpty) {
      break;
    }
  }
  expect(find.byKey(const Key('home-timer-stage')), findsOneWidget);
}

Finder _bindSwitch() {
  final bind = find.byKey(const Key('home-timer-customer-bind'));
  final material = find.descendant(of: bind, matching: find.byType(Switch));
  if (material.evaluate().isNotEmpty) return material;
  return find.descendant(of: bind, matching: find.byType(CupertinoSwitch));
}

Finder _timerSpacer() {
  return find.byKey(
    const Key('home-timer-scroll-bottom-inset'),
    skipOffstage: false,
  );
}

SizedBox _timerSpacerBox(WidgetTester tester) {
  final sliver = tester.widget<SliverToBoxAdapter>(_timerSpacer());
  return sliver.child! as SizedBox;
}

double _scrollPixels(WidgetTester tester) {
  final ctx = tester.element(
    find.byKey(const Key('home-timer-customer-bind')),
  );
  return Scrollable.of(ctx).position.pixels;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('mobile pill nav inset = 64+12+viewPadding+20, no viewInsets', (
    tester,
  ) async {
    late double inset;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewPadding: EdgeInsets.only(bottom: 34),
          padding: EdgeInsets.only(bottom: 34),
          viewInsets: EdgeInsets.only(bottom: 280),
        ),
        child: SoriShellInsetScope(
          pillNavVisible: true,
          child: Builder(
            builder: (context) {
              inset = SoriShellInsets.scrollBottomInset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(inset, 64 + 12 + 34 + 20);
    expect(inset, isNot(64 + 12 + 34 + 20 + 280));
  });

  testWidgets('desktop pill nav occupancy is 0', (tester) async {
    late double scoped;
    late double fallback;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1024, 800)),
        child: Column(
          children: [
            SoriShellInsetScope(
              pillNavVisible: false,
              child: Builder(
                builder: (context) {
                  scoped = SoriShellInsets.scrollBottomInset(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
            Builder(
              builder: (context) {
                fallback = SoriShellInsets.scrollBottomInset(context);
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );

    expect(scoped, 0);
    expect(fallback, 0);
  });

  testWidgets('Timer last spacer uses SSOT inset including viewPadding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              size: const Size(390, 844),
              viewPadding: const EdgeInsets.only(bottom: 34),
              padding: const EdgeInsets.only(bottom: 34),
            ),
            child: child!,
          );
        },
        home: Scaffold(body: VisitLauncherPage(store: store)),
      ),
    );
    await _settle(tester);
    await _openTimerTab(tester);

    expect(_timerSpacerBox(tester).height, 64 + 12 + 34 + 20);
  });

  testWidgets('desktop Timer spacer occupancy is 0', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisitLauncherPage(store: store)),
      ),
    );
    await _settle(tester);
    await _openTimerTab(tester);

    expect(_timerSpacerBox(tester).height, 0);
  });

  testWidgets(
    'Switch On expands customer bind form, reveals it, and does not open keyboard',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = SoriStore();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VisitLauncherPage(store: store))),
      );
      await _settle(tester);
      await _openTimerTab(tester);

      expect(find.byKey(const Key('home-timer-customer-add')), findsNothing);

      final sw = _bindSwitch();
      await tester.ensureVisible(sw);
      await tester.pump();
      await tester.tap(sw);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump(const Duration(milliseconds: 40));

      expect(find.byKey(const Key('home-timer-customer-add')), findsOneWidget);
      expect(find.text('차트 / 이름'), findsOneWidget);
      expect(find.text('연락처'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byType(EditableText), findsNothing);

      final addRect = tester.getRect(
        find.byKey(const Key('home-timer-customer-add')),
      );
      expect(addRect.top, greaterThanOrEqualTo(-0.5));
      expect(addRect.bottom, lessThanOrEqualTo(932.5));
    },
  );

  testWidgets('Switch Off does not reveal or keep the form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = SoriStore();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: VisitLauncherPage(store: store))),
    );
    await _settle(tester);
    await _openTimerTab(tester);

    final sw = _bindSwitch();
    await tester.tap(sw);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.byKey(const Key('home-timer-customer-add')), findsOneWidget);

    final beforeOff = _scrollPixels(tester);
    await tester.tap(sw);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.byKey(const Key('home-timer-customer-add')), findsNothing);
    expect(_scrollPixels(tester), beforeOff);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
