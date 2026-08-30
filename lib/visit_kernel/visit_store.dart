import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/sori_store.dart';
import 'models/visit_session.dart';

/// Visit OS facade — SoriStore 위 얇은 SSOT (PRD v3.0 Phase 1).
class VisitStore extends ChangeNotifier {
  VisitStore(this._host) {
    _host.addListener(_onHostChanged);
  }

  final SoriStore _host;

  SoriStore get host => _host;

  List<VisitSession> get sessions => _host.visitSessions;

  VisitSession? get activeSession => _host.activeVisitSession;

  Customer? findCustomer(String id) => _host.findCustomer(id);

  CustomerChart? chartForSession(VisitSession session) =>
      _host.chartForVisitSession(session);

  void _onHostChanged() => notifyListeners();

  Future<void> ensureLoaded({bool force = false}) =>
      _host.refreshVisitSessions(force: force);

  VisitDaySnapshot snapshotForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final daySessions = sessions
        .where((s) => s.isSameDay(normalized))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    var active = 0;
    var done = 0;
    for (final s in daySessions) {
      if (s.phase == VisitPhase.done) {
        done++;
      } else {
        active++;
      }
    }

    return VisitDaySnapshot(
      day: normalized,
      sessions: daySessions,
      activeCount: active,
      completedCount: done,
    );
  }

  Future<VisitSession> startVisit(Customer customer) =>
      _host.startVisitSession(customerId: customer.id);

  Future<void> setPhase(String sessionId, VisitPhase phase) =>
      _host.updateVisitPhase(sessionId, phase);

  Future<void> completeVisit(String sessionId) =>
      _host.updateVisitPhase(sessionId, VisitPhase.done);

  @override
  void dispose() {
    _host.removeListener(_onHostChanged);
    super.dispose();
  }
}
