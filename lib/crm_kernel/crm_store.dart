import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import 'models/care_schedule_entry.dart';

/// CRM Kernel facade — SoriStore 위 얇은 CRM SSOT (Phase CRM-1).
class CrmStore extends ChangeNotifier {
  CrmStore(this._host) {
    _host.addListener(_onHostChanged);
  }

  final SoriStore _host;

  SoriStore get host => _host;

  List<Customer> get customers => _host.customers;

  Customer? findCustomer(String id) => _host.findCustomer(id);

  List<CustomerChart> chartsForCustomer(String id) =>
      _host.chartsForCustomer(id);

  CustomerChart? latestChart(String customerId) =>
      _host.latestChart(customerId);

  List<CareScheduleEntry> get scheduleEntries => _host.careScheduleEntries;

  void _onHostChanged() => notifyListeners();

  Future<void> ensureScheduleLoaded({bool force = false}) =>
      _host.refreshCareScheduleEntries(force: force);

  TodayBoardSnapshot snapshotForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final entries = _host.careScheduleEntries
        .where((e) =>
            e.isSameDay(normalized) &&
            e.status != CareScheduleStatus.cancelled)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final orbitItems = <TodayOrbitItem>[];
    var completed = 0;
    var unwritten = 0;
    var leads = 0;

    for (final entry in entries) {
      final cid = entry.customerId?.trim();
      Customer? customer;
      if (cid != null && cid.isNotEmpty) {
        customer = findCustomer(cid);
      }

      final chartsToday = cid != null && cid.isNotEmpty
          ? _host.chartsCreatedOnDate(normalized).where((c) => c.customerId == cid)
          : const <CustomerChart>[];
      final hasChart = chartsToday.isNotEmpty;

      if (entry.status == CareScheduleStatus.completed || hasChart) {
        completed++;
      } else {
        unwritten++;
      }
      if (entry.source == CareScheduleSource.customerLead) leads++;

      final remain = customer == null
          ? 0
          : _membershipRemain(customer);

      orbitItems.add(
        TodayOrbitItem(
          entry: entry,
          customerId: cid,
          displayName: customer?.name.trim().isNotEmpty == true
              ? customer!.name.trim()
              : entry.customerName.trim(),
          timeLabel: _formatTime(entry.scheduledAt),
          careLabel: entry.careLabel.trim().isNotEmpty
              ? entry.careLabel.trim()
              : '케어 예정',
          membershipRemain: remain,
          hasChartToday: hasChart,
          isLead: entry.source == CareScheduleSource.customerLead,
        ),
      );
    }

    final scheduled = entries.length;
    final ratio = scheduled == 0 ? 0.0 : completed / scheduled;

    return TodayBoardSnapshot(
      day: normalized,
      scheduledCount: scheduled,
      completedCount: completed,
      unwrittenCount: unwritten,
      leadCount: leads,
      orbitItems: orbitItems,
      progressRatio: ratio.clamp(0, 1),
    );
  }

  /// 오늘 작성되지 않은 차트 — 어제까지 방문했으나 오늘 차트 없는 고객 힌트.
  List<Customer> customersNeedingChartHint(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final today = DateTime.now();
    if (normalized.year != today.year ||
        normalized.month != today.month ||
        normalized.day != today.day) {
      return const [];
    }

    final scheduledIds = scheduleEntries
        .where((e) => e.isSameDay(normalized))
        .map((e) => e.customerId?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final out = <Customer>[];
    for (final c in customers) {
      if (scheduledIds.contains(c.id)) continue;
      final last = c.lastTreatmentDate;
      if (last.year != today.year ||
          last.month != today.month ||
          last.day != today.day) {
        continue;
      }
      final wroteToday = _host
          .chartsCreatedOnDate(normalized)
          .any((ch) => ch.customerId == c.id);
      if (!wroteToday) out.add(c);
    }
    return out;
  }

  int _membershipRemain(Customer c) {
    if (c.isMembershipCustomer) return c.membershipRemainingVisits;
    return _host.membershipTickets
        .where((t) => t.customerId == c.id && t.isActive)
        .fold<int>(0, (sum, t) => sum + t.remainingVisits);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<CareScheduleEntry> addManualSchedule({
    required DateTime scheduledAt,
    required String customerName,
    String? customerId,
    String? customerPhone,
    String careLabel = '',
    String note = '',
  }) {
    return _host.addManualCareSchedule(
      scheduledAt: scheduledAt,
      customerName: customerName,
      customerId: customerId,
      customerPhone: customerPhone,
      careLabel: careLabel,
      note: note,
    );
  }

  Future<CareScheduleEntry> submitCustomerLead({
    required String shopId,
    required String customerName,
    required String customerPhone,
    required DateTime preferredAt,
    String careLabel = '',
    String note = '',
  }) {
    return _host.submitCareScheduleLead(
      shopId: shopId,
      customerName: customerName,
      customerPhone: customerPhone,
      preferredAt: preferredAt,
      careLabel: careLabel,
      note: note,
    );
  }

  Future<void> markScheduleCompleted(String entryId) =>
      _host.updateCareScheduleStatus(entryId, CareScheduleStatus.completed);

  Future<void> cancelSchedule(String entryId) =>
      _host.updateCareScheduleStatus(entryId, CareScheduleStatus.cancelled);

  @override
  void dispose() {
    _host.removeListener(_onHostChanged);
    super.dispose();
  }
}
