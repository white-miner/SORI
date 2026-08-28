import 'package:flutter_test/flutter_test.dart';

import 'package:sori/models/my_boost_gift.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/models/shop.dart';
import 'package:sori/services/sori_store.dart';

void main() {
  test('shellNotificationBadgeCount includes supporter pending thanks', () {
    final store = SoriStore.instance;
    store.session = const SessionUser(
      role: UserRole.director,
      name: 'Director',
      phone: '010',
      provider: SocialProvider.email,
      activeMode: UserRole.director,
      onboardingComplete: true,
    );
    store.shop = const Shop(
      id: 'shop-1',
      name: 'Test Shop',
      naverPlaceUrl: '',
    );
    store.supporterNotifications = const [
      SupporterNotificationItem(
        id: 'n1',
        fanGiftId: 'g1',
        hasThankYou: false,
      ),
      SupporterNotificationItem(
        id: 'n2',
        fanGiftId: 'g2',
        hasThankYou: true,
      ),
    ];

    expect(store.supporterPendingThankCount, 1);
    expect(store.shellNotificationBadgeCount(), 1);
  });
}
