import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/views/chart_workspace/chart_index_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChartIndexPaletteStore.instance.debugResetForTest();
  });

  test('default palette matches the 0~9 spec', () {
    final store = ChartIndexPaletteStore.instance;
    expect(store.colorForDigit(0), const Color(0xFFFFFFFF)); // 흰색
    expect(store.colorForDigit(1), const Color(0xFFE53935)); // 빨강
    expect(store.colorForDigit(4), const Color(0xFF43A047)); // 초록
    expect(store.colorForDigit(9), const Color(0xFF757575)); // 회색
  });

  test('colorForNumber uses the last digit, not the whole number', () {
    final store = ChartIndexPaletteStore.instance;
    expect(store.colorForNumber(10), store.colorForDigit(0));
    expect(store.colorForNumber(21), store.colorForDigit(1));
    expect(store.colorForNumber(76), store.colorForDigit(6));
    expect(chartIndexLastDigit(130), 0);
  });

  test('신규/신규 작성 fixed color is independent of the palette', () {
    expect(kChartIndexNoNumberColor, isNot(kDefaultChartIndexPalette[0]));
    expect(kChartIndexNoNumberColor, const Color(0xFF8B5CF6));
  });

  test('setColor overrides one digit only and persists', () async {
    final store = ChartIndexPaletteStore.instance;
    const newRed = Color(0xFF123456);
    await store.setColor(1, newRed);

    expect(store.colorForDigit(1), newRed);
    // 다른 자리는 그대로.
    expect(store.colorForDigit(2), kDefaultChartIndexPalette[2]);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sori_chart_index_palette_v1');
    expect(raw, isNotNull);
    expect(raw, contains('${newRed.toARGB32()}'));
  });

  test('resetToDefault clears overrides and storage', () async {
    final store = ChartIndexPaletteStore.instance;
    await store.setColor(3, const Color(0xFF000000));
    expect(store.colorForDigit(3), const Color(0xFF000000));

    await store.resetToDefault();
    expect(store.colorForDigit(3), kDefaultChartIndexPalette[3]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sori_chart_index_palette_v1'), isNull);
  });

  test('notifies listeners on change', () async {
    final store = ChartIndexPaletteStore.instance;
    var notified = 0;
    void listener() => notified++;
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));

    await store.setColor(5, const Color(0xFF222222));
    expect(notified, greaterThan(0));
  });
}
