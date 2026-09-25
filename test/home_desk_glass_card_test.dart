import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/features/visit/widgets/management_case_card.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/widgets/before_after_slider.dart';
import 'package:sori/widgets/glass/sori_glass_style.dart';

CustomerChart _chart() => const CustomerChart(
  id: 'glass-1',
  shopId: 'shop-1',
  customerId: 'cus-1',
  visitNumber: 4,
  careName: '스페셜 웨딩케어',
  skinSensitivity: '민감',
  concernChips: ['부종', '순환'],
);

Widget _host(Widget card) => MaterialApp(
  home: Scaffold(
    backgroundColor: SoriGlassStyle.warmCanvas,
    body: SingleChildScrollView(child: card),
  ),
);

void main() {
  group('DESK B&A 글래스 카드', () {
    for (final size in const [Size(360, 800), Size(430, 932)]) {
      testWidgets('${size.width.toInt()}px — 글래스 프레임 안에 사진이 들어가고 넘치지 않는다', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _host(
            ManagementCaseCard(
              chart: _chart(),
              bookmarked: false,
              onBookmark: () {},
              onExpand: () {},
              onHideFromHome: () {},
              glass: true,
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(SoriGlassBlock), findsOneWidget);

        // 사진(슬라이더)은 프레임 두께만큼 사방으로 들어가 있다.
        final block = tester.getRect(find.byKey(const Key('sori-glass-block')));
        final photo = tester.getRect(find.byType(BeforeAfterSlider));
        const f = SoriGlassStyle.frameWidth;
        expect(photo.left - block.left, closeTo(f, 0.5));
        expect(block.right - photo.right, closeTo(f, 0.5));
        expect(photo.top - block.top, closeTo(f, 0.5));
        expect(block.bottom - photo.bottom, closeTo(f, 0.5));
        expect(block.right, lessThanOrEqualTo(size.width + 0.5));

        // 블러는 하단 텍스트 패널 하나에만 (카드 전체 BackdropFilter 금지).
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.byKey(const Key('sori-frosted-panel')), findsOneWidget);

        // 내용·코너 라벨은 그대로, 중복 없이.
        expect(find.text('SORI CASE · 4회차'), findsOneWidget);
        expect(find.text('스페셜 웨딩케어'), findsOneWidget);
        for (final chip in const ['민감', '부종', '순환']) {
          expect(find.text(chip), findsOneWidget);
        }
        expect(find.text('Before'), findsWidgets);
        expect(find.text('After'), findsWidgets);
        expect(find.byTooltip('크게 보기'), findsOneWidget);
        expect(find.byTooltip('즐겨찾기'), findsOneWidget);
        expect(find.byTooltip('더보기'), findsOneWidget);
      });
    }

    testWidgets('글래스 룩에서도 탭 핸들러가 그대로 전달된다', (tester) async {
      var expand = 0;
      var bookmark = 0;
      await tester.pumpWidget(
        _host(
          ManagementCaseCard(
            chart: _chart(),
            bookmarked: true,
            onBookmark: () => bookmark++,
            onExpand: () => expand++,
            glass: true,
          ),
        ),
      );

      await tester.ensureVisible(find.byIcon(Icons.bookmark_rounded));
      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      await tester.tap(find.byIcon(Icons.open_in_full_rounded));
      await tester.pump();
      expect(bookmark, 1);
      expect(expand, 1);
    });

    testWidgets('기본값(glass: false)은 기존 룩을 유지한다', (tester) async {
      await tester.pumpWidget(
        _host(
          ManagementCaseCard(
            chart: _chart(),
            bookmarked: false,
            onBookmark: () {},
            onExpand: () {},
          ),
        ),
      );
      expect(find.byType(SoriGlassBlock), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('DESK 탭은 웜 화이트 캔버스 위에 글래스 카드를 쓴다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = SoriStore();
      store.charts.insert(
        0,
        CustomerChart(
          id: 'glass-desk-1',
          shopId: store.shop.id,
          customerId: 'cus-glass',
          visitNumber: 4,
          careName: '스페셜 웨딩케어',
          beforeImageUrl: 'https://example.com/b.webp',
          afterImageUrl: 'https://example.com/a.webp',
          createdAt: DateTime.now(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VisitLauncherPage(store: store)),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      final canvas = tester.widget<ColoredBox>(
        find.byKey(const Key('home-desk-canvas')),
      );
      expect(canvas.color, SoriGlassStyle.warmCanvas);

      final cards = tester.widgetList<ManagementCaseCard>(
        find.byType(ManagementCaseCard),
      );
      expect(cards, isNotEmpty);
      expect(cards.every((c) => c.glass), isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
