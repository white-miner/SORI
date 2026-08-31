import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/features/visit/ba_recall_cache.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/home_care_prescriptions.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/models/subscription.dart';
import 'package:sori/services/presence_helper.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BaRecallCache', () {
    test('prefetch marks customer warm under SLA budget', () async {
      final store = SoriStore();
      await store.bootstrap(repository: MemorySoriRepository());
      BaRecallCache.instance.invalidateAll();

      if (store.customers.isEmpty) return;
      final customer = store.customers.first;

      if (store.chartsForCustomer(customer.id).isEmpty) {
        store.charts.add(
          CustomerChart(
            id: 'ba-test-chart',
            shopId: store.shop.id,
            customerId: customer.id,
            visitNumber: 1,
            beforeImageUrl: 'https://example.com/b.jpg',
            afterImageUrl: 'https://example.com/a.jpg',
          ),
        );
      }

      final sw = Stopwatch()..start();
      await BaRecallCache.instance.prefetch(store, customer.id);
      sw.stop();

      expect(BaRecallCache.instance.isWarm(customer.id), isTrue);
      expect(
        sw.elapsed,
        lessThan(BaRecallCache.warmSla),
        reason: 'metadata prefetch itself must stay well under warm SLA',
      );
      expect(BaRecallCache.instance.thumbsFor(customer.id), isNotEmpty);
    });

    test('warm open path reads cache without rebuild wait', () async {
      final store = SoriStore();
      await store.bootstrap(repository: MemorySoriRepository());
      BaRecallCache.instance.invalidateAll();
      if (store.customers.isEmpty) return;

      final customer = store.customers.first;
      store.charts.add(
        CustomerChart(
          id: 'ba-warm-2',
          shopId: store.shop.id,
          customerId: customer.id,
          visitNumber: 2,
          beforeImageUrl: 'https://example.com/b2.jpg',
          afterImageUrl: 'https://example.com/a2.jpg',
        ),
      );

      await BaRecallCache.instance.prefetch(store, customer.id);

      final sw = Stopwatch()..start();
      final thumbs = BaRecallCache.instance.thumbsFor(customer.id);
      final warm = BaRecallCache.instance.isWarm(customer.id);
      sw.stop();

      expect(warm, isTrue);
      expect(thumbs, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });

  group('PlanPhase chart wiring', () {
    test('updateCustomerChartFields persists summary + prescriptions', () async {
      final store = SoriStore();
      await store.bootstrap(repository: MemorySoriRepository());
      store.session = const SessionUser(
        role: UserRole.director,
        name: '김원장',
        phone: '010',
        provider: SocialProvider.kakao,
        onboardingComplete: true,
        shopSetupComplete: true,
        activeMode: UserRole.director,
      );

      if (store.customers.isEmpty) return;
      final customer = store.customers.first;
      final existing = store.chartsForCustomer(customer.id);
      final chart = existing.isNotEmpty
          ? existing.first
          : CustomerChart(
              id: 'plan-chart-1',
              shopId: store.shop.id,
              customerId: customer.id,
              visitNumber: 1,
            );
      if (existing.isEmpty) store.charts.add(chart);

      final tags = HomecareDictionary.sanitizeTagIds(const [
        'tag_sun',
        'tag_water',
      ]);

      final updated = await store.updateCustomerChartFields(
        chartId: chart.id,
        treatmentSummary: '다음 회차 장벽 강화 + 수분 집중',
        homeCarePrescriptions: tags,
      );

      expect(updated.treatmentSummary, contains('장벽 강화'));
      expect(updated.homeCarePrescriptions, containsAll(tags));

      final reloaded = store.findChartById(chart.id);
      expect(reloaded?.treatmentSummary, contains('장벽 강화'));
      expect(reloaded?.homeCarePrescriptions, containsAll(tags));
    });
  });

  group('Presence last_seen_at', () {
    test('DiscoverDirector parses last_seen_at and online ring', () {
      final now = DateTime.now();
      final director = DiscoverDirector.fromMap({
        'shop_id': 's1',
        'shop_name': '테스트샵',
        'nickname': '멘토원장',
        'last_seen_at': now.toUtc().toIso8601String(),
      });
      expect(director.lastSeenAt, isNotNull);
      expect(PresenceHelper.isOnline(director.lastSeenAt), isTrue);

      final stale = DiscoverDirector.fromMap({
        'shop_id': 's2',
        'shop_name': '오프샵',
        'nickname': '자리비움',
        'last_seen_at':
            now.subtract(const Duration(minutes: 10)).toUtc().toIso8601String(),
      });
      expect(PresenceHelper.isOnline(stale.lastSeenAt), isFalse);
    });
  });
}
