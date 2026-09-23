import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/home_visual_tokens.dart';
import 'package:sori/features/visit/widgets/ba_capture_carousel.dart';
import 'package:sori/models/ba_capture_session.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/shoot_inbox_item.dart';
import 'package:sori/services/chart_photo_storage.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/consent_publish_gate.dart';

const _unboundUrl =
    'https://example.supabase.co/storage/v1/object/public/chart_photos/shop1/unbound/abc_1_before.webp';

const _draftUrl =
    'https://example.supabase.co/storage/v1/object/public/chart_photos/shop1/ba_draft_tok/xyz_1_before.webp';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> removedPaths;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    removedPaths = <String>[];
    ChartPhotoStorage.debugRemoveHandler = (path) async {
      removedPaths.add(path);
      return true;
    };
  });

  tearDown(() {
    ChartPhotoStorage.debugRemoveHandler = null;
  });

  group('D02-1 characterization — 교체 경로는 큐만', () {
    test('dismissShootInboxItem does not call Storage remove', () async {
      final store = SoriStore();
      await store.enqueueShootInboxItem(
        ShootInboxItem(
          id: 'inbox-1',
          shopId: store.shop.id,
          kind: 'after',
          imageUrl: _unboundUrl,
          sessionToken: 'sess-a',
        ),
      );

      await store.dismissShootInboxItem('inbox-1');

      expect(removedPaths, isEmpty);
      expect(store.shootInbox, isEmpty);
    });
  });

  group('D02-1 staging discard', () {
    test('1. unbound ShootHub URL + 차트 미참조 → remove 1 + queue 제거', () async {
      final store = SoriStore();
      await store.enqueueShootInboxItem(
        ShootInboxItem(
          id: 'inbox-u',
          shopId: store.shop.id,
          kind: 'before',
          imageUrl: _unboundUrl,
          sessionToken: 'sess-u',
        ),
      );

      final result = await store.discardUnlinkedShootInboxItems(['inbox-u']);

      expect(result.discarded, isTrue);
      expect(result.storageRemoveCount, 1);
      expect(removedPaths, ['shop1/unbound/abc_1_before.webp']);
      expect(store.shootInbox.where((e) => e.id == 'inbox-u'), isEmpty);
    });

    test('2b. Before만 삭제하면 After는 남고 Storage는 Before만 지운다', () async {
      final store = SoriStore();
      const afterUrl =
          'https://example.supabase.co/storage/v1/object/public/chart_photos/shop1/ba_draft_tok/xyz_1_after.webp';
      const session = BaCaptureSession(
        id: 'ba-draft-pair',
        shopId: 'shop1',
        sessionToken: 'tok-pair',
        beforeImageUrl: _draftUrl,
        afterImageUrl: afterUrl,
        status: BaCaptureStatus.draft,
      );
      store.baSessions.add(session);

      final result = await store.discardUnlinkedBaSlot(
        target: session,
        kind: 'before',
      );

      expect(result.discarded, isTrue);
      expect(result.storageRemoveCount, 1);
      expect(removedPaths, ['shop1/ba_draft_tok/xyz_1_before.webp']);
      final kept = store.baSessions.singleWhere((s) => s.id == 'ba-draft-pair');
      expect(kept.beforeImageUrl, isNull);
      expect(kept.afterImageUrl, afterUrl);
    });

    test('2c. 마지막 슬롯 삭제 시 세션 메타도 제거한다', () async {
      final store = SoriStore();
      const session = BaCaptureSession(
        id: 'ba-draft-one',
        shopId: 'shop1',
        sessionToken: 'tok-one',
        beforeImageUrl: _draftUrl,
        status: BaCaptureStatus.draft,
      );
      store.baSessions.add(session);

      final result = await store.discardUnlinkedBaSlot(
        target: session,
        kind: 'before',
      );

      expect(result.discarded, isTrue);
      expect(store.baSessions.where((s) => s.id == 'ba-draft-one'), isEmpty);
    });

    test('2d. 교체 attach는 이전 Storage 원본을 정리한다', () async {
      final store = SoriStore();
      const session = BaCaptureSession(
        id: 'ba-draft-replace',
        shopId: 'shop1',
        sessionToken: 'tok-replace',
        beforeImageUrl: _draftUrl,
        status: BaCaptureStatus.draft,
      );
      store.baSessions.add(session);
      const nextUrl =
          'https://example.supabase.co/storage/v1/object/public/chart_photos/shop1/ba_draft_tok/new_2_before.webp';

      final saved = await store.attachBaPhoto(
        target: session,
        kind: 'before',
        imageUrl: nextUrl,
      );

      expect(saved.beforeImageUrl, nextUrl);
      expect(removedPaths, ['shop1/ba_draft_tok/xyz_1_before.webp']);
    });

    test('2e. 차트 참조 URL 슬롯 삭제는 차단한다', () async {
      final store = SoriStore();
      store.charts.add(
        CustomerChart(
          id: 'chart-slot-ref',
          shopId: store.shop.id,
          customerId: store.customers.first.id,
          visitNumber: 7,
          beforeImageUrl: _draftUrl,
        ),
      );
      const session = BaCaptureSession(
        id: 'ba-draft-blocked',
        shopId: 'shop1',
        sessionToken: 'tok-blocked',
        beforeImageUrl: _draftUrl,
        status: BaCaptureStatus.draft,
      );
      store.baSessions.add(session);

      final result = await store.discardUnlinkedBaSlot(
        target: session,
        kind: 'before',
      );

      expect(result.discarded, isFalse);
      expect(result.blockedByChartRef, isTrue);
      expect(removedPaths, isEmpty);
      expect(store.baSessions.any((s) => s.id == 'ba-draft-blocked'), isTrue);
    });

    test('3. 차트 before/after가 같은 URL이면 remove 0 + 메타 유지', () async {
      final store = SoriStore();
      store.charts.add(
        CustomerChart(
          id: 'chart-ref',
          shopId: store.shop.id,
          customerId: store.customers.first.id,
          visitNumber: 99,
          beforeImageUrl: _unboundUrl,
        ),
      );
      await store.enqueueShootInboxItem(
        ShootInboxItem(
          id: 'inbox-ref',
          shopId: store.shop.id,
          kind: 'before',
          imageUrl: _unboundUrl,
          sessionToken: 'sess-ref',
        ),
      );

      final result =
          await store.discardUnlinkedShootInboxItems(['inbox-ref']);

      expect(result.discarded, isFalse);
      expect(result.blockedByChartRef, isTrue);
      expect(result.storageRemoveCount, 0);
      expect(removedPaths, isEmpty);
      expect(store.shootInbox.any((e) => e.id == 'inbox-ref'), isTrue);
      expect(store.charts.firstWhere((c) => c.id == 'chart-ref').beforeImageUrl,
          _unboundUrl);
    });

    test('3b. 차트에 연결된 히스토리 사진을 지우면 세션과 차트 URL이 함께 빠진다', () async {
      final store = SoriStore();
      store.charts.add(
        CustomerChart(
          id: 'chart-keep',
          shopId: store.shop.id,
          customerId: store.customers.first.id,
          visitNumber: 3,
          beforeImageUrl: _draftUrl,
        ),
      );
      const session = BaCaptureSession(
        id: 'ba-linked',
        shopId: 'shop1',
        sessionToken: 'tok-linked',
        beforeImageUrl: _draftUrl,
        chartId: 'chart-keep',
        status: BaCaptureStatus.draft,
      );
      store.baSessions.add(session);

      final result = await store.discardUnlinkedBaSession(session);

      expect(result.discarded, isTrue);
      expect(removedPaths, ['shop1/ba_draft_tok/xyz_1_before.webp']);
      expect(store.baSessions.any((s) => s.id == 'ba-linked'), isFalse);
      expect(
        store.charts.firstWhere((c) => c.id == 'chart-keep').beforeImageUrl?.trim() ?? '',
        isEmpty,
      );
    });

    test('3d. 같은 URL을 가진 차트 두 곳도 함께 떼고 Storage를 지운다', () async {
      final store = SoriStore();
      final customerId = store.customers.first.id;
      store.charts.add(
        CustomerChart(
          id: 'chart-dup-a',
          shopId: store.shop.id,
          customerId: customerId,
          visitNumber: 5,
          beforeImageUrl: _draftUrl,
          afterImageUrl: _draftUrl,
        ),
      );
      store.charts.add(
        CustomerChart(
          id: 'chart-dup-b',
          shopId: store.shop.id,
          customerId: customerId,
          visitNumber: 6,
          beforeImageUrl: _draftUrl,
          afterImageUrl: _draftUrl,
        ),
      );
      const session = BaCaptureSession(
        id: 'ba-dup',
        shopId: 'shop1',
        sessionToken: 'tok-dup',
        beforeImageUrl: _draftUrl,
        afterImageUrl: _draftUrl,
        chartId: 'chart-dup-a',
        label: '미등록',
        status: BaCaptureStatus.linked,
      );
      store.baSessions.add(session);

      final result = await store.discardUnlinkedBaSession(session);

      expect(result.discarded, isTrue);
      expect(removedPaths, ['shop1/ba_draft_tok/xyz_1_before.webp']);
      expect(store.baSessions.any((s) => s.id == 'ba-dup'), isFalse);
      for (final id in ['chart-dup-a', 'chart-dup-b']) {
        final chart = store.charts.firstWhere((c) => c.id == id);
        expect(chart.beforeImageUrl?.trim() ?? '', isEmpty);
        expect(chart.afterImageUrl?.trim() ?? '', isEmpty);
      }
    });

    test('3c. 차트 미러 원형도 차트 URL을 떼고 Storage를 지운다', () async {
      final store = SoriStore();
      store.charts.add(
        CustomerChart(
          id: 'chart-mirror',
          shopId: store.shop.id,
          customerId: store.customers.first.id,
          visitNumber: 4,
          beforeImageUrl: _draftUrl,
        ),
      );
      final mirror = BaCaptureSession(
        id: SoriStore.chartMirrorSessionId('chart-mirror'),
        shopId: store.shop.id,
        sessionToken: 'chart-chart-mirror',
        beforeImageUrl: _draftUrl,
        chartId: 'chart-mirror',
        status: BaCaptureStatus.linked,
      );

      final result = await store.discardUnlinkedBaSession(mirror);

      expect(result.discarded, isTrue);
      expect(removedPaths, ['shop1/ba_draft_tok/xyz_1_before.webp']);
      expect(
        store.charts.firstWhere((c) => c.id == 'chart-mirror').beforeImageUrl?.trim() ?? '',
        isEmpty,
      );
    });

    test('4. Storage remove 실패 → 메타/큐 유지', () async {
      ChartPhotoStorage.debugRemoveHandler = (path) async {
        removedPaths.add(path);
        return false;
      };
      final store = SoriStore();
      await store.enqueueShootInboxItem(
        ShootInboxItem(
          id: 'inbox-fail',
          shopId: store.shop.id,
          kind: 'before',
          imageUrl: _unboundUrl,
          sessionToken: 'sess-fail',
        ),
      );

      final result =
          await store.discardUnlinkedShootInboxItems(['inbox-fail']);

      expect(result.discarded, isFalse);
      expect(result.storageFailed, isTrue);
      expect(store.shootInbox.any((e) => e.id == 'inbox-fail'), isTrue);
    });

    test('6. visitChecked / Consent publish gate 회귀 없음', () {
      final store = SoriStore();
      final customer = store.findCustomer('2') ?? store.customers.first;
      final saved = store.saveChartAndConfirmVisit(
        customerId: customer.id,
        visitNumber: store.nextVisitNumber(customer.id),
        careName: 'D02-1',
        treatmentSummary: 'keep',
        directorInsight: 'internal',
        concernChips: const [],
        firstVisitFearChips: const [],
        revisitFeedbackChips: const [],
        memberships: customer.memberships,
      );
      expect(saved.visitChecked, isTrue);

      final unsigned = CustomerChart(
        id: 'gate-1',
        shopId: store.shop.id,
        customerId: customer.id,
        visitNumber: 1,
        consentMarketing: true,
      );
      expect(canPublishBa(unsigned), ConsentPublishGate.notSigned);
    });
  });

  group('D02-1 dialog', () {
    testWidgets('5. 취소하면 Storage/onDiscard가 호출되지 않는다', (tester) async {
      var discarded = 0;
      const pending = BaCaptureSession(
        id: 'pending-1',
        shopId: 'shop1',
        sessionToken: 'pending-tok',
        beforeImageUrl: _draftUrl,
        status: BaCaptureStatus.draft,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: HomeVisualTokens.canvasBg,
            body: BaCaptureCarousel(
              sessions: const [],
              pending: pending,
              onCapture: (_, _) {},
              onBind: (_) {},
              onDefer: (_) {},
              onOpen: (_) {},
              onDiscard: (_) async {
                discarded++;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('NEW'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ba-discard-pending')));
      await tester.pumpAndSettle();

      expect(find.text('사진을 삭제할까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(discarded, 0);
      expect(removedPaths, isEmpty);
      expect(find.text('사진을 삭제할까요?'), findsNothing);
    });

    testWidgets('채워진 Before 탭 → 교체·삭제·차트 작성 메뉴', (tester) async {
      String? capturedKind;
      var discardedKind = '';
      BaCaptureSession? bound;
      const pending = BaCaptureSession(
        id: 'pending-menu',
        shopId: 'shop1',
        sessionToken: 'pending-menu-tok',
        beforeImageUrl: _draftUrl,
        status: BaCaptureStatus.draft,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: HomeVisualTokens.canvasBg,
            body: BaCaptureCarousel(
              sessions: const [],
              pending: pending,
              onCapture: (_, kind) => capturedKind = kind,
              onBind: (s) => bound = s,
              onDefer: (_) {},
              onOpen: (_) {},
              onDiscard: (_) async {},
              onDiscardSlot: (_, kind) async {
                discardedKind = kind;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('NEW'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Before'));
      await tester.pumpAndSettle();

      expect(find.text('사진 교체'), findsOneWidget);
      expect(find.text('사진 삭제'), findsWidgets);
      expect(find.byKey(const Key('ba-slot-action-bind')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ba-slot-action-replace')));
      await tester.pumpAndSettle();
      expect(capturedKind, 'before');

      await tester.tap(find.text('NEW'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Before'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ba-slot-action-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Before 사진을 삭제할까요?'), findsOneWidget);
      await tester.tap(find.text('사진 삭제').last);
      await tester.pumpAndSettle();
      expect(discardedKind, 'before');

      await tester.tap(find.text('NEW'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Before'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ba-slot-action-bind')));
      await tester.pumpAndSettle();
      expect(bound?.id, 'pending-menu');
    });

    testWidgets('연결된 완성 카드에는 삭제 버튼을 노출하지 않는다', (tester) async {
      final complete = BaCaptureSession(
        id: 'green-1',
        shopId: 'shop1',
        sessionToken: 'tok-g',
        beforeImageUrl: _draftUrl,
        afterImageUrl: _unboundUrl,
        chartId: 'chart-g',
        status: BaCaptureStatus.linked,
        label: '완성케어',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: HomeVisualTokens.canvasBg,
            body: BaCaptureCarousel(
              sessions: [complete],
              onCapture: (_, _) {},
              onBind: (_) {},
              onDefer: (_) {},
              onOpen: (_) {},
              onDiscard: (_) async {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('ba-discard-green-1')), findsNothing);
      expect(find.text('완성케어'), findsOneWidget);
    });

    testWidgets('NEW 길게 누르기 → 삭제 확인 → onDiscard', (tester) async {
      var discarded = 0;
      const pending = BaCaptureSession(
        id: 'pending-lp',
        shopId: 'shop1',
        sessionToken: 'pending-lp-tok',
        beforeImageUrl: _draftUrl,
        status: BaCaptureStatus.draft,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: HomeVisualTokens.canvasBg,
            body: BaCaptureCarousel(
              sessions: const [],
              pending: pending,
              onCapture: (_, _) {},
              onBind: (_) {},
              onDefer: (_) {},
              onOpen: (_) {},
              onDiscard: (_) async {
                discarded++;
              },
            ),
          ),
        ),
      );

      await tester.longPress(find.byKey(const Key('ba-fixed-capture-slot')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ba-history-delete-new-pending-lp')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ba-history-delete-new-pending-lp')));
      await tester.pumpAndSettle();
      expect(find.text('사진을 삭제할까요?'), findsOneWidget);
      await tester.tap(find.text('사진 삭제'));
      await tester.pumpAndSettle();
      expect(discarded, 1);
    });

    testWidgets('미완성 고객원형 미등록 표시 + 길게 누르기 삭제', (tester) async {
      var discardedId = '';
      const incomplete = BaCaptureSession(
        id: 'red-cust',
        shopId: 'shop1',
        sessionToken: 'tok-red',
        beforeImageUrl: _draftUrl,
        customerId: 'cust-1',
        label: '김고객',
        status: BaCaptureStatus.draft,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: HomeVisualTokens.canvasBg,
            body: BaCaptureCarousel(
              sessions: const [incomplete],
              onCapture: (_, _) {},
              onBind: (_) {},
              onDefer: (_) {},
              onOpen: (_) {},
              onDiscard: (s) async {
                discardedId = s.id;
              },
            ),
          ),
        ),
      );

      expect(find.text('김고객'), findsOneWidget);
      expect(find.text('미등록'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ba-history-delete-red-cust')),
        findsNothing,
      );

      await tester.longPress(find.byKey(const ValueKey('history-red-cust')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ba-history-delete-red-cust')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ba-history-delete-red-cust')));
      await tester.pumpAndSettle();
      expect(find.text('사진을 삭제할까요?'), findsOneWidget);

      await tester.tap(find.text('사진 삭제'));
      await tester.pumpAndSettle();
      expect(discardedId, 'red-cust');
    });
  });

  group('chart → B&A history sync', () {
    test('After clear 시 linked 세션이 완성 히스토리에서 빠진다', () async {
      final store = SoriStore();
      final customer = store.customers.first;
      final chart = CustomerChart(
        id: 'chart-sync-1',
        shopId: store.shop.id,
        customerId: customer.id,
        visitNumber: 99,
        beforeImageUrl: _draftUrl,
        afterImageUrl: _unboundUrl,
        visitChecked: true,
        createdAt: DateTime.now(),
      );
      store.charts.add(chart);
      store.baSessions.add(
        BaCaptureSession(
          id: 'ba-linked-1',
          shopId: store.shop.id,
          sessionToken: 'tok-linked-1',
          beforeImageUrl: _draftUrl,
          afterImageUrl: _unboundUrl,
          customerId: customer.id,
          chartId: chart.id,
          status: BaCaptureStatus.linked,
          label: customer.name,
        ),
      );

      expect(
        store.baCarouselSessions.any((s) => s.chartId == chart.id && s.isComplete),
        isTrue,
      );

      await store.updateCustomerChartFields(
        chartId: chart.id,
        clearAfterImageUrl: true,
      );

      final synced = store.baSessions.singleWhere((s) => s.id == 'ba-linked-1');
      expect(synced.afterImageUrl, isNull);
      expect(synced.beforeImageUrl, _draftUrl);
      expect(synced.isComplete, isFalse);
      expect(
        store.baCarouselSessions
            .where((s) => s.chartId == chart.id && s.isComplete),
        isEmpty,
      );
      expect(
        store.managementCaseCharts().where((c) => c.id == chart.id),
        isEmpty,
      );
    });

    test('B/A 둘 다 없으면 linked 세션 메타를 제거한다', () async {
      final store = SoriStore();
      final customer = store.customers.first;
      final chart = CustomerChart(
        id: 'chart-sync-2',
        shopId: store.shop.id,
        customerId: customer.id,
        visitNumber: 98,
        visitChecked: true,
      );
      store.charts.add(chart);
      store.baSessions.add(
        BaCaptureSession(
          id: 'ba-linked-2',
          shopId: store.shop.id,
          sessionToken: 'tok-linked-2',
          beforeImageUrl: _draftUrl,
          afterImageUrl: _unboundUrl,
          customerId: customer.id,
          chartId: chart.id,
          status: BaCaptureStatus.linked,
        ),
      );

      await store.syncBaHistoryWithChart(chart);

      expect(store.baSessions.where((s) => s.id == 'ba-linked-2'), isEmpty);
    });

    test('ShootHub 미등록 삭제 후 로컬 BA 투영도 비운다', () async {
      final store = SoriStore();
      store.baRemoteReady = false;
      await store.enqueueShootInboxItem(
        ShootInboxItem(
          id: 'inbox-local',
          shopId: store.shop.id,
          kind: 'before',
          imageUrl: _unboundUrl,
          label: '미등록',
          sessionToken: 'sess-local',
        ),
      );
      // 원격 폴백 투영 상태를 흉내낸다 (refresh는 메모리가 살아 baRemoteReady를 다시 켠다).
      store.baSessions
        ..clear()
        ..add(
          BaCaptureSession(
            id: SoriStore.localBaSessionId('sess-local'),
            shopId: store.shop.id,
            sessionToken: 'sess-local',
            beforeImageUrl: _unboundUrl,
            label: '미등록',
          ),
        );

      final result =
          await store.discardUnlinkedShootInboxItems(['inbox-local']);
      expect(result.discarded, isTrue);
      expect(store.shootInbox, isEmpty);
      expect(
        store.baSessions.where((s) => s.sessionToken == 'sess-local'),
        isEmpty,
      );
    });
  });

  test('objectPathFromPublicUrl parses chart_photos public URL', () {
    expect(
      ChartPhotoStorage.objectPathFromPublicUrl(_unboundUrl),
      'shop1/unbound/abc_1_before.webp',
    );
    expect(ChartPhotoStorage.objectPathFromPublicUrl('data:image/webp;base64,x'),
        isNull);
  });
}
