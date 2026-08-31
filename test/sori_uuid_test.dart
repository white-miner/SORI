import 'package:flutter_test/flutter_test.dart';
import 'package:sori/utils/sori_uuid.dart';

void main() {
  test('newUuidV4 returns valid RFC4122 v4 strings', () {
    for (var i = 0; i < 20; i++) {
      final id = newUuidV4();
      expect(isUuidV4(id), isTrue, reason: id);
      expect(id.startsWith('visit-'), isFalse);
    }
  });
}
