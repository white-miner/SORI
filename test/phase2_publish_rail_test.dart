import 'package:flutter_test/flutter_test.dart';

import 'package:sori/content_atomizer/content_atomizer.dart';
import 'package:sori/content_atomizer/models/post_draft.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/features/publish_rail/publish_rail_service.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/visit_kernel/models/visit_session.dart';

void main() {
  test('publishAll publishes whisper and tip without photo consent', () async {
    final store = SoriStore();
    await store.bootstrap(repository: MemorySoriRepository());
    store.session = const SessionUser(
      role: UserRole.director,
      name: '김원장',
      phone: '010-1234-5678',
      provider: SocialProvider.kakao,
      onboardingComplete: true,
      shopSetupComplete: true,
      activeMode: UserRole.director,
    );

    if (store.customers.isEmpty) return;

    final customer = store.customers.first;
    final chart = CustomerChart(
      id: 'atom-chart-1',
      shopId: store.shop.id,
      customerId: customer.id,
      visitNumber: 1,
      careName: '테스트',
      concernChips: const ['건조/장벽'],
      homeCarePrescriptions: const ['tag_water'],
      consentMandatory: true,
      consentPhoto: false,
      consentMarketing: false,
      signatureUrl: 'https://example.com/sig.png',
    );
    store.charts.add(chart);

    final session = VisitSession(
      id: 'visit-pub-1',
      shopId: store.shop.id,
      customerId: customer.id,
      customerName: customer.name,
      chartDraftId: chart.id,
      startedAt: DateTime.now(),
    );

    final atomized = ContentAtomizer.atomize(
      session: session,
      chart: chart,
      shopName: store.shop.name,
    );

    final beforeCount = store.communityPosts.length;
    final result = await PublishRailService.publishAll(
      store: store,
      chart: chart,
      drafts: atomized.drafts,
    );

    expect(result.published, greaterThanOrEqualTo(1));
    expect(
      atomized.drafts
          .where((d) => d.kind == PostDraftKind.clinicalBa && d.enabled),
      isEmpty,
    );
    expect(store.communityPosts.length >= beforeCount, isTrue);
  });
}
