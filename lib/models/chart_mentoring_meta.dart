/// Feed-level mentoring snapshot for a B/A chart.
class ChartMentoringMeta {
  const ChartMentoringMeta({
    required this.mentoringPostId,
    required this.status,
    required this.priceEcho,
  });

  final String mentoringPostId;
  final String status;
  final int priceEcho;

  bool get isActive => status == 'active';

  bool get hasLivePost => status != 'archived';

  factory ChartMentoringMeta.fromMap(Map<String, dynamic> map) {
    return ChartMentoringMeta(
      mentoringPostId: (map['id'] ?? map['mentoring_post_id'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      priceEcho: ChartMentoringMeta.asInt(map['price_echo'] ?? map['priceEcho']),
    );
  }

  static int asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

/// Detail-page mentoring payload from `get_mentoring_for_chart`.
class ChartMentoringDetail {
  const ChartMentoringDetail({
    required this.exists,
    this.id = '',
    this.chartId = '',
    this.title = 'Premium Mentoring',
    this.previewTeaser = '',
    this.bodyLocked,
    this.priceEcho = 0,
    this.status = '',
    this.purchased = false,
    this.canPurchase = false,
    this.helpCount = 0,
    this.notHelpCount = 0,
    this.purchaseCount = 0,
  });

  final bool exists;
  final String id;
  final String chartId;
  final String title;
  final String previewTeaser;
  final String? bodyLocked;
  final int priceEcho;
  final String status;
  final bool purchased;
  final bool canPurchase;
  final int helpCount;
  final int notHelpCount;
  final int purchaseCount;

  bool get isActive => status == 'active';

  bool get isUnlocked =>
      purchased || (bodyLocked != null && bodyLocked!.trim().isNotEmpty);

  factory ChartMentoringDetail.fromRpc(Map<String, dynamic> map) {
    final exists = map['exists'] == true;
    if (!exists) return const ChartMentoringDetail(exists: false);
    return ChartMentoringDetail(
      exists: true,
      id: (map['id'] ?? '').toString(),
      chartId: (map['chart_id'] ?? '').toString(),
      title: (map['title'] ?? 'Premium Mentoring').toString(),
      previewTeaser: (map['preview_teaser'] ?? '').toString(),
      bodyLocked: map['body_locked']?.toString(),
      priceEcho: ChartMentoringMeta.asInt(map['price_echo']),
      status: (map['status'] ?? '').toString(),
      purchased: map['purchased'] == true,
      canPurchase: map['can_purchase'] == true,
      helpCount: ChartMentoringMeta.asInt(map['help_count']),
      notHelpCount: ChartMentoringMeta.asInt(map['not_help_count']),
      purchaseCount: ChartMentoringMeta.asInt(map['purchase_count']),
    );
  }
}
