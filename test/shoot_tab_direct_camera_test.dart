import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/shoot_inbox_item.dart';
import 'package:sori/views/shoot_hub_page.dart';

ShootInboxItem item({
  required String id,
  required String kind,
  String session = 'sess-a',
  String url = 'https://example.com/a.jpg',
}) {
  return ShootInboxItem(
    id: id,
    shopId: 'shop',
    kind: kind,
    imageUrl: url,
    sessionToken: session,
    createdAt: DateTime(2026, 9, 1),
  );
}

void main() {
  group('미연결 세션 페어링', () {
    test('같은 토큰의 Before·After를 한 칸으로 묶는다', () {
      final sessions = groupShootInboxSessions([
        item(id: '1', kind: 'before'),
        item(id: '2', kind: 'after'),
      ]);
      expect(sessions, hasLength(1));
      expect(sessions.first.before?.id, '1');
      expect(sessions.first.after?.id, '2');
    });

    test('Before만 있으면 After 슬롯은 비어 있다', () {
      final sessions = groupShootInboxSessions([
        item(id: '1', kind: 'before'),
        item(id: '2', kind: 'before', session: 'sess-b'),
      ]);
      expect(sessions, hasLength(2));
      expect(sessions.every((s) => s.hasBefore && !s.hasAfter), isTrue);
    });

    test('토큰이 없으면 항목마다 단독 세션이다', () {
      final sessions = groupShootInboxSessions([
        const ShootInboxItem(
          id: 'solo',
          shopId: 'shop',
          kind: 'before',
          imageUrl: 'https://example.com/b.jpg',
        ),
      ]);
      expect(sessions, hasLength(1));
      expect(sessions.first.token, 'legacy-solo');
    });
  });
}
