// S3-0 특성 테스트: 앱 시작(bootstrap) 시 스냅샷 적용과 차트 병합 호출.
//
// 지금 동작을 그대로 고정한다. 보안 S3 PR 3-8(D5)에서 "비소유자는 고객 데이터를
// 받지 않고 병합도 하지 않는다"로 바뀌면, 비소유자 쪽 기대값만 그 PR에서 고친다.
// 소유자 쪽 기대값(스냅샷 그대로 적용, 원격일 때 병합 1회)은 계속 지켜야 한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/data/sori_repository.dart';
import 'package:sori/models/customer_chart.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/utils/chart_row_collapse.dart';

class _CollapseCall {
  _CollapseCall(this.merged, this.dropIds, this.repoint);
  final List<CustomerChart> merged;
  final List<String> dropIds;
  final Map<String, String> repoint;
}

/// 메모리 저장소를 "원격"처럼 보이게 하고 loadInitialData / collapseChartRows 를 기록한다.
class _SpyRepository extends MemorySoriRepository {
  _SpyRepository({required this.remote, required this.snapshot});

  final bool remote;
  final SoriSnapshot snapshot;
  int loadCalls = 0;
  final List<_CollapseCall> collapseCalls = [];

  @override
  bool get isRemote => remote;

  @override
  Future<SoriSnapshot> loadInitialData() async {
    loadCalls++;
    return snapshot;
  }

  @override
  Future<void> collapseChartRows({
    required List<CustomerChart> merged,
    required List<String> dropIds,
    required Map<String, String> repoint,
  }) async {
    collapseCalls.add(_CollapseCall(merged, dropIds, repoint));
  }
}

CustomerChart _consentShell(String id, DateTime createdAt, int visitNumber) {
  return CustomerChart(
    id: id,
    shopId: 'shop-demo',
    customerId: '1',
    visitNumber: visitNumber,
    careName: '동의',
    treatmentSummary: ChartRowCollapse.consentSummary,
    signatureUrl: 'sig-$id',
    consentMandatory: true,
    createdAt: createdAt,
  );
}

/// 시드 + 1년 안 동의서 껍질 2건 (최신 1건만 남아야 하는 병합 대상).
SoriSnapshot _snapshotWithDuplicateShells() {
  final seed = MemorySoriRepository.createSeedSnapshot();
  final now = DateTime.now();
  return SoriSnapshot(
    shop: seed.shop,
    customers: seed.customers,
    charts: [
      ...seed.charts,
      _consentShell('s3-shell-new', now.subtract(const Duration(days: 1)), 91),
      _consentShell('s3-shell-old', now.subtract(const Duration(days: 2)), 92),
    ],
    reviews: seed.reviews,
    aiReplies: seed.aiReplies,
    gallerySlides: seed.gallerySlides,
    diaryNotes: seed.diaryNotes,
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('S3-0 bootstrap 특성', () {
    test('메모리 저장소: 시드 스냅샷을 그대로 적용하고 병합은 호출하지 않는다', () async {
      final seed = MemorySoriRepository.createSeedSnapshot();
      final repo = _SpyRepository(remote: false, snapshot: seed);
      final store = SoriStore(repository: repo);

      await store.bootstrap();
      await _settle();

      expect(repo.loadCalls, 1);
      expect(store.bootstrapComplete, isTrue);
      expect(store.bootstrapFailed, isFalse);
      expect(store.shop.id, seed.shop.id);
      expect(store.customers.length, seed.customers.length);
      expect(store.charts.length, seed.charts.length);
      expect(store.reviews.length, seed.reviews.length);
      expect(repo.collapseCalls, isEmpty);
    });

    test('원격 저장소: 로그인 세션이 없어도 스냅샷의 고객·차트·후기를 모두 받는다 (D5 현재 동작)', () async {
      final snapshot = _snapshotWithDuplicateShells();
      final repo = _SpyRepository(remote: true, snapshot: snapshot);
      final store = SoriStore(repository: repo);
      expect(store.session, isNull);

      await store.bootstrap();
      await _settle();

      // 지금은 세션·소유 여부와 무관하게 저장소가 준 샵을 "내 샵"으로 쓴다.
      expect(store.shop.id, snapshot.shop.id);
      expect(
        store.customers.map((c) => c.id).toSet(),
        snapshot.customers.map((c) => c.id).toSet(),
      );
      expect(store.reviews.length, snapshot.reviews.length);
      expect(store.findCustomerByPhone('01012345678')?.id, '1');
    });

    test('원격 저장소: bootstrap 뒤 중복 동의서 껍질 병합을 1회 호출하고 메모리에서도 지운다', () async {
      final snapshot = _snapshotWithDuplicateShells();
      final repo = _SpyRepository(remote: true, snapshot: snapshot);
      final store = SoriStore(repository: repo);

      await store.bootstrap();
      await _settle();

      expect(repo.collapseCalls, hasLength(1));
      final call = repo.collapseCalls.single;
      expect(call.dropIds, contains('s3-shell-old'));
      expect(call.dropIds, isNot(contains('s3-shell-new')));
      expect(store.findChartById('s3-shell-old'), isNull);
      expect(store.findChartById('s3-shell-new'), isNotNull);
      expect(store.charts.length, snapshot.charts.length - call.dropIds.length);
    });

    test(
      'loadInitialData 실패: 이미 있는 데이터는 유지하고 bootstrapFailed 로 표시한다',
      () async {
        final repo = _ThrowingRepository();
        final store = SoriStore(repository: repo);
        final before = store.customers.length;

        await store.bootstrap();
        await _settle();

        expect(store.bootstrapFailed, isTrue);
        expect(store.bootstrapComplete, isTrue);
        expect(store.customers.length, before);
      },
    );
  });
}

class _ThrowingRepository extends MemorySoriRepository {
  @override
  bool get isRemote => true;

  @override
  Future<SoriSnapshot> loadInitialData() async {
    throw StateError('network down');
  }
}
