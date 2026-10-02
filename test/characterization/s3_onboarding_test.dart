// S3-0 특성 테스트: 온보딩(원장 샵 설정, 고객 역할 선택)이 샵·고객 행을 다루는 방식.
//
// 지켜야 할 동작: 이미 샵을 가진 원장이 샵 설정을 다시 저장하면 "자기 샵"을 같은 id로 수정한다.
// 바뀔 동작(지금 상태를 고정): 새 원장도 스토어의 현재 샵(비소유자면 가장 오래된 샵) id로
// upsertShop + linkShopOwner 를 부르고(D10), 고객은 메모리의 남의 샵 고객과 전화번호로
// 연결된다(D11, Q7). 보안 S3 PR 3-9에서 이 부분의 기대값만 고친다.
import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/customer.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/services/sori_store.dart';

class _Link {
  _Link(this.targetId, this.userId);
  final String targetId;
  final String userId;
}

class _SpyRepository extends MemorySoriRepository {
  final List<Shop> upsertedShops = [];
  final List<_Link> shopOwnerLinks = [];
  final List<_Link> customerLinks = [];
  final List<Map<String, String>> registered = [];
  final List<Customer> upsertedCustomers = [];

  @override
  bool get isRemote => true;

  @override
  Future<Shop> upsertShop(Shop shop) async {
    upsertedShops.add(shop);
    return shop;
  }

  @override
  Future<void> linkShopOwner({
    required String shopId,
    required String userId,
  }) async {
    shopOwnerLinks.add(_Link(shopId, userId));
  }

  @override
  Future<void> linkCustomerUser({
    required String customerId,
    required String userId,
  }) async {
    customerLinks.add(_Link(customerId, userId));
  }

  @override
  Future<Customer> registerCustomer({
    required String shopId,
    required String name,
    required String phone,
    String memo = '',
  }) async {
    registered.add({'shopId': shopId, 'name': name, 'phone': phone});
    return Customer(
      id: 'reg-${registered.length}',
      shopId: shopId,
      name: name,
      phone: phone,
      lastTreatmentDate: DateTime(2026, 10, 3),
      treatmentType: '상담',
      membershipTotalVisits: 0,
    );
  }

  @override
  Future<Customer> upsertCustomer(Customer customer) async {
    upsertedCustomers.add(customer);
    return customer;
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('S3-0 원장 샵 설정 특성', () {
    test('보호: 샵 설정 저장은 현재 샵을 같은 id로 수정하고 원장 세션을 연다', () async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      final shopId = store.shop.id;
      store.beginSocialLogin(
        provider: SocialProvider.kakao,
        name: '김원장',
        phone: '010-9999-8888',
        authUserId: 'auth-owner-1',
      );
      store.completeRoleSelection(UserRole.director);

      store.completeShopSetup(
        shopName: ' 새이름샵 ',
        shopPhone: '02-111-2222',
        naverPlaceUrl: 'https://m.place.naver.com/place/test',
      );
      await _settle();

      expect(store.shop.id, shopId);
      expect(store.shop.name, '새이름샵');
      expect(store.shop.phone, '02-111-2222');
      expect(store.shop.ownerName, '김원장');
      expect(store.shopRegisteredByUser, isTrue);
      expect(store.session!.role, UserRole.director);
      expect(store.session!.onboardingComplete, isTrue);
      expect(store.session!.shopSetupComplete, isTrue);
      expect(store.session!.showFirstChartTutorial, isTrue);

      expect(repo.upsertedShops, isNotEmpty);
      expect(repo.upsertedShops.last.id, shopId);
      expect(repo.upsertedShops.last.name, '새이름샵');
    });

    test('현재 동작(D10): 새 원장도 현재 샵 id로 linkShopOwner 를 부른다', () async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      final existingShopId = store.shop.id;
      store.beginSocialLogin(
        provider: SocialProvider.kakao,
        name: '신규원장',
        phone: '010-7777-6666',
        authUserId: 'auth-new-director',
      );
      store.completeRoleSelection(UserRole.director);
      store.completeShopSetup(
        shopName: '신규샵',
        shopPhone: '02-333-4444',
        naverPlaceUrl: '',
      );
      await _settle();

      expect(repo.shopOwnerLinks, hasLength(1));
      expect(repo.shopOwnerLinks.single.targetId, existingShopId);
      expect(repo.shopOwnerLinks.single.userId, 'auth-new-director');
      // 새 샵 행을 만들지 않고 기존 id 로 upsert 한다.
      expect(repo.upsertedShops.map((s) => s.id).toSet(), {existingShopId});
    });

    test('authUserId 가 없으면 linkShopOwner 를 부르지 않는다', () async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      store.beginSocialLogin(
        provider: SocialProvider.kakao,
        name: '김원장',
        phone: '010-9999-8888',
      );
      store.completeRoleSelection(UserRole.director);
      store.completeShopSetup(
        shopName: '테스트샵',
        shopPhone: '02-111-2222',
        naverPlaceUrl: '',
      );
      await _settle();

      expect(repo.shopOwnerLinks, isEmpty);
    });
  });

  group('S3-0 고객 역할 특성 (D11, Q7 현재 동작)', () {
    test('고객 역할 선택: 메모리 고객과 전화번호가 맞으면 그 고객으로 연결한다', () async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      store.beginSocialLogin(
        provider: SocialProvider.kakao,
        name: '김민지',
        phone: '010-1234-5678',
        authUserId: 'auth-customer-1',
      );

      store.completeRoleSelection(UserRole.customer);
      await _settle();

      expect(store.session!.role, UserRole.customer);
      expect(store.session!.customerId, '1');
      expect(store.session!.onboardingComplete, isTrue);
      expect(repo.customerLinks, hasLength(1));
      expect(repo.customerLinks.single.targetId, '1');
      expect(repo.customerLinks.single.userId, 'auth-customer-1');
    });

    test('고객 역할 선택: 맞는 고객이 없으면 현재 샵 id로 로컬 고객을 만들고 연결한다', () async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      store.beginSocialLogin(
        provider: SocialProvider.kakao,
        name: '처음고객',
        phone: '010-0000-1111',
        authUserId: 'auth-customer-2',
      );

      store.completeRoleSelection(UserRole.customer);
      await _settle();

      final created = store.findCustomer(store.session!.customerId!);
      expect(created, isNotNull);
      expect(created!.shopId, store.shop.id);
      expect(created.phone, '010-0000-1111');
      expect(repo.customerLinks.single.targetId, created.id);
    });

    test('고객 온보딩(원격): 맞는 고객이 없으면 현재 샵 id로 registerCustomer 후 연결한다', () async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      store.beginSocialLogin(
        provider: SocialProvider.kakao,
        name: '',
        phone: '',
        authUserId: 'auth-customer-3',
      );

      await store.completeCustomerOnboarding(
        name: '새고객',
        phone: '010-2222-3333',
      );
      await _settle();

      expect(repo.registered, [
        {'shopId': store.shop.id, 'name': '새고객', 'phone': '010-2222-3333'},
      ]);
      expect(store.session!.customerId, 'reg-1');
      expect(repo.customerLinks.single.targetId, 'reg-1');
    });

    test('고객 온보딩(원격): 맞는 고객이 있으면 그 행을 upsertCustomer 한다', () async {
      final repo = _SpyRepository();
      final store = SoriStore(repository: repo);
      store.beginSocialLogin(
        provider: SocialProvider.kakao,
        name: '',
        phone: '',
        authUserId: 'auth-customer-4',
      );

      await store.completeCustomerOnboarding(
        name: '김민지',
        phone: '010-1234-5678',
      );
      await _settle();

      expect(repo.registered, isEmpty);
      expect(repo.upsertedCustomers.single.id, '1');
      expect(store.session!.customerId, '1');
      expect(repo.customerLinks.single.targetId, '1');
    });
  });
}
