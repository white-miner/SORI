import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sori/features/visit/management_case_paginator.dart';
import 'package:sori/models/ba_capture_session.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/models/shoot_inbox_item.dart';
import 'package:sori/services/shoot_inbox_local.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/services/sori_store.dart';

/// `108_ba_capture_sessions.sql` 이 아직 적용되지 않은 Supabase를 흉내 낸다.
class _MissingTableRepository extends MemorySoriRepository {
  static const _pgrst205 =
      "PostgrestException(message: Could not find the table "
      "'public.ba_capture_sessions' in the schema cache, code: PGRST205)";

  @override
  Future<List<BaCaptureSession>> loadBaCaptureSessions(
    String shopId, {
    bool draftOnly = true,
  }) async {
    throw StateError(_pgrst205);
  }

  @override
  Future<BaCaptureSession> upsertBaCaptureSession(BaCaptureSession session) async {
    throw StateError(_pgrst205);
  }

  @override
  Future<BaCaptureSession> bindBaCaptureSessionToChart({
    required String sessionId,
    required String customerId,
    required String chartId,
  }) async {
    throw StateError(_pgrst205);
  }
}

BaCaptureSession _session({
  String id = 'sess-1',
  String? before,
  String? after,
  String? chartId,
  DateTime? deferredAt,
  DateTime? createdAt,
}) {
  return BaCaptureSession(
    id: id,
    shopId: 'shop-1',
    sessionToken: 'token-$id',
    beforeImageUrl: before,
    afterImageUrl: after,
    chartId: chartId,
    deferredAt: deferredAt,
    createdAt: createdAt,
  );
}

CustomerChart _chart(String id, DateTime at) {
  return CustomerChart(
    id: id,
    shopId: 'shop-1',
    customerId: 'cus-1',
    visitNumber: 1,
    careName: '테스트 케어',
    beforeImageUrl: 'https://example.com/$id-b.webp',
    afterImageUrl: 'https://example.com/$id-a.webp',
    createdAt: at,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('신호등 진리표 (is_complete generated column과 동일 수식)', () {
    test('아무것도 없음 → 🔴 empty', () {
      final s = _session();
      expect(s.isComplete, isFalse);
      expect(s.reason, BaDraftReason.empty);
      expect(s.showsInCarousel, isTrue);
    });

    test('Before만 → 🔴 missingAfter', () {
      final s = _session(before: 'https://x/b.webp');
      expect(s.isComplete, isFalse);
      expect(s.reason, BaDraftReason.missingAfter);
    });

    test('After만 → 🔴 missingBefore', () {
      final s = _session(after: 'https://x/a.webp');
      expect(s.isComplete, isFalse);
      expect(s.reason, BaDraftReason.missingBefore);
    });

    test('두 장 있으나 차트 미연동 → 🔴 unlinked', () {
      final s = _session(before: 'https://x/b.webp', after: 'https://x/a.webp');
      expect(s.isComplete, isFalse);
      expect(s.reason, BaDraftReason.unlinked);
      expect(s.showsInCarousel, isTrue);
    });

    test('두 장 + 차트 매핑 → 🟢 complete, 캐러셀에는 그대로 남는다', () {
      final s = _session(
        before: 'https://x/b.webp',
        after: 'https://x/a.webp',
        chartId: 'chart-1',
      );
      expect(s.isComplete, isTrue);
      expect(s.reason, BaDraftReason.complete);
      // v7.0.2 정책 — 완성분도 참고용으로 캐러셀에 남긴다.
      expect(s.showsInCarousel, isTrue);
    });

    test('archived 세션만 캐러셀에서 빠진다', () {
      final s = _session().copyWith(status: BaCaptureStatus.archived);
      expect(s.showsInCarousel, isFalse);
    });

    test('빈 문자열 URL은 사진 없음으로 취급', () {
      final s = _session(before: '   ', after: '');
      expect(s.hasBefore, isFalse);
      expect(s.hasAfter, isFalse);
      expect(s.reason, BaDraftReason.empty);
    });
  });

  test('"완료"로 밀어둔 세션은 뒤로 밀리되 사라지지 않는다', () {
    final now = DateTime(2026, 9, 2, 10);
    final fresh = _session(id: 'a', createdAt: now);
    final deferred = _session(
      id: 'b',
      createdAt: now.add(const Duration(hours: 1)),
      deferredAt: now,
    );

    final list = [deferred, fresh]..sort(BaCaptureSession.carouselOrder);

    // 더 최신인데도 밀어둔 세션이 뒤로 간다.
    expect(list.first.id, 'a');
    expect(list.last.id, 'b');
    // 그래도 캐러셀에는 남아 경고를 유지한다.
    expect(deferred.showsInCarousel, isTrue);
  });

  test('캐러셀 정렬 — 🔴 미완성이 먼저, 🟢 완성이 뒤', () {
    final now = DateTime(2026, 9, 2, 10);
    // 완성분이 가장 최신이어도 미완성 뒤로 밀려야 한다.
    final done = _session(
      id: 'done',
      before: 'https://x/b.webp',
      after: 'https://x/a.webp',
      chartId: 'chart-1',
      createdAt: now.add(const Duration(hours: 2)),
    );
    final todo = _session(id: 'todo', createdAt: now);
    final deferred = _session(
      id: 'later',
      createdAt: now.add(const Duration(hours: 1)),
      deferredAt: now,
    );

    final list = [done, deferred, todo]..sort(BaCaptureSession.carouselOrder);

    expect(list.map((s) => s.id), ['todo', 'later', 'done']);
  });

  test('BaCaptureSession JSON 왕복', () {
    final s = _session(
      before: 'https://x/b.webp',
      after: 'https://x/a.webp',
      chartId: 'chart-1',
      createdAt: DateTime(2026, 9, 2, 9, 30),
    );
    final again = BaCaptureSession.fromMap(s.toMap());
    expect(again.sessionToken, s.sessionToken);
    expect(again.beforeImageUrl, s.beforeImageUrl);
    expect(again.chartId, 'chart-1');
    expect(again.isComplete, isTrue);
  });

  group('관리 케이스 keyset 페이지네이션', () {
    List<CustomerChart> source(int n) {
      final base = DateTime(2026, 9, 2, 12);
      return [
        for (var i = 0; i < n; i++)
          _chart('c$i', base.subtract(Duration(minutes: i))),
      ];
    }

    test('페이지를 이어 받아도 중복·누락이 없다', () {
      final pager = ManagementCasePaginator(pageSize: 10);
      final all = source(25);

      expect(pager.loadMore(all), 10);
      expect(pager.loadMore(all), 10);
      expect(pager.loadMore(all), 5);
      expect(pager.hasMore, isFalse);
      expect(pager.loadMore(all), 0);

      final ids = pager.items.map((c) => c.id).toList();
      expect(ids.length, 25);
      expect(ids.toSet().length, 25, reason: '중복 없음');
      expect(ids, all.map((c) => c.id).toList(), reason: '누락 없음 + 순서 보존');
    });

    test('스크롤 중 새 케이스가 상단에 추가돼도 커서가 밀리지 않는다', () {
      final pager = ManagementCasePaginator(pageSize: 5);
      final all = source(12);
      pager.loadMore(all);

      // 이관으로 최신 케이스가 하나 생긴 상황.
      final incoming = _chart('new', DateTime(2026, 9, 2, 13));
      pager.prepend(incoming);
      final grown = [incoming, ...all];

      pager.loadMore(grown);
      pager.loadMore(grown);

      final ids = pager.items.map((c) => c.id).toList();
      expect(ids.first, 'new');
      expect(ids.toSet().length, ids.length, reason: '중복 없음');
      expect(ids.length, 13);
    });

    test('reset은 커서를 처음으로 되감는다', () {
      final pager = ManagementCasePaginator(pageSize: 5);
      final all = source(8);
      pager.loadMore(all);
      pager.loadMore(all);
      expect(pager.length, 8);

      pager.reset();
      expect(pager.isEmpty, isTrue);
      expect(pager.hasMore, isTrue);
      expect(pager.loadMore(all), 5);
    });
  });

  group('로컬 큐 무손실 승격', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('before/after가 sessionToken 기준으로 한 장의 카드로 병합된다', () async {
      final store = SoriStore();
      final shopId = store.shop.id;

      await ShootInboxLocal.save(shopId, [
        ShootInboxItem(
          id: 'legacy-b',
          shopId: shopId,
          kind: 'before',
          imageUrl: 'https://example.com/legacy-b.webp',
          sessionToken: 'legacy-token',
          label: '베드1',
          createdAt: DateTime(2026, 9, 1, 10),
        ),
        ShootInboxItem(
          id: 'legacy-a',
          shopId: shopId,
          kind: 'after',
          imageUrl: 'https://example.com/legacy-a.webp',
          sessionToken: 'legacy-token',
          createdAt: DateTime(2026, 9, 1, 11),
        ),
      ]);

      await store.promoteLocalShootInbox();
      await store.refreshBaSessions();

      final promoted = store.baSessions
          .where((s) => s.sessionToken == 'legacy-token')
          .toList();
      expect(promoted.length, 1);
      expect(promoted.single.beforeImageUrl, contains('legacy-b'));
      expect(promoted.single.afterImageUrl, contains('legacy-a'));
      expect(promoted.single.label, '베드1');

      // 승격에 성공한 항목은 로컬에서 제거된다.
      final remaining = await ShootInboxLocal.load(shopId);
      expect(remaining, isEmpty);
    });

    test('재실행해도 중복 row가 생기지 않는다 (멱등성)', () async {
      final storeA = SoriStore();
      final shopId = storeA.shop.id;

      final items = [
        ShootInboxItem(
          id: 'dup-b',
          shopId: shopId,
          kind: 'before',
          imageUrl: 'https://example.com/dup-b.webp',
          sessionToken: 'dup-token',
          createdAt: DateTime(2026, 9, 1, 10),
        ),
      ];

      await ShootInboxLocal.save(shopId, items);
      await storeA.promoteLocalShootInbox();

      // 로컬 정리가 실패해 같은 항목이 다시 남은 상황을 재현한다.
      await ShootInboxLocal.save(shopId, items);
      final storeB = SoriStore();
      await storeB.promoteLocalShootInbox();
      await storeB.refreshBaSessions();

      final rows = storeB.baSessions
          .where((s) => s.sessionToken == 'dup-token')
          .toList();
      expect(rows.length, 1, reason: 'unique(shop_id, session_token) 멱등');
    });

    test('사진 URL이 비어 있는 레거시 항목은 건너뛴다', () async {
      final store = SoriStore();
      final shopId = store.shop.id;

      await ShootInboxLocal.save(shopId, [
        ShootInboxItem(
          id: 'blank',
          shopId: shopId,
          kind: 'before',
          imageUrl: '',
          sessionToken: 'blank-token',
        ),
      ]);

      await store.promoteLocalShootInbox();
      await store.refreshBaSessions();

      expect(
        store.baSessions.where((s) => s.sessionToken == 'blank-token'),
        isEmpty,
      );
    });
  });

  group('🟢 이관 — 캐러셀 이탈 + 관리 케이스 진입', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('차트 연결 시 캐러셀에서 빠지고 완성 케이스로 나타난다', () async {
      final store = SoriStore();
      if (store.customers.isEmpty) return;
      final customer = store.customers.first;

      var session = await store.createBaSession(label: '이관 테스트');
      session = await store.attachBaPhoto(
        target: session,
        kind: 'before',
        imageUrl: 'https://example.com/bind-b.webp',
      );
      session = await store.attachBaPhoto(
        target: session,
        kind: 'after',
        imageUrl: 'https://example.com/bind-a.webp',
      );

      // 두 장 다 찍었어도 차트 미연동이면 🔴로 캐러셀에 남는다.
      expect(session.reason, BaDraftReason.unlinked);
      expect(
        store.baCarouselSessions.any((s) => s.id == session.id),
        isTrue,
      );

      final chart = await store.bindBaSessionToChart(
        target: session,
        customerId: customer.id,
      );

      final stillThere = store.baCarouselSessions
          .where((s) => s.sessionToken == session.sessionToken)
          .toList();
      expect(
        stillThere,
        hasLength(1),
        reason: '🟢 판정 후에도 캐러셀에 남는다 (v7.0.2)',
      );
      expect(stillThere.single.isComplete, isTrue);
      expect(stillThere.single.chartId, chart.id);
      // 완성분은 넛지 카운트에서는 빠진다.
      expect(
        store.baIncompleteCount,
        store.baCarouselSessions.where((s) => !s.isComplete).length,
      );
      expect(chart.hasBeforeImage && chart.hasAfterImage, isTrue);
      expect(
        store.managementCaseCharts().any((c) => c.id == chart.id),
        isTrue,
        reason: '관리 케이스 피드로 이관',
      );
    });

    test('After 없는 차트는 관리 케이스 피드에 노출되지 않는다 (Q5a)', () async {
      final store = SoriStore();
      for (final chart in store.managementCaseCharts()) {
        expect(chart.hasBeforeImage, isTrue);
        expect(chart.hasAfterImage, isTrue);
      }
    });
  });

  group('마이그레이션 미적용(PGRST205) 내성', () {
    test('세션 테이블이 없으면 로컬 큐로 폴백하고 캐러셀이 살아 있다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SoriStore(repository: _MissingTableRepository());

      await ShootInboxLocal.save(store.shop.id, [
        ShootInboxItem(
          id: 'inbox-1',
          shopId: store.shop.id,
          kind: 'before',
          imageUrl: 'https://example.com/b.webp',
          sessionToken: 'tok-1',
          createdAt: DateTime(2026, 9, 2, 10),
        ),
        ShootInboxItem(
          id: 'inbox-2',
          shopId: store.shop.id,
          kind: 'after',
          imageUrl: 'https://example.com/a.webp',
          sessionToken: 'tok-1',
          createdAt: DateTime(2026, 9, 2, 11),
        ),
      ]);
      await store.refreshShootInbox();
      await store.refreshBaSessions();

      expect(store.baRemoteReady, isFalse);

      // 로컬 큐가 서버와 동일한 카드 모양으로 투영된다 (before/after 한 장).
      expect(store.baSessions, hasLength(1));
      final card = store.baSessions.single;
      expect(card.beforeImageUrl, 'https://example.com/b.webp');
      expect(card.afterImageUrl, 'https://example.com/a.webp');
      expect(card.reason, BaDraftReason.unlinked);
      expect(store.baCarouselSessions, hasLength(1));
    });

    test('폴백 구간에서도 촬영이 저장되고 사진이 유실되지 않는다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SoriStore(repository: _MissingTableRepository());
      await store.refreshBaSessions();
      expect(store.baRemoteReady, isFalse);

      final draft = await store.createBaSession();
      expect(SoriStore.isLocalBaSessionId(draft.id), isTrue);

      final withBefore = await store.attachBaPhoto(
        target: draft,
        kind: 'before',
        imageUrl: 'https://example.com/local-b.webp',
      );
      expect(withBefore.beforeImageUrl, 'https://example.com/local-b.webp');
      expect(withBefore.reason, BaDraftReason.missingAfter);

      // 재부팅해도 로컬 큐에 남아 있어야 한다.
      final persisted = await ShootInboxLocal.load(store.shop.id);
      expect(persisted, hasLength(1));
      expect(persisted.single.imageUrl, 'https://example.com/local-b.webp');
    });

    test('폴백 구간 이관은 차트에 사진을 붙이고 캐러셀에서 뺀다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SoriStore(repository: _MissingTableRepository());
      await store.refreshBaSessions();

      final draft = await store.createBaSession();
      await store.attachBaPhoto(
        target: draft,
        kind: 'before',
        imageUrl: 'https://example.com/local-b.webp',
      );
      final ready = await store.attachBaPhoto(
        target: store.baSessions.first,
        kind: 'after',
        imageUrl: 'https://example.com/local-a.webp',
      );
      expect(ready.reason, BaDraftReason.unlinked);

      final customer = store.customers.first;
      final chart = await store.bindBaSessionToChart(
        target: ready,
        customerId: customer.id,
      );

      expect(chart.beforeImageUrl, 'https://example.com/local-b.webp');
      expect(chart.afterImageUrl, 'https://example.com/local-a.webp');

      // 사진은 차트로 넘어가 큐에서 빠지지만, 🟢 카드는 캐러셀에 남는다.
      expect(await ShootInboxLocal.load(store.shop.id), isEmpty);
      expect(store.baCarouselSessions, hasLength(1));
      expect(store.baCarouselSessions.single.isComplete, isTrue);
      expect(store.baIncompleteCount, 0);
    });

    test('테이블 미적용 시 로컬 큐를 한 장도 지우지 않는다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SoriStore(repository: _MissingTableRepository());
      final queued = [
        ShootInboxItem(
          id: 'inbox-1',
          shopId: store.shop.id,
          kind: 'before',
          imageUrl: 'https://example.com/b.webp',
          sessionToken: 'tok-1',
          createdAt: DateTime(2026, 9, 2, 10),
        ),
      ];
      await ShootInboxLocal.save(store.shop.id, queued);

      await store.promoteLocalShootInbox();

      expect(store.baRemoteReady, isFalse);
      expect(await ShootInboxLocal.load(store.shop.id), hasLength(1));
    });
  });

  group('My Feed 프라이버시 격리', () {
    final sources = [
      'lib/features/visit/visit_launcher_page.dart',
      'lib/features/visit/widgets/ba_capture_carousel.dart',
      'lib/features/visit/widgets/management_case_card.dart',
      'lib/features/visit/management_case_paginator.dart',
    ];

    // 공개 피드는 Boost 경매·타 샵 데이터를 포함한다. My Feed가 이를 재사용하면
    // 원장 프라이빗 포트폴리오에 외부 데이터가 섞이는 P0 사고가 된다.
    const forbidden = [
      'interleavedCaseFeed',
      'localBoostPinnedFeed',
      'activeBoostPlacements',
      'communityHotCases',
      'favoriteShopCaseItems',
    ];

    for (final path in sources) {
      test('$path 는 공개 피드 API를 참조하지 않는다', () {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path 없음');
        final source = file.readAsStringSync();
        for (final symbol in forbidden) {
          expect(
            source.contains(symbol),
            isFalse,
            reason: '$path 가 공개 피드 API `$symbol` 를 참조합니다',
          );
        }
      });
    }
  });
}
