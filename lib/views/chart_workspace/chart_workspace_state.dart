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
  const CustomerFileRailItem({required this.customer, required this.label});

  final Customer customer;
  final String label;

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

/// No 미연결 전환기: 가짜 No.N 금지. 이름 기반 임시 라벨.
String fileRailLabelFor(Customer customer) {
  final name = customer.name.trim();
  if (name.isEmpty) return '파일';
  return name.length <= 4 ? name : '${name.substring(0, 4)}';
}

List<FileRailItem> buildFileRailItems(SoriStore store) {
  final customers = List<Customer>.of(store.customers)
    ..sort((a, b) => a.name.compareTo(b.name));
  return [
    const NewCustomerFileRailItem(),
    ...customers.map(
      (c) => CustomerFileRailItem(customer: c, label: fileRailLabelFor(c)),
    ),
  ];
}

String formatChartDate(DateTime? t) {
  final s = seoulNow(t ?? DateTime.now());
  final mm = s.month.toString().padLeft(2, '0');
  final dd = s.day.toString().padLeft(2, '0');
  return '${s.year}.$mm.$dd';
}
