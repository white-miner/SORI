import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/operation/widgets/flip_clock_display.dart';
import 'package:sori/features/visit/home_visual_tokens.dart';
import 'package:sori/features/visit/widgets/ba_capture_carousel.dart';
import 'package:sori/features/visit/widgets/home_quick_action_row.dart';
import 'package:sori/features/visit/widgets/home_scheduler_strip.dart';
import 'package:sori/features/visit/widgets/management_case_card.dart';
import 'package:sori/models/ba_capture_session.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/visit_kernel/models/care_schedule_entry.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: HomeVisualTokens.canvasBg,
      body: child,
    ),
  );
}

BaCaptureSession _draft({
  required String id,
  String? before,
  String? after,
  String label = '',
}) {
  return BaCaptureSession(
    id: id,
    shopId: 'shop-1',
    sessionToken: 'token-$id',
    beforeImageUrl: before,
    afterImageUrl: after,
    label: label,
    createdAt: DateTime(2026, 9, 2, 9),
  );
}

void main() {
  group('⓪ 플립 시계 — 초(SS) 오버플로우', () {
    // 화면 폭을 바꿔가며 SS가 시계 박스 밖으로 새지 않는지 본다.
    for (final size in const [
      Size(360, 800), // 좁은 세로
      Size(430, 932), // 기본 세로
      Size(932, 430), // 가로
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} 에서 넘치지 않는다',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _host(
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: FlipClockDisplay(
                  totalSeconds: 12 * 3600 + 2 * 60 + 38,
                  hero: true,
                  homeHero: true,
                  showSeconds: false,
                  showCornerSeconds: true,
                  style: FlipClockStyle.darkGlass,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        // SS가 시계 위젯의 경계 안에 완전히 들어와야 한다.
        final clockRect = tester.getRect(find.byType(FlipClockDisplay));
        final ssRect = tester.getRect(
          find.byKey(const Key('dark-glass-corner-seconds')),
        );

        expect(ssRect.right, lessThanOrEqualTo(clockRect.right + 0.5));
        expect(ssRect.bottom, lessThanOrEqualTo(clockRect.bottom + 0.5));
        expect(ssRect.left, greaterThanOrEqualTo(clockRect.left - 0.5));

        // 그리고 화면 밖으로도 나가면 안 된다.
        expect(ssRect.right, lessThanOrEqualTo(size.width + 0.5));
      });
    }

    testWidgets('SS가 HH:MM 타일을 밀어내지 않는다', (tester) async {
      // 축소 없이 원래 크기로 재야 하므로 넉넉한 서피스에서 측정한다.
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<Rect> digitsRect({required bool withSeconds}) async {
        await tester.pumpWidget(
          _host(
            Align(
              alignment: Alignment.centerLeft,
              child: FlipClockDisplay(
                totalSeconds: 12 * 3600 + 2 * 60 + 38,
                hero: true,
                homeHero: true,
                showSeconds: false,
                showCornerSeconds: withSeconds,
                style: FlipClockStyle.darkGlass,
              ),
            ),
          ),
        );
        await tester.pump();
        // 스플릿플랩은 한 타일에 위·아래 두 장을 그린다. 첫 타일만 잰다.
        return tester.getRect(find.byKey(const Key('dark-glass-digit')).first);
      }

      final without = await digitsRect(withSeconds: false);
      final with_ = await digitsRect(withSeconds: true);

      // SS를 켜도 HH:MM 타일 위치가 그대로여야 한다 (Row로 이어 붙이지 않는다).
      expect(with_.left, closeTo(without.left, 0.5));
      expect(with_.width, closeTo(without.width, 0.5));
    });

    testWidgets('HH와 MM 사이에 콜론이 보이는 색으로 렌더된다', (tester) async {
      await tester.pumpWidget(
        _host(
          const Center(
            child: FlipClockDisplay(
              totalSeconds: 13 * 3600 + 4 * 60 + 38,
              hero: true,
              homeHero: true,
              showSeconds: false,
              showCornerSeconds: true,
              style: FlipClockStyle.darkGlass,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(':'), findsOneWidget);

      // 히어로 카드는 밝다 — 흰 콜론은 배경에 묻혀 사라진다.
      final colon = tester.widget<Text>(find.text(':'));
      final color = colon.style!.color!;
      expect(color.a, greaterThan(0.5), reason: '너무 투명하면 안 보인다');
      expect(color.computeLuminance(), lessThan(0.3), reason: '밝은 배경 위 어두운 글자');

      // 콜론은 시(HH)와 분(MM) 사이에 있어야 한다. (13:04)
      final colonX = tester.getCenter(find.text(':')).dx;
      expect(colonX, greaterThan(tester.getCenter(find.text('3').first).dx));
      expect(colonX, lessThan(tester.getCenter(find.text('4').first).dx));
    });

    testWidgets('초(SS)에도 시/분과 동일한 다크 글래스 패널이 깔린다', (tester) async {
      await tester.pumpWidget(
        _host(
          const Center(
            child: FlipClockDisplay(
              totalSeconds: 13 * 3600 + 4 * 60 + 38,
              hero: true,
              homeHero: true,
              showSeconds: false,
              showCornerSeconds: true,
              style: FlipClockStyle.darkGlass,
            ),
          ),
        ),
      );
      await tester.pump();

      // 초 숫자를 감싼 조상 중에 어두운 그라디언트 배경이 있어야 한다.
      final cornerDigit = find.byKey(const Key('dark-glass-corner-digit')).first;
      final panel = find
          .ancestor(of: cornerDigit, matching: find.byType(Container))
          .evaluate()
          .map((e) => e.widget as Container)
          .where((c) => c.decoration is BoxDecoration)
          .map((c) => c.decoration as BoxDecoration)
          .where((d) => d.gradient != null)
          .toList();

      expect(panel, isNotEmpty, reason: '흰 배경에 흰 글자만 떠 있으면 초가 안 보인다');
      final colors = (panel.first.gradient as LinearGradient).colors;
      for (final c in colors) {
        expect(c.computeLuminance(), lessThan(0.1), reason: '다크 글래스');
      }

      // 글자는 패널 위에서 흰색이다.
      final ss = tester.widget<Text>(cornerDigit);
      expect(ss.style!.color!.computeLuminance(), greaterThan(0.7));
    });
  });

  group('⓪-2 히어로 카드 — 날짜·시계·메모 응집', () {
    testWidgets('세 요소 사이 여백이 타이트하게 붙어 있다', (tester) async {
      expect(
        HomeVisualTokens.dateRowMinHeight,
        lessThanOrEqualTo(32.0),
        reason: '날짜 줄이 부풀면 시계와 멀어진다',
      );
      // 시계 타일 높이(132)에 붙는 여유만 남긴다.
      expect(HomeVisualTokens.flipHeroZoneMinHeight, lessThanOrEqualTo(150.0));
      expect(HomeVisualTokens.flipHeroZoneMinHeight, greaterThanOrEqualTo(132.0));
      expect(HomeVisualTokens.heroCardPaddingTop, lessThanOrEqualTo(16.0));
      expect(HomeVisualTokens.heroCardPaddingBottom, lessThanOrEqualTo(14.0));
    });
  });

  group('② Quick Action — 컬러 헌법 (Q2a)', () {
    testWidgets('신규 고객은 보라 #8B5CF6, 재방문은 흰 배경 + 보더', (tester) async {
      await tester.pumpWidget(
        _host(
          HomeQuickActionRow(
            onNewCustomer: () {},
            onReturningCustomer: () {},
          ),
        ),
      );

      final materials = tester
          .widgetList<Material>(find.byType(Material))
          .where((m) => m.color != null)
          .toList();

      expect(
        materials.any((m) => m.color == HomeVisualTokens.quickNewFill),
        isTrue,
        reason: '신규 고객 버튼이 보라 토큰을 써야 한다',
      );
      expect(
        materials.any((m) => m.color == HomeVisualTokens.quickReturningFill),
        isTrue,
      );
      expect(HomeVisualTokens.quickNewFill, const Color(0xFF8B5CF6));
      expect(find.text('신규 고객'), findsOneWidget);
      expect(find.text('재방문 고객'), findsOneWidget);
    });

    testWidgets('케어 시작 Green이 신규 버튼에 재사용되지 않는다', (tester) async {
      await tester.pumpWidget(
        _host(
          HomeQuickActionRow(
            onNewCustomer: () {},
            onReturningCustomer: () {},
          ),
        ),
      );

      final colors = tester
          .widgetList<Material>(find.byType(Material))
          .map((m) => m.color)
          .toList();
      expect(colors.contains(HomeVisualTokens.careGreen), isFalse);
    });

    testWidgets('탭하면 각각의 라우팅 콜백이 발화한다', (tester) async {
      var newTaps = 0;
      var returningTaps = 0;
      await tester.pumpWidget(
        _host(
          HomeQuickActionRow(
            onNewCustomer: () => newTaps++,
            onReturningCustomer: () => returningTaps++,
          ),
        ),
      );

      await tester.tap(find.text('신규 고객'));
      await tester.tap(find.text('재방문 고객'));
      await tester.pump();

      expect(newTaps, 1);
      expect(returningTaps, 1);
    });
  });

  group('③ B&A 히스토리 작업대', () {
    testWidgets('빈 NEW에서 전후 촬영 선택을 연다', (tester) async {
      String? captured;
      await tester.pumpWidget(_host(BaCaptureCarousel(
        sessions: const [], onCapture: (_, kind) => captured = kind,
        onBind: (_) {}, onDefer: (_) {}, onOpen: (_) {},
      )));
      expect(find.byKey(const Key('ba-fixed-capture-slot')), findsOneWidget);
      await tester.tap(find.text('NEW'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
      await tester.tap(find.byIcon(Icons.add_rounded).at(1));
      await tester.pumpAndSettle();
      expect(captured, 'before');
    });
    testWidgets('거치 사진은 명시적으로 차트 연결을 선택해야 전달된다', (tester) async {
      BaCaptureSession? bound;
      await tester.pumpWidget(_host(BaCaptureCarousel(
        sessions: const [], pending: _draft(id: 'pending', before: 'https://x/b.webp'),
        onCapture: (_, _) {}, onBind: (s) => bound = s,
        onDefer: (_) {}, onOpen: (_) {},
      )));
      expect(bound, isNull);
      await tester.tap(find.text('NEW'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('차트 작성'));
      await tester.pumpAndSettle();
      expect(bound?.id, 'pending');
    });
  });

  group('① 스케줄러 스트립', () {
    testWidgets('가장 가까운 일정을 "HH:mm 이름님 케어" 로 보여준다', (tester) async {
      final store = SoriStore();
      final today = DateTime.now();
      store.careScheduleEntries = [
        CareScheduleEntry(
          id: 'e1',
          shopId: store.shop.id,
          scheduledAt: DateTime(today.year, today.month, today.day, 12, 30),
          customerName: '김민정',
          careLabel: '상담예약',
        ),
      ];

      await tester.pumpWidget(
        _host(HomeSchedulerStrip(store: store, onTap: () {})),
      );

      expect(find.text('12:30 김민정님 상담예약'), findsOneWidget);
    });

    testWidgets('일정이 없으면 빈 상태 문구를 보여준다', (tester) async {
      final store = SoriStore();
      store.careScheduleEntries = [];

      await tester.pumpWidget(
        _host(HomeSchedulerStrip(store: store, onTap: () {})),
      );

      expect(find.text('오늘 예정된 일정이 없어요.'), findsOneWidget);
    });

    testWidgets('일정이 4건 이상이면 +N 칩이 붙는다', (tester) async {
      final store = SoriStore();
      final today = DateTime.now();
      store.careScheduleEntries = [
        CareScheduleEntry(
          id: 'e1',
          shopId: store.shop.id,
          scheduledAt: DateTime(today.year, today.month, today.day, 10),
          customerName: '김민정',
          careLabel: '상담예약',
        ),
        CareScheduleEntry(
          id: 'e2',
          shopId: store.shop.id,
          scheduledAt: DateTime(today.year, today.month, today.day, 12, 30),
          customerName: '최진실',
          careLabel: '웨딩케어',
        ),
        CareScheduleEntry(
          id: 'e3',
          shopId: store.shop.id,
          scheduledAt: DateTime(today.year, today.month, today.day, 14),
          customerName: '박서연',
          careLabel: '관리',
        ),
        CareScheduleEntry(
          id: 'e4',
          shopId: store.shop.id,
          scheduledAt: DateTime(today.year, today.month, today.day, 16),
          customerName: '이하늘',
          careLabel: '리프팅',
        ),
      ];

      await tester.pumpWidget(
        _host(HomeSchedulerStrip(store: store, onTap: () {})),
      );

      expect(find.text('+1'), findsOneWidget);
    });
  });

  group('④ 관리 케이스 카드', () {
    testWidgets('회차 · 케어명 · 고객 키워드가 모두 보인다', (tester) async {
      final chart = CustomerChart(
        id: 'c1',
        shopId: 'shop-1',
        customerId: 'cus-1',
        visitNumber: 3,
        careName: '스페셜 웨딩 케어',
        feedAge: 38,
        feedGenderLabel: '여성',
        skinSensitivity: '민감',
        concernChips: const ['부종', '순환'],
      );

      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ManagementCaseCard(
              chart: chart,
              bookmarked: false,
              onBookmark: () {},
              onExpand: () {},
            ),
          ),
        ),
      );

      expect(find.text('3회차'), findsOneWidget);
      expect(find.text('스페셜 웨딩 케어'), findsOneWidget);

      final caption = tester.widget<Text>(
        find.textContaining('만 38세').first,
      );
      expect(caption.data, contains('여성'));
      expect(caption.data, contains('민감'));
      expect(caption.data, contains('부종'));

      // 상담 중 원장이 읽는 문장 — 12sp 미만으로 다시 내려가지 않도록 고정.
      expect(caption.style?.fontSize, greaterThanOrEqualTo(13.0));
      expect(caption.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('Before/After 코너 태그가 두 겹으로 겹치지 않는다', (tester) async {
      final chart = CustomerChart(
        id: 'c1',
        shopId: 'shop-1',
        customerId: 'cus-1',
        visitNumber: 2,
        careName: '스페셜 웨딩 케어',
        beforeImageUrl: 'https://example.com/b.webp',
        afterImageUrl: 'https://example.com/a.webp',
      );

      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ManagementCaseCard(
              chart: chart,
              bookmarked: false,
              onBookmark: () {},
              onExpand: () {},
            ),
          ),
        ),
      );

      // BeforeAfterSlider가 그리는 코너 태그 1쌍만 존재해야 한다.
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
    });

    testWidgets('북마크 상태가 아이콘에 반영되고 탭이 전달된다', (tester) async {
      var taps = 0;
      final chart = CustomerChart(
        id: 'c1',
        shopId: 'shop-1',
        customerId: 'cus-1',
        visitNumber: 1,
        careName: '테스트 케어',
      );

      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ManagementCaseCard(
              chart: chart,
              bookmarked: true,
              onBookmark: () => taps++,
              onExpand: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('케어명이 비면 "관리 케이스"로 폴백한다', (tester) async {
      final chart = CustomerChart(
        id: 'c1',
        shopId: 'shop-1',
        customerId: 'cus-1',
        visitNumber: 1,
        careName: '',
      );

      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ManagementCaseCard(
              chart: chart,
              bookmarked: false,
              onBookmark: () {},
              onExpand: () {},
            ),
          ),
        ),
      );

      expect(find.text('관리 케이스'), findsOneWidget);
    });
  });
}
