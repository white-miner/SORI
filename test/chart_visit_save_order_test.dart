import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sori/features/chart_visit/chart_visit_flow_page.dart';
import 'package:sori/features/chart_visit/chart_visit_mock.dart';

class Probe implements ChartVisitGateway {
  Completer<void>? hold;
  final writes = <String>[];
  final allergies = <String>[];
  bool started = false;
  bool failDraft = false;
  bool failComplete = false;
  int completionCalls = 0;
  @override
  Future<ChartVisitSession> startFresh({bool forceNew = false}) =>
      throw UnimplementedError();
  @override
  Future<ChartVisitSession> resumeLatest(
    ChartVisitDraftRef draft, {
    bool refillDefaultSteps = true,
  }) => throw UnimplementedError();
  @override
  Future<void> saveDraft(ChartVisitSession session) async {
    started = true;
    allergies.add(session.safety.allergy);
    await hold?.future;
    if (failDraft) throw StateError('offline');
    writes.add('draft');
  }

  @override
  Future<void> complete(ChartVisitSession session) async {
    completionCalls++;
    if (failComplete) throw StateError('offline');
    writes.add('completed');
  }
}

void main() {
  final store = ChartVisitPreviewStore.instance;
  Future<void> open(WidgetTester t, Probe gate) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    store.debugResetForTest();
    store.bindLive(
      nextCustomer: store.customer,
      nextHistory: [],
      nextDrafts: [],
      nextGateway: gate,
      customerId: 'qa',
    );
    store.active = ChartVisitSession.fresh(
      id: 'qa-visit',
      startedAt: DateTime.now(),
      safety: const SafetySnapshot(),
    );
    final router = GoRouter(
      initialLocation: '/write',
      routes: [
        GoRoute(path: '/write', builder: (_, _) => const ChartVisitFlowPage()),
        GoRoute(
          path: '/app/customers/:id',
          builder: (_, _) => const Scaffold(body: Text('returned')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
  }

  Future<void> edit(WidgetTester t) async {
    await t.tap(find.byKey(const Key('chart-visit-safety-edit')));
    await t.pumpAndSettle();
    final none = find.text('없음').first;
    await t.ensureVisible(none);
    await t.pumpAndSettle();
    await t.tap(none);
    await t.pump(const Duration(milliseconds: 700));
    await t.pump();
  }

  Future<void> finish(WidgetTester t) async {
    for (var i = 0; i < 5; i++) {
      await t.tap(find.byKey(const Key('chart-visit-next')));
      await t.pumpAndSettle();
    }
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    store.debugResetForTest();
  }

  testWidgets('completion waits for autosave and cannot be tapped twice', (
    t,
  ) async {
    final gate = Probe()..hold = Completer<void>();
    await open(t, gate);
    await edit(t);
    expect(gate.started, isTrue);
    await finish(t);
    expect(find.byKey(const Key('chart-visit-to-home')), findsNothing);
    expect(gate.completionCalls, 0);
    expect(find.text('저장 중...'), findsNWidgets(2));
    await t.tap(find.byKey(const Key('chart-visit-next')), warnIfMissed: false);
    gate.hold!.complete();
    await t.pumpAndSettle();
    expect(gate.writes, ['draft', 'completed']);
    expect(gate.completionCalls, 1);
    expect(find.text('권장 시점 미기록'), findsOneWidget);
    expect(find.byKey(const Key('chart-visit-to-home')), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(gate.writes, ['draft', 'completed']);
    await t.tap(find.byKey(const Key('chart-visit-to-home')));
    await t.pumpAndSettle();
    expect(find.text('returned'), findsOneWidget);
    expect(gate.completionCalls, 1);
    await close(t);
  });

  testWidgets('completion flushes a debounce that has not fired', (t) async {
    final gate = Probe()..hold = Completer<void>();
    await open(t, gate);
    await t.tap(find.byKey(const Key('chart-visit-safety-edit')));
    await t.pumpAndSettle();
    final no = find.text('없음').first;
    await t.ensureVisible(no);
    await t.pumpAndSettle();
    await t.tap(no);
    await t.pump();
    expect(gate.started, isFalse);
    for (var i = 0; i < 5; i++) {
      await t.tap(find.byKey(const Key('chart-visit-next')));
      await t.pump();
    }
    expect(gate.started, isTrue);
    expect(gate.completionCalls, 0);
    gate.hold!.complete();
    await t.pumpAndSettle();
    expect(gate.writes, ['draft', 'completed']);
    await t.pump(const Duration(seconds: 2));
    expect(gate.writes, ['draft', 'completed']);
    await close(t);
  });

  for (final systemBack in [false, true]) {
    testWidgets('leaving flushes pending input: systemBack=$systemBack', (t) async {
      final gate = Probe()..hold = Completer<void>();
      await open(t, gate);
      await t.tap(find.byKey(const Key('chart-visit-safety-edit')));
      await t.pumpAndSettle();
      final no = find.text('없음').first;
      await t.ensureVisible(no);
      await t.pumpAndSettle();
      await t.tap(no);
      await t.pump();
      expect(gate.started, isFalse);
      if (systemBack) {
        unawaited(t.state<NavigatorState>(find.byType(Navigator).last).maybePop());
      } else {
        await t.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      }
      await t.pump();
      expect(gate.started, isTrue);
      expect(find.byKey(const Key('chart-visit-flow')), findsOneWidget);
      gate.hold!.complete();
      await t.pumpAndSettle();
      expect(gate.writes, ['draft']);
      expect(gate.completionCalls, 0);
      expect(find.text('returned'), findsOneWidget);
      await close(t);
    });
  }

  testWidgets('failed exit save keeps the form and retries before leaving', (t) async {
    final gate = Probe()..failDraft = true;
    await open(t, gate);
    await edit(t);
    await t.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('chart-visit-flow')), findsOneWidget);
    expect(store.active!.safety.allergy, '없음');
    expect(find.text('returned'), findsNothing);
    gate.failDraft = false;
    await t.tap(find.text('다시 시도'));
    await t.pumpAndSettle();
    expect(gate.writes, ['draft']);
    expect(find.text('returned'), findsOneWidget);
    await close(t);
  });

  testWidgets(
    'edits during a delayed save are drained from separate snapshots',
    (t) async {
      final gate = Probe()..hold = Completer<void>();
      await open(t, gate);
      await edit(t);
      // Use its ChoiceChip ancestor so the read-only facts cannot be tapped.
      final chips = find.widgetWithText(ChartVisitChoiceChip, '미확인');
      expect(chips, findsWidgets);
      await t.ensureVisible(chips.first);
      await t.tap(chips.first);
      await t.pump(const Duration(milliseconds: 700));
      expect(gate.allergies, ['없음']);
      gate.hold!.complete();
      await t.pumpAndSettle();
      expect(gate.allergies, ['없음', '']);
      expect(store.active!.safety.allergy, isEmpty);
      expect(gate.writes, ['draft', 'draft']);
      expect(find.text('저장됨'), findsOneWidget);
      await close(t);
    },
  );

  for (final failDraft in [true, false]) {
    testWidgets(
      '${failDraft ? "draft" : "completion"} failure retains input and permits retry',
      (t) async {
        final gate = Probe()
          ..failDraft = failDraft
          ..failComplete = !failDraft;
        await open(t, gate);
        await edit(t);
        await finish(t);
        expect(find.byKey(const Key('chart-visit-to-home')), findsNothing);
        expect(store.active!.safety.allergy, '없음');
        expect(find.text('저장 실패'), findsOneWidget);
        if (failDraft) expect(gate.completionCalls, 0);
        gate.failDraft = false;
        gate.failComplete = false;
        await t.tap(find.text('다시 시도'));
        await t.pumpAndSettle();
        expect(gate.writes.last, 'completed');
        expect(find.byKey(const Key('chart-visit-to-home')), findsOneWidget);
        await close(t);
      },
    );
  }
}
