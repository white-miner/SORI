import 'package:flutter_test/flutter_test.dart';
import 'package:sori/services/guide_camera_session.dart';

void main() {
  test('닫기가 먼저 오면 늦게 도착한 스트림은 버린다', () {
    final gen = GuideCameraGeneration();
    final startToken = gen.begin();
    gen.invalidate();
    expect(gen.isCurrent(startToken), isFalse);
  });

  test('닫기 없이 끝나면 그 스트림을 쓴다', () {
    final gen = GuideCameraGeneration();
    final startToken = gen.begin();
    expect(gen.isCurrent(startToken), isTrue);
  });

  test('새 시작이 끼어들면 이전 시작은 낡은 시도가 된다', () {
    final gen = GuideCameraGeneration();
    final first = gen.begin();
    final second = gen.begin();
    expect(gen.isCurrent(first), isFalse);
    expect(gen.isCurrent(second), isTrue);
    gen.invalidate();
    expect(gen.isCurrent(second), isFalse);
  });

  test('시작 직후 연속 닫기도 세대를 올린다', () {
    final gen = GuideCameraGeneration();
    final tokens = <int>[];
    for (var i = 0; i < 5; i++) {
      tokens.add(gen.begin());
      gen.invalidate();
    }
    expect(tokens.toSet().length, 5);
    for (final t in tokens) {
      expect(gen.isCurrent(t), isFalse);
    }
  });
}
