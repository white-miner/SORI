import '../utils/db_map.dart';

/// Composable audience atom ids (064 / 068 / 089).
abstract final class WhisperAtoms {
  /// 전체 공개 — 모든 소리앱 유저.
  static const everyone = 'everyone';

  /// 차트 고객 — 내가 작성한 차트 고객.
  static const visited = 'visited';

  /// 내 팔로워 — 날 팔로우 하는 유저.
  static const followers = 'followers';

  /// 내 팔로우 — 내가 팔로우 하는 유저.
  static const following = 'following';

  /// 원장 유저 — 소리앱을 사용하는 원장 유저.
  static const peerDirectors = 'peer_directors';

  /// 내 서포터 — 에코/부스터 등 서포트한 유저.
  static const superFans = 'super_fans';

  /// Legacy atom (presets / RPC); omitted from composer chips.
  static const seminarHosts = 'seminar_hosts';

  /// 일반 유저 — 소리앱을 사용하는 일반 유저.
  static const customerMode = 'customer_mode';

  /// 계정 지정 — 프로필 검색 / 최근 상호작용.
  static const explicit = 'explicit';

  /// Composer chips — PO 8 options (exact chip labels via [label]).
  static const composerChips = <String>[
    everyone,
    followers,
    following,
    superFans,
    visited,
    peerDirectors,
    customerMode,
    explicit,
  ];

  static const all = <String>[
    everyone,
    visited,
    followers,
    following,
    peerDirectors,
    superFans,
    seminarHosts,
    customerMode,
    explicit,
  ];

  static String label(String atom) => switch (atom) {
        everyone => '전체 공개',
        followers => '내 팔로워',
        following => '내 팔로우',
        superFans => '내 서포터',
        visited => '차트 고객',
        peerDirectors => '원장 유저',
        customerMode => '일반 유저',
        explicit => '계정 지정',
        seminarHosts => '세미나 강사',
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
    required this.postId,
    required this.recipientCount,
    this.truncated = false,
  });

  final String postId;
  final int recipientCount;
  final bool truncated;

  /// 하위 호환 — post_id 와 동일.
  String get whisperId => postId;

  factory WhisperSendResult.fromMap(Map<String, dynamic> map) {
    final id = DbMap.asText(
      map['post_id'] ?? map['postId'] ?? map['whisper_id'] ?? map['whisperId'],
    );
    return WhisperSendResult(
      postId: id,
      recipientCount: DbMap.asInt(
        map['recipient_count'] ?? map['recipientCount'],
      ),
      truncated: DbMap.asBool(map['truncated']),
    );
  }
}
