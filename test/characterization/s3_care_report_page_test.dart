// S3-0 특성 테스트: 케어 리포트 화면(/care-report/:chartId)이 데이터를 얻는 방식.
//
// 지금은 ① 스토어 메모리에서 chartId 로 차트를 찾고 ② 없으면 저장소
// loadPublicCareReport(chartId)를 부른다. 고객 이름은 가리지 않는다.
// 보안 S3 PR 3-3에서 토큰 + Edge `care-report` 로 바뀌면 이 기대값을 그 PR에서 고친다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/kakao_alimtalk.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/views/care_report_page.dart';

const _remoteChartId = '418de1ef-0000-4000-8000-0000000000aa';

class _SpyRepository extends MemorySoriRepository {
  final List<String> requested = [];

  @override
  Future<PublicCareReport?> loadPublicCareReport(String chartId) async {
    requested.add(chartId);
    if (chartId != _remoteChartId) return null;
    return const PublicCareReport(
      chart: CustomerChart(
        id: _remoteChartId,
        shopId: 'shop-remote',
        customerId: 'cu-remote',
        visitNumber: 4,
        careName: '윤곽케어',
        treatmentSummary: '라인 정리 집중',
      ),
      shop: Shop(
        id: 'shop-remote',
        name: '원격 테스트샵',
        ownerName: '박원장',
        phone: '02-000-0000',
        naverPlaceUrl: '',
        address: '',
      ),
      customerDisplayName: '박지은',
    );
  }
}

CustomerChart _localChart(SoriStore store) {
  return store.saveChartAndConfirmVisit(
    customerId: '1',
    visitNumber: 2,
    customChartNo: 'S3-CR',
    careName: '재생케어',
    treatmentSummary: '장벽 진정 2회차',
    directorInsight: '안정',
    concernChips: const ['건조/장벽'],
    firstVisitFearChips: const [],
    revisitFeedbackChips: const [],
  );
}

Future<void> _pumpPage(WidgetTester tester, SoriStore store, String id) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CareReportPage(store: store, chartId: id),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('S3-0 케어 리포트 화면 특성', () {
    testWidgets('메모리에 있는 차트는 저장소를 부르지 않고 바로 그린다 (전체 이름 표시)', (tester) async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      final chart = _localChart(store);

      await _pumpPage(tester, store, chart.id);

      expect(repo.requested, isEmpty);
      expect(find.text(store.shop.name), findsWidgets);
      expect(find.text('김민지님의 케어 리포트'), findsOneWidget);
      expect(find.text('회차 2 · 재생케어'), findsOneWidget);
      expect(find.text('장벽 진정 2회차'), findsOneWidget);
      expect(find.text('Before / After'), findsOneWidget);
    });

    testWidgets('메모리에 없는 chartId 는 저장소 loadPublicCareReport(chartId)로 조회한다', (
      tester,
    ) async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);

      await _pumpPage(tester, store, _remoteChartId);

      expect(repo.requested, [_remoteChartId]);
      expect(find.text('원격 테스트샵'), findsWidgets);
      expect(find.text('박지은님의 케어 리포트'), findsOneWidget);
      expect(find.text('회차 4 · 윤곽케어'), findsOneWidget);
    });

    testWidgets('어디에도 없는 chartId 는 "유효하지 않은 케어 리포트 링크" 안내', (tester) async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);

      await _pumpPage(tester, store, 'not-a-chart');

      expect(repo.requested, ['not-a-chart']);
      expect(find.text('유효하지 않은 케어 리포트 링크입니다'), findsOneWidget);
    });

    test('loadPublicCareReport: 메모리 차트의 샵이 다르면 현재 샵 정보에 id 만 바꿔 쓴다', () async {
      final store = SoriStore(repository: _SpyRepository());
      final chart = _localChart(store);
      final foreign = chart.copyWith(id: 's3-foreign', shopId: 'shop-other');
      store.charts.add(foreign);

      final report = await store.loadPublicCareReport('s3-foreign');

      expect(report, isNotNull);
      expect(report!.shop.id, 'shop-other');
      expect(report.shop.name, store.shop.name);
      expect(report.customerDisplayName, '김민지');
    });
  });
}
