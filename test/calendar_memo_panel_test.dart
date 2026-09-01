import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/features/visit/widgets/calendar_memo_panel.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  late SoriStore store;

  setUp(() async {
    store = SoriStore.instance;
    await store.bootstrap(repository: MemorySoriRepository());
  });

  testWidgets('expands and switches month/week/day modes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalendarMemoPanel(store: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('캘린더 메모'), findsOneWidget);
    expect(find.byType(SegmentedButton<CalendarMemoViewMode>), findsNothing);

    await tester.tap(find.text('캘린더 메모'));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<CalendarMemoViewMode>), findsOneWidget);
    expect(find.text('메모 추가'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<CalendarMemoViewMode>),
        matching: find.text('월'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('년'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<CalendarMemoViewMode>),
        matching: find.text('주'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('화'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<CalendarMemoViewMode>),
        matching: find.text('일'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('메모 추가'), findsOneWidget);
  });
}
