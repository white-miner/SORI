import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/community_case_item.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/sori_post_original_page.dart';
import 'package:sori/widgets/post/post_action_row.dart';
import 'package:sori/widgets/post/post_header.dart';
import 'package:sori/widgets/post/post_interaction_sidebar.dart';
import 'package:sori/widgets/post/post_layout_breakpoints.dart';
import 'package:sori/widgets/post/post_media_section.dart';
import 'package:sori/widgets/post/post_view_data.dart';

void main() {
  late SoriStore store;

  setUp(() async {
    store = SoriStore.instance;
    await store.bootstrap(repository: MemorySoriRepository());
  });

  PostViewData baData() {
    final chart = CustomerChart(
      id: 'split-chart',
      shopId: store.shop.id,
      customerId: 'cust',
      visitNumber: 3,
      treatmentSummary: '페이스 관리',
    );
    return PostViewData.fromCaseItem(
      CommunityCaseItem(
        chart: chart,
        shop: Shop(
          id: store.shop.id,
          name: 'SORI 샵',
          naverPlaceUrl: '',
        ),
        careTags: const ['장벽'],
      ),
    );
  }

  testWidgets('desktop width renders split-pane with sticky sidebar', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SoriPostOriginalPage(data: baData(), store: store),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PostInteractionSidebar), findsOneWidget);
    expect(find.text('B/A 케이스 댓글은 홈 피드에서 확인할 수 있어요.'), findsNothing);
  });

  testWidgets('desktop: PostHeader above media on left; sidebar has no header', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SoriPostOriginalPage(data: baData(), store: store),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Exactly one author header — on the left post column, not duplicated in sidebar.
    expect(find.byType(PostHeader), findsOneWidget);
    expect(find.byType(PostInteractionSidebar), findsOneWidget);

    final headerRect = tester.getRect(find.byType(PostHeader));
    final mediaRect = tester.getRect(find.byType(PostMediaSection));
    final actionRect = tester.getRect(find.byType(PostActionRow));
    final sidebarRect = tester.getRect(find.byType(PostInteractionSidebar));

    // Hierarchy: Header → Media → … → ActionDock (top-to-bottom).
    expect(headerRect.bottom, lessThanOrEqualTo(mediaRect.top + 1));
    expect(mediaRect.bottom, lessThanOrEqualTo(actionRect.top + 1));

    // Header lives in left column, not inside the comment sidebar.
    expect(headerRect.right, lessThanOrEqualTo(sidebarRect.left + 1));

    // Sidebar title is simple "댓글".
    expect(
      find.descendant(
        of: find.byType(PostInteractionSidebar),
        matching: find.text('댓글'),
      ),
      findsOneWidget,
    );

    // Wrap-content: post column shorter than viewport (no stretch to fill height).
    final columnRect = tester.getRect(find.byKey(const Key('post-original-main-column')));
    expect(columnRect.height, lessThan(850));
  });

  testWidgets('desktop split-pane is centered with tight gap between columns', (tester) async {
    const viewportWidth = 1600.0;
    tester.view.physicalSize = const Size(viewportWidth, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SoriPostOriginalPage(data: baData(), store: store),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final bundle = tester.getRect(find.byKey(const Key('desktop-split-pane-bundle')));
    final sidebar = tester.getRect(find.byType(PostInteractionSidebar));
    final postColumn = tester.getRect(find.byType(PostActionRow));
    final gap = sidebar.left - postColumn.right;

    expect(bundle.width, lessThanOrEqualTo(PostLayoutBreakpoints.splitPaneMaxWidth));
    expect((viewportWidth - bundle.width) / 2, closeTo(bundle.left, 1));
    expect(gap, closeTo(PostLayoutBreakpoints.splitPaneGap, 2));
    expect(
      sidebar.width,
      closeTo(PostLayoutBreakpoints.sidebarWidth, 1),
    );
    expect(find.byIcon(Icons.send_rounded), findsWidgets);
    expect(find.text('댓글을 입력하세요'), findsOneWidget);
  });

  testWidgets('mobile width keeps single column without sidebar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SoriPostOriginalPage(data: baData(), store: store),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PostInteractionSidebar), findsNothing);
    expect(find.text('댓글'), findsWidgets);
  });

  test('PostLayoutBreakpoints enforces 1024 desktop gate', () {
    expect(PostLayoutBreakpoints.isDesktopLayout(1024), isTrue);
    expect(PostLayoutBreakpoints.isDesktopLayout(1023), isFalse);
  });
}
