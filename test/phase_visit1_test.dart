import 'package:flutter_test/flutter_test.dart';

import 'package:sori/visit_kernel/models/visit_session.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  test('startVisitSession creates chart draft and active session', () async {
    final store = SoriStore();
    if (store.customers.isEmpty) return;

    final customer = store.customers.first;
    final session = await store.startVisitSession(customerId: customer.id);

    expect(session.customerId, customer.id);
    expect(session.phase, VisitPhase.shoot);
    expect(session.chartDraftId, isNotNull);
    expect(store.activeVisitSession?.id, session.id);
    expect(store.chartForVisitSession(session), isNotNull);
  });

  test('updateVisitPhase advances session lifecycle', () async {
    final store = SoriStore();
    if (store.customers.isEmpty) return;

    final session = await store.startVisitSession(
      customerId: store.customers.first.id,
    );

    await store.updateVisitPhase(session.id, VisitPhase.consult);
    final updated = store.findVisitSession(session.id);
    expect(updated?.phase, VisitPhase.consult);

    await store.updateVisitPhase(session.id, VisitPhase.done);
    expect(store.findVisitSession(session.id)?.phase, VisitPhase.done);
    expect(store.activeVisitSessionId, isNull);
  });

  test('visit snapshotForDay counts today sessions', () async {
    final store = SoriStore();
    await store.refreshVisitSessions(force: true);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);

    if (store.customers.isEmpty) {
      expect(store.visit.snapshotForDay(day).sessions.length, 0);
      return;
    }

    await store.startVisitSession(customerId: store.customers.first.id);
    final snap = store.visit.snapshotForDay(day);
    expect(snap.sessions.length, greaterThan(0));
  });
}
