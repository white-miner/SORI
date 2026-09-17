import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/customer.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/theme/sori_tokens.dart';
import 'package:sori/views/customer_merge_wizard.dart';

void main() {
  testWidgets('merge confirm step has Korean copy and survives keyboard inset',
      (tester) async {
    final store = SoriStore(repository: MemorySoriRepository());
    await store.bootstrap(repository: MemorySoriRepository());
    final shopId = store.shop.id;
    final now = DateTime.now();
    final a = Customer(
      id: 'merge-a',
      shopId: shopId,
      name: '하얀광부',
      phone: '01011112222',
      lastTreatmentDate: now,
      treatmentType: '페이스',
      memberships: const [],
    );
    final b = Customer(
      id: 'merge-b',
      shopId: shopId,
      name: '하얀광부',
      phone: '01011112222',
      lastTreatmentDate: now.subtract(const Duration(days: 5)),
      treatmentType: '페이스',
      memberships: const [],
    );
    store.customers
      ..clear()
      ..addAll([a, b]);

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: SoriTokens.background,
            body: Center(
              child: FilledButton(
                onPressed: () => showCustomerMergeWizard(
                  context: context,
                  store: store,
                  selected: [a, b],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Primary'), findsNothing);
    expect(find.textContaining('Secondary'), findsNothing);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('병합되는 1명의 고객 정보는 영구 삭제됩니다'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '틀린이름');
    await tester.pump();
    expect(
      find.text('입력값이 유지할 고객의 이름과 다릅니다.'),
      findsOneWidget,
    );

    // Simulate virtual keyboard — must not expand into a white full-screen overlay.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('3/3 · 최종 확인'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('병합 실행'), findsOneWidget);
    expect(find.textContaining('Primary'), findsNothing);
    expect(find.textContaining('Secondary'), findsNothing);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.binding.setSurfaceSize(null);
  });
}
