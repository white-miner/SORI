import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/shoot_inbox_item.dart';
import 'package:sori/views/shoot_hub_page.dart';

ShootInboxItem item({
  required String id,
  required String kind,
  String session = 'sess-a',
  String url = 'https://example.com/a.jpg',
  DateTime? createdAt,
}) {
  return ShootInboxItem(
    id: id,
    shopId: 'shop',
    kind: kind,
    imageUrl: url,
    sessionToken: session,
    createdAt: createdAt ?? DateTime(2026, 9, 10, 14, 30),
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

    test('같은 세션에 After가 여러 장이어도 1장만 남긴다', () {
      final sessions = groupShootInboxSessions([
        item(id: '1', kind: 'before'),
        item(id: '2', kind: 'after'),
        item(id: '3', kind: 'after', url: 'https://example.com/dup.jpg'),
      ]);
      expect(sessions, hasLength(1));
      expect(sessions.first.after?.id, '2');
    });
  });

  group('촬영 시각 배지', () {
    test('월.일 시:분 형식으로 찍는다', () {
      expect(
        formatShootInboxStamp(DateTime(2026, 9, 10, 14, 30)),
        '09.10 14:30',
      );
      expect(formatShootInboxStamp(null), isEmpty);
    });
  });
}
