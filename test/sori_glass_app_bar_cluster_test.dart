import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/widgets/glass/sori_glass_app_bar_cluster.dart';
import 'package:sori/widgets/glass/sori_glass_overlay.dart';

void main() {
  testWidgets('GNB cluster renders four dark icons inside a glass pill', (tester) async {
    var tapped = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              SoriGlassAppBarCluster(
                items: [
                  SoriGlassAppBarItem(
                    icon: Icons.add_rounded,
                    tooltip: '새 게시물',
                    onPressed: () => tapped = 'compose',
                  ),
                  SoriGlassAppBarItem(
                    icon: Icons.notifications_rounded,
                    tooltip: '알림',
                    onPressed: () => tapped = 'bell',
                    badgeCount: 2,
                  ),
                  SoriGlassAppBarItem(
                    icon: Icons.inventory_2_rounded,
                    tooltip: '보관함',
                    onPressed: () => tapped = 'archive',
                  ),
                  SoriGlassAppBarItem(
                    icon: Icons.settings_rounded,
                    tooltip: '설정',
                    onPressed: () => tapped = 'settings',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SoriGlassAppBarCluster), findsOneWidget);
    expect(find.byType(SoriGlassOverlay), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

    final addIcon = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
    expect(addIcon.color, Colors.black87);
    expect(addIcon.size, greaterThanOrEqualTo(22));

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(tapped, 'compose');
  });
}
