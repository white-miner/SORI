import '../../models/customer_chart.dart';
import 'home_visual_tokens.dart';

/// PRD v7.0 ④ — 관리 케이스 무한 스크롤 커서.
///
/// `OFFSET` 대신 (게시시각, id) 복합 키셋 커서를 쓴다. 스크롤 도중 새 케이스가
/// 상단에 추가돼도 이미 읽은 지점이 밀리지 않으므로 항목 중복·누락이 없다.
class ManagementCasePaginator {
  ManagementCasePaginator({this.pageSize = HomeVisualTokens.caseFeedPageSize});

  final int pageSize;

  final List<CustomerChart> _loaded = [];
  DateTime? _cursorAt;
  String? _cursorId;
  bool _exhausted = false;

  List<CustomerChart> get items => List.unmodifiable(_loaded);
  int get length => _loaded.length;
  bool get isEmpty => _loaded.isEmpty;
  bool get hasMore => !_exhausted;

  static DateTime _sortKey(CustomerChart c) =>
      c.feedPostedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// 커서보다 엄격히 뒤(더 오래된) 항목인지.
  bool _isAfterCursor(CustomerChart c) {
    final at = _cursorAt;
    final id = _cursorId;
    if (at == null || id == null) return true;
    final key = _sortKey(c);
    if (key.isBefore(at)) return true;
    if (key.isAtSameMomentAs(at)) return c.id.compareTo(id) < 0;
    return false;
  }

  /// [source]는 최신순으로 정렬된 전체 목록이어야 한다.
  /// 다음 페이지를 append하고, 실제로 추가된 개수를 반환한다.
  int loadMore(List<CustomerChart> source) {
    if (_exhausted) return 0;
    final seen = _loaded.map((c) => c.id).toSet();
    var added = 0;
    for (final chart in source) {
      if (added >= pageSize) break;
      if (!_isAfterCursor(chart)) continue;
      if (seen.contains(chart.id)) continue;
      _loaded.add(chart);
      seen.add(chart.id);
      _cursorAt = _sortKey(chart);
      _cursorId = chart.id;
      added++;
    }
    if (added < pageSize) _exhausted = true;
    return added;
  }

  /// 리프레시 — 커서를 처음으로 되감는다.
  void reset() {
    _loaded.clear();
    _cursorAt = null;
    _cursorId = null;
    _exhausted = false;
  }

  /// 이관 등으로 상단에 새 케이스가 생겼을 때, 커서를 건드리지 않고 앞에 끼운다.
  void prepend(CustomerChart chart) {
    if (_loaded.any((c) => c.id == chart.id)) return;
    _loaded.insert(0, chart);
  }

  /// 원본에서 갱신된 차트를 제자리 반영 (After 재촬영 등).
  void replace(CustomerChart chart) {
    final idx = _loaded.indexWhere((c) => c.id == chart.id);
    if (idx >= 0) _loaded[idx] = chart;
  }
}
