import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';

void main() {
  test('toggle case bookmark persists in loadMyCaseBookmarks', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();

    final hot = await repo.loadCommunityHotCases(limit: 1);
    expect(hot, isNotEmpty);
    final chartId = hot.first.chart.id;

    final on = await repo.toggleCaseBookmark(chartId);
    expect(on.ok, isTrue);
    expect(on.bookmarked, isTrue);

    final rows = await repo.loadMyCaseBookmarks();
    expect(rows.map((e) => e.chartId), contains(chartId));

    final off = await repo.toggleCaseBookmark(chartId);
    expect(off.ok, isTrue);
    expect(off.bookmarked, isFalse);

    final after = await repo.loadMyCaseBookmarks();
    expect(after.map((e) => e.chartId), isNot(contains(chartId)));
  });

  test('loadChartBookmarkCounts reflects toggles', () async {
    MemorySoriRepository.resetFanBoostStateForTest();
    final repo = MemorySoriRepository();

    final hot = await repo.loadCommunityHotCases(limit: 2);
    expect(hot.length, greaterThanOrEqualTo(1));
    final chartId = hot.first.chart.id;

    await repo.toggleCaseBookmark(chartId);

    final counts = await repo.loadChartBookmarkCounts([chartId]);
    expect(counts[chartId], greaterThanOrEqualTo(1));
  });
}
