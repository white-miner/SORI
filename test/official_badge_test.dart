import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/sori_official.dart';
import 'package:sori/widgets/official_badge.dart';

void main() {
  test('SoriOfficial matches seed id, slug, and isOfficial flag', () {
    expect(
      SoriOfficial.matchesShop(id: SoriOfficial.shopId, isOfficial: false),
      isTrue,
    );
    expect(
      SoriOfficial.matchesShop(
        id: 'other',
        slug: SoriOfficial.slug,
        isOfficial: false,
      ),
      isTrue,
    );
    expect(
      SoriOfficial.matchesShop(id: 'other', isOfficial: true),
      isTrue,
    );
    expect(
      SoriOfficial.matchesShop(id: 'random-shop', isOfficial: false),
      isFalse,
    );
  });

  test('Shop.displayIsOfficial follows seed + flag', () {
    const official = Shop(
      id: SoriOfficial.shopId,
      name: 'SORI',
      naverPlaceUrl: '',
      isOfficial: true,
      slug: SoriOfficial.slug,
    );
    expect(official.displayIsOfficial, isTrue);

    const plain = Shop(
      id: 'shop-plain',
      name: '일반샵',
      naverPlaceUrl: '',
    );
    expect(plain.displayIsOfficial, isFalse);
  });

  testWidgets('Official badge renders next to official shop name',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShopNameWithOfficialBadge(
            name: 'SORI',
            isOfficial: true,
          ),
        ),
      ),
    );
    expect(find.text('SORI'), findsOneWidget);
    expect(find.text('공식'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('non-official name has no badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShopNameWithOfficialBadge(
            name: '청담샵',
            isOfficial: false,
          ),
        ),
      ),
    );
    expect(find.text('청담샵'), findsOneWidget);
    expect(find.text('공식'), findsNothing);
  });

  test('memory hot cases seed includes SORI Official', () async {
    final repo = MemorySoriRepository();
    final store = SoriStore(repository: repo);
    await store.refreshCommunityHotCases();
    final official = store.communityHotCases.where(
      (e) => e.shop.displayIsOfficial,
    );
    expect(official, isNotEmpty);
    expect(official.first.shop.slug, SoriOfficial.slug);
    expect(official.first.shop.id, SoriOfficial.shopId);
  });
}
