import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// RFC 4122 UUID v4 for Supabase `uuid` columns.
String newUuidV4() => _uuid.v4();

final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Legacy client ids (`visit-123`, `sched-…`) must never hit uuid columns.
bool isUuidV4(String id) => _uuidV4Pattern.hasMatch(id.trim());

bool isLegacyVisitSessionId(String id) {
  final t = id.trim();
  return t.startsWith('visit-') && !isUuidV4(t);
}
