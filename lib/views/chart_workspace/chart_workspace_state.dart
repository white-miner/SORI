import '../../models/customer.dart';
import '../../models/customer_chart.dart';
import '../../services/sori_store.dart';

/// 서랍 뷰모델. Drawer DB 없음 — 기본 A만 runtime 제공.
class ChartDrawerViewModel {
  const ChartDrawerViewModel({required this.id, required this.label});

  final String id;
  final String label;
}

const kDefaultChartDrawer = ChartDrawerViewModel(id: 'drawer-a', label: '서랍 A');

/// 파일 rail 항목. `신규`는 맨 왼쪽.
sealed class FileRailItem {
  const FileRailItem();

  String get id;
}

class NewCustomerFileRailItem extends FileRailItem {
  const NewCustomerFileRailItem();

  @override
  String get id => 'file-new';
}

class CustomerFileRailItem extends FileRailItem {
  const CustomerFileRailItem({
    required this.customer,
    required this.displayNumber,
  });

  final Customer customer;

  /// 파일 rail 주 라벨용 순번. `customer_file_no`(DB) 미발급 상태의
  /// 정직한 대체값 — 등록순 1-based 위치. 저장/백필 없음(3차 이관).
  final int displayNumber;

  /// rail 주 라벨. 고객 이름은 대체하지 않는다.
  String get label => 'No.$displayNumber';

  @override
  String get id => 'file-${customer.id}';
}

/// 방문 rail 항목.
enum VisitRailKind { newDraft, today, existing }

class VisitRailItem {
  const VisitRailItem._({required this.kind, required this.id, this.chart});

  const VisitRailItem.newDraft()
    : this._(kind: VisitRailKind.newDraft, id: 'visit-new');

  factory VisitRailItem.today(CustomerChart chart) => VisitRailItem._(
    kind: VisitRailKind.today,
    id: 'visit-today-${chart.id}',
    chart: chart,
  );

  factory VisitRailItem.existing(CustomerChart chart) => VisitRailItem._(
    kind: VisitRailKind.existing,
    id: 'visit-${chart.id}',
    chart: chart,
  );

  final VisitRailKind kind;
  final String id;
  final CustomerChart? chart;

  String get label => switch (kind) {
    VisitRailKind.newDraft => '신규 작성',
    VisitRailKind.today => 'Today',
    VisitRailKind.existing => 'v${chart?.visitNumber ?? ''}',
  };
}

/// Seoul 달력일 기준 (UTC+9). visit_date 컬럼 미사용 — createdAt/visitCheckedAt.
DateTime seoulNow([DateTime? utcOrLocal]) {
  final src = utcOrLocal ?? DateTime.now();
  return src.toUtc().add(const Duration(hours: 9));
}

bool isSameSeoulDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  final sa = seoulNow(a);
  final sb = seoulNow(b);
  return sa.year == sb.year && sa.month == sb.month && sa.day == sb.day;
}

bool isTodaySeoul(DateTime? t) => isSameSeoulDay(t, DateTime.now());

DateTime? chartVisitInstant(CustomerChart chart) =>
    chart.createdAt ?? chart.visitCheckedAt;

CustomerChart? todayChartForCustomer(SoriStore store, String customerId) {
  final todays = store.chartsForCustomer(customerId).where((c) {
    return isTodaySeoul(chartVisitInstant(c));
  }).toList();
  if (todays.isEmpty) return null;
  todays.sort((a, b) => b.visitNumber.compareTo(a.visitNumber));
  return todays.first;
}

List<CustomerChart> pastChartsForCustomer(SoriStore store, String customerId) {
  return store.chartsForCustomer(customerId).where((c) {
    return !isTodaySeoul(chartVisitInstant(c));
  }).toList()..sort((a, b) => b.visitNumber.compareTo(a.visitNumber));
}

List<VisitRailItem> buildVisitRailItems(SoriStore store, String customerId) {
  final today = todayChartForCustomer(store, customerId);
  final past = pastChartsForCustomer(store, customerId);
  if (today != null) {
    return [VisitRailItem.today(today), ...past.map(VisitRailItem.existing)];
  }
  return [const VisitRailItem.newDraft(), ...past.map(VisitRailItem.existing)];
}

/// 파일 rail 순서 SSOT: 등록순(createdAt asc), 동률/결측은 id로 고정.
/// `customer_file_no`(DB 컬럼)는 아직 발급 로직이 없어 미사용 — 3차에서
/// 이 함수를 실제 발급값으로 교체한다. 정렬은 store.customers를 그대로
/// 두고 로컬 복사본에서만 수행(원본 순서·기존 참조 영향 없음).
List<Customer> orderedFileCustomers(SoriStore store) {
  final customers = List<Customer>.of(store.customers);
  customers.sort((a, b) {
    final at = a.createdAt;
    final bt = b.createdAt;
    if (at == null && bt == null) return a.id.compareTo(b.id);
    if (at == null) return 1;
    if (bt == null) return -1;
    final byTime = at.compareTo(bt);
    if (byTime != 0) return byTime;
    return a.id.compareTo(b.id);
  });
  return customers;
}

/// No.N 계산. 목록에 없으면(경합 등) 안전하게 끝번호로.
int fileDisplayNumberFor(SoriStore store, Customer customer) {
  final ordered = orderedFileCustomers(store);
  final idx = ordered.indexWhere((c) => c.id == customer.id);
  return idx == -1 ? ordered.length + 1 : idx + 1;
}

/// 파일철 문서 인덱스 헤더 라벨. "No.N · 고객이름" — 이름은 보조 정보.
String fileHeaderLabel(int displayNumber, Customer customer) {
  final name = customer.name.trim();
  return name.isEmpty ? 'No.$displayNumber' : 'No.$displayNumber · $name';
}

List<FileRailItem> buildFileRailItems(SoriStore store) {
  final customers = orderedFileCustomers(store);
  return [
    const NewCustomerFileRailItem(),
    for (var i = 0; i < customers.length; i++)
      CustomerFileRailItem(customer: customers[i], displayNumber: i + 1),
  ];
}

String formatChartDate(DateTime? t) {
  final s = seoulNow(t ?? DateTime.now());
  final mm = s.month.toString().padLeft(2, '0');
  final dd = s.day.toString().padLeft(2, '0');
  return '${s.year}.$mm.$dd';
}
