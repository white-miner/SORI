import 'package:flutter_test/flutter_test.dart';
import 'package:sori/views/shoot_hub_page.dart';

void main() {
  group('촬영 탭 진입', () {
    test('아무것도 진행 중이 아니면 허브를 건너뛰고 카메라를 연다', () {
      expect(
        shouldAutoOpenCamera(
          hasActiveSession: false,
          hasInbox: false,
          hasAfterWaiting: false,
        ),
        isTrue,
      );
    });

    test('이어 찍을 게 남아 있으면 허브를 먼저 보여 준다', () {
      expect(
        shouldAutoOpenCamera(
          hasActiveSession: true,
          hasInbox: false,
          hasAfterWaiting: false,
        ),
        isFalse,
      );
      expect(
        shouldAutoOpenCamera(
          hasActiveSession: false,
          hasInbox: true,
          hasAfterWaiting: false,
        ),
        isFalse,
      );
      expect(
        shouldAutoOpenCamera(
          hasActiveSession: false,
          hasInbox: false,
          hasAfterWaiting: true,
        ),
        isFalse,
      );
    });
  });
}
