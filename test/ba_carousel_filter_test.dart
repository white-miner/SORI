import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/visit/home_visual_tokens.dart';
import 'package:sori/features/visit/widgets/ba_capture_carousel.dart';
import 'package:sori/models/ba_capture_session.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: HomeVisualTokens.canvasBg,
      body: child,
    ),
  );
}

BaCaptureSession _session({
  required String id,
  required String label,
  required bool complete,
}) {
  return BaCaptureSession(
    id: id,
    shopId: 'shop-1',
    sessionToken: 'token-$id',
    beforeImageUrl: 'https://x/$id-b.webp',
    afterImageUrl: complete ? 'https://x/$id-a.webp' : null,
    chartId: complete ? 'chart-$id' : null,
    label: label,
    createdAt: DateTime(2026, 9, 2, 9),
  );
}

void main() {
  testWidgets('미완성만 보면 🟢가 빠지고 고정 슬롯은 남는다', (tester) async {
    await tester.pumpWidget(
      _host(
        BaCaptureCarousel(
          sessions: [
            _session(id: 'red', label: '수분관리', complete: false),
            _session(id: 'green', label: '완성케어', complete: true),
          ],
          onCapture: (_, _) {},
          onBind: (_) {},
          onDefer: (_) {},
          onOpen: (_) {},
        ),
      ),
    );

    expect(find.text('수분관리'), findsOneWidget);
    expect(find.text('완성케어'), findsOneWidget);
    expect(find.byKey(const Key('ba-fixed-capture-slot')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ba-filter-incomplete')));
    await tester.pump();

    expect(find.byKey(const Key('ba-fixed-capture-slot')), findsOneWidget);
    expect(find.text('수분관리'), findsOneWidget);
    expect(find.text('완성케어'), findsNothing);
  });

  testWidgets('완성만 보면 🔴가 빠지고 없으면 안내 문구가 뜬다', (tester) async {
    await tester.pumpWidget(
      _host(
        BaCaptureCarousel(
          sessions: [
            _session(id: 'red', label: '수분관리', complete: false),
          ],
          onCapture: (_, _) {},
          onBind: (_) {},
          onDefer: (_) {},
          onOpen: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ba-filter-complete')));
    await tester.pump();

    expect(find.byKey(const Key('ba-fixed-capture-slot')), findsOneWidget);
    expect(find.text('수분관리'), findsNothing);
    expect(find.text('완성된 촬영이 없습니다'), findsOneWidget);
  });
}
