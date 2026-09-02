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
        final ssRect = tester.getRect(find.text('38'));

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
        return tester.getRect(find.text('0'));
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

      // '38' 을 감싼 조상 중에 어두운 그라디언트 배경이 있어야 한다.
      final panel = find
          .ancestor(of: find.text('38'), matching: find.byType(Container))
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
      final ss = tester.widget<Text>(find.text('38'));
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

  group('③ B/A 캐러셀 — 신호등 및 이관 애니메이션', () {
    testWidgets('첫 슬롯은 "B/A 촬영" 고정 슬롯 단 1개다 (헌법 1)', (tester) async {
      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: const [],
            onCapture: (_, _) {},
            onBind: (_) {},
            onDefer: (_) {},
            onOpen: (_) {},
          ),
        ),
      );

      expect(find.text('B/A 등록'), findsOneWidget);
      expect(find.text('B/A 촬영'), findsOneWidget);
      expect(find.text('촬영 대기'), findsNothing);
      expect(find.byKey(const Key('ba-fixed-capture-slot')), findsOneWidget);
      // 빈 상태에서도 ⊕ 두 개(Before/After)가 즉시 보인다.
      expect(find.byIcon(Icons.add_rounded), findsNWidgets(2));
      // 할 일이 없으므로 넛지 배지도 없다.
      expect(find.text('1'), findsNothing);
    });

    testWidgets('고정 슬롯의 촬영본은 탭하면 곧장 고객 연결로 간다 (헌법 3)', (tester) async {
      BaCaptureSession? bound;
      final pending = _draft(id: 'p', before: 'https://x/b.webp');

      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: const [],
            pending: pending,
            onCapture: (_, _) {},
            onBind: (s) => bound = s,
            onDefer: (_) {},
            onOpen: (_) {},
          ),
        ),
      );

      // 고정 슬롯은 여전히 1개다 — 사진이 들어와도 카드로 분리되지 않는다.
      expect(find.byKey(const Key('ba-fixed-capture-slot')), findsOneWidget);
      expect(find.text('B/A 촬영'), findsOneWidget);
      expect(find.text('1'), findsOneWidget, reason: '연결 대기 1건');

      expect(find.text('고객 연결'), findsOneWidget);
      await tester.tap(find.text('고객 연결'));
      await tester.pump();
      expect(bound?.id, 'p');
    });

    testWidgets('Before만 찍힌 세션은 🔴와 "After 필요" 배지', (tester) async {
      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: [_draft(id: 'a', before: 'https://x/b.webp')],
            onCapture: (_, _) {},
            onBind: (_) {},
            onDefer: (_) {},
            onOpen: (_) {},
          ),
        ),
      );

      expect(find.text('After 필요'), findsOneWidget);
      expect(find.text('1'), findsOneWidget, reason: '넛지 배지 카운트');
    });

    testWidgets('두 장 다 찍혔지만 차트 미연동이면 "고객 연결" 액션이 뜬다', (tester) async {
      BaCaptureSession? bound;
      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: [
              _draft(
                id: 'a',
                before: 'https://x/b.webp',
                after: 'https://x/a.webp',
              ),
            ],
            onCapture: (_, _) {},
            onBind: (s) => bound = s,
            onDefer: (_) {},
            onOpen: (_) {},
          ),
        ),
      );

      expect(find.text('고객 연결'), findsOneWidget);
      await tester.tap(find.text('고객 연결'));
      await tester.pump();
      expect(bound?.id, 'a');
    });

    testWidgets('이관 중 카드는 320ms 동안 제자리에서 확정된다 (Q3a)', (tester) async {
      final session = _draft(
        id: 'a',
        before: 'https://x/b.webp',
        after: 'https://x/a.webp',
        label: '최진실님',
      );

      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: [session],
            transferringId: 'a',
            onCapture: (_, _) {},
            onBind: (_) {},
            onDefer: (_) {},
            onOpen: (_) {},
          ),
        ),
      );

      // index 0은 "새 촬영" 카드이므로, 이관 대상은 두 번째 카드다.
      final scales =
          tester.widgetList<AnimatedScale>(find.byType(AnimatedScale)).toList();
      expect(scales.length, 2);
      expect(scales.first.scale, 1.0, reason: '새 촬영 카드는 정지');

      final transferring = scales[1];
      expect(transferring.duration, HomeVisualTokens.baTransferDuration);
      expect(transferring.duration, const Duration(milliseconds: 320));
      expect(transferring.scale, greaterThan(1.0), reason: '제자리 확정 팝');

      // v7.0.2 — 캐러셀 밖으로 밀어내지 않는다.
      expect(find.byType(AnimatedSlide), findsNothing);

      // 이관 중에는 고객 연결 액션을 감춘다 (중복 바인딩 방지).
      expect(find.text('고객 연결'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('밀어둔 세션도 넛지 카운트에 남는다', (tester) async {
      final deferred = BaCaptureSession(
        id: 'd',
        shopId: 'shop-1',
        sessionToken: 'token-d',
        beforeImageUrl: 'https://x/b.webp',
        deferredAt: DateTime(2026, 9, 2, 9),
        createdAt: DateTime(2026, 9, 2, 8),
      );

      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: [deferred],
            onCapture: (_, _) {},
            onBind: (_) {},
            onDefer: (_) {},
            onOpen: (_) {},
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    });

    testWidgets('🟢 완성 카드는 캐러셀에 남고, 탭하면 뷰어로 열린다', (tester) async {
      BaCaptureSession? opened;
      final done = BaCaptureSession(
        id: 'done',
        shopId: 'shop-1',
        sessionToken: 'token-done',
        beforeImageUrl: 'https://x/b.webp',
        afterImageUrl: 'https://x/a.webp',
        chartId: 'chart-1',
        status: BaCaptureStatus.linked,
        createdAt: DateTime(2026, 9, 2, 8),
      );

      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: [done],
            onCapture: (_, _) => fail('완성 카드는 촬영을 다시 열지 않는다'),
            onBind: (_) {},
            onDefer: (_) {},
            onOpen: (s) => opened = s,
          ),
        ),
      );

      expect(find.text('완료'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      // 완성 카드에는 후순위화/연결 액션이 없다.
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.text('고객 연결'), findsNothing);
      // 미완성이 없으므로 넛지 배지도 뜨지 않는다.
      expect(find.text('1'), findsNothing);

      await tester.tap(find.byType(InkWell).last);
      await tester.pump();
      expect(opened?.id, 'done');
    });

    testWidgets('🔴 미완성이 앞, 🟢 완성이 뒤에 배치된다', (tester) async {
      final done = BaCaptureSession(
        id: 'done',
        shopId: 'shop-1',
        sessionToken: 'token-done',
        beforeImageUrl: 'https://x/b.webp',
        afterImageUrl: 'https://x/a.webp',
        chartId: 'chart-1',
        status: BaCaptureStatus.linked,
        createdAt: DateTime(2026, 9, 2, 12),
      );
      final todo = _draft(id: 'todo', before: 'https://x/b.webp');

      // 스토어가 넘겨주는 정렬과 동일하게 정렬해 전달한다.
      final ordered = [done, todo]..sort(BaCaptureSession.carouselOrder);

      await tester.pumpWidget(
        _host(
          BaCaptureCarousel(
            sessions: ordered,
            onCapture: (_, _) {},
            onBind: (_) {},
            onDefer: (_) {},
            onOpen: (_) {},
          ),
        ),
      );

      final todoX = tester.getTopLeft(find.text('After 필요')).dx;
      final doneX = tester.getTopLeft(find.text('완료')).dx;
      expect(todoX, lessThan(doneX), reason: '🔴 → 🟢 순서');
      expect(find.text('1'), findsOneWidget, reason: '넛지는 미완성 1건만');
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

      expect(find.text('오늘 예약된 일정이 없습니다'), findsOneWidget);
    });

    testWidgets('일정이 2건 이상이면 +N 칩이 붙는다', (tester) async {
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
        CareScheduleEntry(
          id: 'e2',
          shopId: store.shop.id,
          scheduledAt: DateTime(today.year, today.month, today.day, 15),
          customerName: '최진실',
          careLabel: '웨딩케어',
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
