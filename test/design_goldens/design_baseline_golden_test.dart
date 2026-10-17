// D0-1 디자인 골든 기준선 — 디자인 개편 전 12개 화면을 360px · 1280px 로 고정한다.
//
// 동작 변경 없음. 디자인 PR(D0-2 이후)이 화면을 바꾸면 이 골든이 차이를 보여 준다.
// 실행·갱신 방법은 test/design_goldens/README.md 참고:
//   tool/design_goldens.sh            # 비교
//   tool/design_goldens.sh --update   # 갱신(PR 에 전후 이미지 첨부)
// SORI_DESIGN_GOLDENS=1 이 아니면 전부 skip 된다(일반 flutter test 영향 없음).
// '오늘'이 보이는 화면은 기준선 날짜(2026-10-17 KST)가 아니면 달라진다 — README 참고.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/features/chart_visit/chart_visit_home_page.dart';
import 'package:sori/features/chart_visit/chart_visit_live.dart';
import 'package:sori/features/crm_today/care_schedule_lead_page.dart';
import 'package:sori/features/visit/visit_launcher_page.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/theme/app_theme.dart';
import 'package:sori/views/before_after_compare_page.dart';
import 'package:sori/views/care_report_page.dart';
import 'package:sori/views/community_page.dart';
import 'package:sori/views/customer_chart/customer_chart_page.dart';
import 'package:sori/views/director_customers_tab.dart';
import 'package:sori/views/director_fandom_profile_page.dart';
import 'package:sori/views/entry_home_page.dart';

import 'support/design_golden_harness.dart';

const _shopLinkId = '00000000-0000-4000-8000-0000000000f2';

CustomerChart _ba(
  SoriStore store,
  String id,
  String customerId,
  int visit,
  String care,
  DateTime at,
) {
  return CustomerChart(
    id: id,
    shopId: store.shop.id,
    customerId: customerId,
    visitNumber: visit,
    careName: care,
    treatmentSummary: '$care $visit회차',
    beforeImageUrl: 'https://example.com/golden/$id-before.png',
    afterImageUrl: 'https://example.com/golden/$id-after.png',
    createdAt: at,
  );
}

void _seedBa(SoriStore store) {
  final c = store.customers.first.id;
  store.charts.insertAll(0, [
    _ba(store, 'g-ba-3', c, 3, '진정·수분관리', DateTime(2026, 10, 16, 15)),
    _ba(store, 'g-ba-2', c, 2, '장벽관리', DateTime(2026, 10, 9, 14)),
    _ba(store, 'g-ba-1', c, 1, '첫 방문 진정케어', DateTime(2026, 10, 2, 11)),
  ]);
}

typedef _Build = Future<Widget> Function(SoriStore store);

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.theme,
  home: home,
);

final Map<String, _Build> _screens = {
  '01_login': (s) async => _app(const EntryHomePage()),
  '02_desk_empty': (s) async {
    s.charts.clear();
    return _app(Scaffold(body: VisitLauncherPage(store: s)));
  },
  '03_desk_records': (s) async {
    _seedBa(s);
    return _app(Scaffold(body: VisitLauncherPage(store: s)));
  },
  '04_customer_list': (s) async =>
      _app(Scaffold(body: DirectorCustomersTab(store: s))),
  '05_customer_chart': (s) async {
    _seedBa(s);
    final id = s.customers.first.id;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => CustomerChartPage(store: s, customerId: id),
          ),
        ],
      ),
    );
  },
  '06_chart_visit_preview': (s) async {
    bindChartVisitRoute(s, '');
    return _app(const ChartVisitRoutePage());
  },
  '07_ba_detail': (s) async {
    _seedBa(s);
    final c = s.customers.first;
    return _app(
      BeforeAfterComparePage(
        customerName: c.name,
        charts: s.charts.where((x) => x.id.startsWith('g-ba')).toList(),
        initialChartId: 'g-ba-3',
      ),
    );
  },
  '08_community_feed': (s) async => _app(CommunityPage(store: s)),
  '09_owner_profile_gallery': (s) async {
    _seedBa(s);
    return _app(DirectorFandomProfilePage(store: s, isOwner: false));
  },
  '10_care_request': (s) async =>
      _app(CareScheduleLeadPage(store: s, shopId: _shopLinkId)),
  '11_care_report': (s) async {
    final chart = s.saveChartAndConfirmVisit(
      customerId: s.customers.first.id,
      visitNumber: 3,
      customChartNo: 'G-CR',
      careName: '진정·수분관리',
      treatmentSummary: '홍조 진정 3회차',
      directorInsight: '장벽이 안정되고 있어요',
      concernChips: const ['건조/장벽'],
      firstVisitFearChips: const [],
      revisitFeedbackChips: const [],
    );
    return _app(CareReportPage(store: s, chartId: chart.id));
  },
  '12_care_report_expired': (s) async =>
      _app(CareReportPage(store: s, chartId: 'expired-or-unknown')),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useDesignGoldens('test/design_goldens/design_baseline_golden_test.dart');
  installGoldenFontAssets();

  final skip = !designGoldensEnabled;

  for (final width in designGoldenWidths) {
    for (final entry in _screens.entries) {
      final name = '${entry.key}_${width.toInt()}';
      testWidgets(name, skip: skip, (tester) async {
        SharedPreferences.setMockInitialValues({});
        await HttpOverrides.runWithHttpOverrides(() async {
          await tester.runAsync(loadDesignGoldenFonts);
          final size = Size(width, width < 600 ? 780 : 800);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final store = SoriStore(repository: MemorySoriRepository());
          await tester.pumpWidget(await entry.value(store));
          await settleFrames(tester);
          await waitForImages(tester);
          await settleFrames(tester, frames: 5);

          await expectLater(
            find.byType(MaterialApp).first,
            matchesGoldenFile('goldens/$name.png'),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await settleFrames(tester, frames: 3);
          // 화면이 남긴 지연 타이머(토스트·폴링 등)를 흘려보낸다.
          await tester.pump(const Duration(minutes: 2));
        }, GoldenImageHttpOverrides());
      });
    }
  }
}
