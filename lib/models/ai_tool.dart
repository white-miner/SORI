/// AI Tool Split & Micro — models for quota, jobs, and drafts.

int _aiToolAsInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

class AiToolQuota {
  const AiToolQuota({
    this.periodKey = '',
    this.freeUsed = 0,
    this.freeLimit = 5,
  });

  final String periodKey;
  final int freeUsed;
  final int freeLimit;

  int get freeRemaining => (freeLimit - freeUsed).clamp(0, freeLimit);
  bool get hasFree => freeRemaining > 0;

  String get chipLabel => '무료 $freeRemaining/$freeLimit회';

  factory AiToolQuota.fromMap(Map<String, dynamic> map) {
    final used = _aiToolAsInt(map['free_used'] ?? map['freeUsed']);
    final limit = _aiToolAsInt(map['free_limit'] ?? map['freeLimit'], 5);
    return AiToolQuota(
      periodKey: '${map['period_key'] ?? map['periodKey'] ?? ''}',
      freeUsed: used,
      freeLimit: limit > 0 ? limit : 5,
    );
  }

  factory AiToolQuota.empty() => const AiToolQuota();
}

enum AiToolMode {
  marketing,
  clinical,
  dual,
  regenerate;

  String get sku => switch (this) {
        AiToolMode.marketing => 'ai_copy_marketing',
        AiToolMode.clinical => 'ai_copy_clinical',
        AiToolMode.dual => 'ai_copy_dual',
        AiToolMode.regenerate => 'ai_regenerate',
      };

  int get priceEcho => switch (this) {
        AiToolMode.marketing => 2,
        AiToolMode.clinical => 3,
        AiToolMode.dual => 4,
        AiToolMode.regenerate => 1,
      };

  int get priceWon => priceEcho * 100;

  String get label => switch (this) {
        AiToolMode.marketing => '마케팅 카피',
        AiToolMode.clinical => '임상 요약',
        AiToolMode.dual => '듀얼 생성',
        AiToolMode.regenerate => '재생성',
      };

  String get priceLabel => '${priceEcho}E (${priceWon}원)';

  static AiToolMode? fromSku(String sku) {
    final s = sku.trim().toLowerCase();
    for (final m in AiToolMode.values) {
      if (m.sku == s) return m;
    }
    return null;
  }
}

class AiToolPurchaseResult {
  const AiToolPurchaseResult({
    this.ok = false,
    this.jobId = '',
    this.sku = '',
    this.mode = '',
    this.chargedEcho = 0,
    this.chargedVia = '',
    this.quota = const AiToolQuota(),
    this.message = '',
    this.insufficient = false,
    this.have = 0,
    this.need = 0,
  });

  final bool ok;
  final String jobId;
  final String sku;
  final String mode;
  final int chargedEcho;
  final String chargedVia;
  final AiToolQuota quota;
  final String message;
  final bool insufficient;
  final int have;
  final int need;

  bool get usedFreeQuota => chargedVia == 'free_quota';

  factory AiToolPurchaseResult.fromMap(Map<String, dynamic> map) {
    final quotaRaw = map['quota'];
    return AiToolPurchaseResult(
      ok: map['ok'] == true,
      jobId: '${map['job_id'] ?? map['jobId'] ?? ''}',
      sku: '${map['sku'] ?? ''}',
      mode: '${map['mode'] ?? ''}',
      chargedEcho: _aiToolAsInt(map['charged_echo'] ?? map['chargedEcho']),
      chargedVia: '${map['charged_via'] ?? map['chargedVia'] ?? ''}',
      quota: quotaRaw is Map
          ? AiToolQuota.fromMap(Map<String, dynamic>.from(quotaRaw))
          : const AiToolQuota(),
      message: '${map['message'] ?? ''}',
    );
  }

  factory AiToolPurchaseResult.insufficientPoints({
    required int have,
    required int need,
  }) {
    return AiToolPurchaseResult(
      ok: false,
      insufficient: true,
      have: have,
      need: need,
      message: 'Echo 부족',
    );
  }
}

class AiToolDraft {
  const AiToolDraft({
    this.title = '',
    this.marketingBody = '',
    this.clinicalReport = '',
    this.hashtags = const [],
    this.source = 'unknown',
    this.mode = AiToolMode.marketing,
  });

  final String title;
  final String marketingBody;
  final String clinicalReport;
  final List<String> hashtags;
  final String source;
  final AiToolMode mode;

  String get clipboardPayload {
    final tags = hashtags
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .map((h) => h.startsWith('#') ? h : '#$h')
        .join(' ');
    final story = marketingBody.trim();
    if (tags.isEmpty) return story;
    if (story.isEmpty) return tags;
    return '$story\n\n$tags';
  }

  factory AiToolDraft.fromJson(
    Map<String, dynamic> map, {
    AiToolMode mode = AiToolMode.marketing,
  }) {
    final rawTags = map['hashtags'];
    List<String> tags = const [];
    if (rawTags is List) {
      tags = rawTags.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    }
    return AiToolDraft(
      title: (map['title'] as String?)?.trim() ?? '',
      marketingBody: (map['body'] as String?)?.trim() ??
          (map['marketing_body'] as String?)?.trim() ??
          '',
      clinicalReport: (map['clinical_report'] as String?)?.trim() ?? '',
      hashtags: tags,
      source: (map['source'] as String?)?.trim() ?? 'unknown',
      mode: mode,
    );
  }
}

class ShopPromoCredit {
  const ShopPromoCredit({
    required this.creditSku,
    required this.balance,
    this.source = '',
    this.note = '',
  });

  final String creditSku;
  final int balance;
  final String source;
  final String note;

  factory ShopPromoCredit.fromMap(Map<String, dynamic> map) {
    return ShopPromoCredit(
      creditSku: '${map['credit_sku'] ?? map['creditSku'] ?? ''}',
      balance: _aiToolAsInt(map['balance']),
      source: '${map['source'] ?? ''}',
      note: '${map['note'] ?? ''}',
    );
  }
}
