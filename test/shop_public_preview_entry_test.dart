import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sori/features/visit/open_shop_public_preview.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/director_fandom_profile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> settleShowcase(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final manage = find.byKey(const Key('profile_featured_ba_manage'));
    if (manage.evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('owner preview shows manage CTA; visitor hides it',
      (tester) async {
    final store = SoriStore();

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorFandomProfilePage(store: store, isOwner: true),
      ),
    );
    await settleShowcase(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('profile_featured_ba_manage')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: DirectorFandomProfilePage(store: store, isOwner: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_featured_ba_manage')), findsNothing);
  });

  testWidgets('openShopPublicPreview pushes isOwner route and pops back',
      (tester) async {
    final store = SoriStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                key: const Key('entry_preview'),
                onPressed: () => openShopPublicPreview(
                  context,
                  store,
                  isOwner: true,
                ),
                child: const Text('내 샵 미리보기'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('entry_preview')));
    await settleShowcase(tester);

    expect(find.byType(DirectorFandomProfilePage), findsOneWidget);
    expect(find.byKey(const Key('profile_featured_ba_manage')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DirectorFandomProfilePage), findsNothing);
    expect(find.byKey(const Key('entry_preview')), findsOneWidget);
  });
}
