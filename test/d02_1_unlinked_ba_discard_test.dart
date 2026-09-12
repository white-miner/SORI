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

    test('2. draft BaCaptureSession + chart_id null → remove 1 + session 제거',
        () async {
      final store = SoriStore();
      const session = BaCaptureSession(
        id: 'ba-draft-1',
        shopId: 'shop1',
        sessionToken: 'tok-draft',
        beforeImageUrl: _draftUrl,
        status: BaCaptureStatus.draft,
      );
      store.baSessions.add(session);

      final result = await store.discardUnlinkedBaSession(session);

      expect(result.discarded, isTrue);
      expect(result.storageRemoveCount, 1);
      expect(removedPaths, ['shop1/ba_draft_tok/xyz_1_before.webp']);
      expect(store.baSessions.where((s) => s.id == 'ba-draft-1'), isEmpty);
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

    test('3b. chart_id 있는 BA 세션은 Storage/메타를 건드리지 않는다', () async {
      final store = SoriStore();
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

      expect(result.discarded, isFalse);
      expect(removedPaths, isEmpty);
      expect(store.baSessions.any((s) => s.id == 'ba-linked'), isTrue);
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

      await tester.tap(find.byKey(const Key('ba-discard-pending')));
      await tester.pumpAndSettle();

      expect(find.text('사진을 삭제할까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(discarded, 0);
      expect(removedPaths, isEmpty);
      expect(find.text('사진을 삭제할까요?'), findsNothing);
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
