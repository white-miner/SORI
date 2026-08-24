import '../utils/db_map.dart';

/// Composable audience atom ids (064).
abstract final class WhisperAtoms {
  static const visited = 'visited';
  static const followers = 'followers';
  static const peerDirectors = 'peer_directors';
  static const superFans = 'super_fans';
  static const explicit = 'explicit';

  static const all = <String>[
    visited,
    followers,
    peerDirectors,
    superFans,
    explicit,
  ];

  static String label(String atom) => switch (atom) {
        visited => '방문 고객',
        followers => '내 팔로워',
        peerDirectors => '동료 원장',
        superFans => '찐팬',
        explicit => '지정',
        _ => atom,
      };
}

class WhisperAudienceSpec {
  const WhisperAudienceSpec({
    this.op = 'union',
    this.atoms = const [],
    this.explicitUserIds = const [],
    this.explicitShopIds = const [],
    this.shopId,
    this.maxRecipients = 500,
  });

  final String op;
  final List<String> atoms;
  final List<String> explicitUserIds;
  final List<String> explicitShopIds;
  final String? shopId;
  final int maxRecipients;

  WhisperAudienceSpec copyWith({
    String? op,
    List<String>? atoms,
    List<String>? explicitUserIds,
    List<String>? explicitShopIds,
    String? shopId,
    int? maxRecipients,
  }) {
    return WhisperAudienceSpec(
      op: op ?? this.op,
      atoms: atoms ?? this.atoms,
      explicitUserIds: explicitUserIds ?? this.explicitUserIds,
      explicitShopIds: explicitShopIds ?? this.explicitShopIds,
      shopId: shopId ?? this.shopId,
      maxRecipients: maxRecipients ?? this.maxRecipients,
    );
  }

  Map<String, dynamic> toRpcParams() => {
        'p_op': op,
        'p_atoms': atoms,
        'p_explicit_user_ids':
            explicitUserIds.isEmpty ? null : explicitUserIds,
        'p_explicit_shop_ids':
            explicitShopIds.isEmpty ? null : explicitShopIds,
        'p_shop_id': shopId,
        'p_max': maxRecipients,
      };
}

class WhisperPreviewPerson {
  const WhisperPreviewPerson({
    required this.userId,
    required this.nickname,
    this.avatarUrl = '',
    this.atomBits = 0,
  });

  final String userId;
  final String nickname;
  final String avatarUrl;
  final int atomBits;

  factory WhisperPreviewPerson.fromMap(Map<String, dynamic> map) {
    return WhisperPreviewPerson(
      userId: DbMap.asText(map['user_id'] ?? map['userId']),
      nickname: DbMap.asText(map['nickname'], 'SORI'),
      avatarUrl: DbMap.asText(map['avatar_url'] ?? map['avatarUrl']),
      atomBits: DbMap.asInt(map['atom_bits'] ?? map['atomBits']),
    );
  }
}

class WhisperAudiencePreview {
  const WhisperAudiencePreview({
    required this.count,
    this.preview = const [],
    this.op = 'union',
    this.atoms = const [],
  });

  final int count;
  final List<WhisperPreviewPerson> preview;
  final String op;
  final List<String> atoms;

  factory WhisperAudiencePreview.fromMap(Map<String, dynamic> map) {
    final raw = map['preview'];
    final people = <WhisperPreviewPerson>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          people.add(
            WhisperPreviewPerson.fromMap(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    final atomsRaw = map['atoms'];
    final atoms = <String>[];
    if (atomsRaw is List) {
      for (final a in atomsRaw) {
        final t = a?.toString() ?? '';
        if (t.isNotEmpty) atoms.add(t);
      }
    }
    return WhisperAudiencePreview(
      count: DbMap.asInt(map['count']),
      preview: people,
      op: DbMap.asText(map['op'], 'union'),
      atoms: atoms,
    );
  }
}

class WhisperMessage {
  const WhisperMessage({
    required this.id,
    required this.body,
    required this.createdAt,
    this.box = 'inbox',
    this.recipientCount = 0,
    this.truncated = false,
    this.readAt,
    this.senderUserId,
    this.senderNickname = '',
    this.senderAvatarUrl = '',
    this.audienceOp = 'union',
    this.audienceSpec = const {},
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String box;
  final int recipientCount;
  final bool truncated;
  final DateTime? readAt;
  final String? senderUserId;
  final String senderNickname;
  final String senderAvatarUrl;
  final String audienceOp;
  final Map<String, dynamic> audienceSpec;

  bool get isUnread => box == 'inbox' && readAt == null;

  factory WhisperMessage.fromMap(Map<String, dynamic> map) {
    final specRaw = map['audience_spec'] ?? map['audienceSpec'];
    return WhisperMessage(
      id: DbMap.asText(map['id']),
      body: DbMap.asText(map['body']),
      createdAt: DbMap.asDateTime(map['created_at'] ?? map['createdAt']) ??
          DateTime.now(),
      box: DbMap.asText(map['box'], 'inbox'),
      recipientCount: DbMap.asInt(
        map['recipient_count'] ?? map['recipientCount'],
      ),
      truncated: DbMap.asBool(map['truncated']),
      readAt: DbMap.asDateTime(map['read_at'] ?? map['readAt']),
      senderUserId: DbMap.asTextOrNull(
        map['sender_user_id'] ?? map['senderUserId'],
      ),
      senderNickname: DbMap.asText(
        map['sender_nickname'] ?? map['senderNickname'],
        '원장',
      ),
      senderAvatarUrl: DbMap.asText(
        map['sender_avatar_url'] ?? map['senderAvatarUrl'],
      ),
      audienceOp: DbMap.asText(map['audience_op'] ?? map['audienceOp'], 'union'),
      audienceSpec: specRaw is Map
          ? Map<String, dynamic>.from(specRaw)
          : const {},
    );
  }
}

class WhisperAudiencePreset {
  const WhisperAudiencePreset({
    required this.id,
    required this.name,
    required this.spec,
    this.op = 'union',
  });

  final String id;
  final String name;
  final WhisperAudienceSpec spec;
  final String op;

  factory WhisperAudiencePreset.fromMap(Map<String, dynamic> map) {
    final specRaw = map['audience_spec'] ?? map['audienceSpec'];
    final specMap = specRaw is Map
        ? Map<String, dynamic>.from(specRaw)
        : <String, dynamic>{};
    final atomsRaw = specMap['atoms'];
    final atoms = <String>[];
    if (atomsRaw is List) {
      for (final a in atomsRaw) {
        final t = a?.toString() ?? '';
        if (t.isNotEmpty) atoms.add(t);
      }
    }
    final explicitUsers = <String>[];
    final eu = specMap['explicit_user_ids'];
    if (eu is List) {
      for (final e in eu) {
        final t = e?.toString() ?? '';
        if (t.isNotEmpty) explicitUsers.add(t);
      }
    }
    return WhisperAudiencePreset(
      id: DbMap.asText(map['id']),
      name: DbMap.asText(map['name'], '그룹'),
      op: DbMap.asText(
        map['audience_op'] ?? map['audienceOp'] ?? specMap['op'],
        'union',
      ),
      spec: WhisperAudienceSpec(
        op: DbMap.asText(specMap['op'], 'union'),
        atoms: atoms,
        explicitUserIds: explicitUsers,
        shopId: DbMap.asTextOrNull(specMap['shop_id']),
      ),
    );
  }
}

class WhisperSendResult {
  const WhisperSendResult({
    required this.whisperId,
    required this.recipientCount,
    this.truncated = false,
  });

  final String whisperId;
  final int recipientCount;
  final bool truncated;

  factory WhisperSendResult.fromMap(Map<String, dynamic> map) {
    return WhisperSendResult(
      whisperId: DbMap.asText(map['whisper_id'] ?? map['whisperId']),
      recipientCount: DbMap.asInt(
        map['recipient_count'] ?? map['recipientCount'],
      ),
      truncated: DbMap.asBool(map['truncated']),
    );
  }
}
