import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/content_candidate/content_candidate_inbox.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/widgets/shop_posts_hub_sheet.dart';
import 'package:sori/widgets/ai_tool_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ContentCandidateInbox.instance.debugReset();
  });

  testWidgets('posts hub shows candidate cards without PII or AI sheet', (
    tester,
  ) async {
    final store = SoriStore();
    expect(store.customers, isNotEmpty);
    final customer = store.customers.first;
    store.charts.add(
      CustomerChart(
        id: 'hub-cand-1',
        shopId: store.shop.id,
        customerId: customer.id,
        visitNumber: 3,
        careName: '후보함리프팅',
        treatmentSummary: '내부 시술 메모',
        directorInsight: '원장 감사 메모',
        allergyNotes: '땅콩 알러지',
        beforeImageUrl: 'https://example.com/b.jpg',
        afterImageUrl: 'https://example.com/a.jpg',
        consentMarketing: true,
        signatureUrl: 'https://example.com/sig.png',
        createdAt: DateTime(2026, 9, 1),
      ),
    );
    expect(
      await ContentCandidateInbox.instance.enqueue(store.findChartById('hub-cand-1')!),
      isTrue,
    );

    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showShopPostsHubSheet(ctx, store: store),
              child: const Text('open-hub'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-hub'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('콘텐츠 후보함'), findsOneWidget);
    final card = find.byKey(
      const Key('content-candidate-card-hub-cand-1'),
    );
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('후보함리프팅')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('2026.09.01')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('후보')),
      findsOneWidget,
    );
    expect(find.text('내부 시술 메모'), findsNothing);
    expect(find.text('원장 감사 메모'), findsNothing);
    expect(find.text('땅콩 알러지'), findsNothing);
    expect(find.text(customer.name), findsNothing);
    expect(find.text(customer.phone), findsNothing);
    expect(find.byType(AiToolSheet), findsNothing);
  });
}
