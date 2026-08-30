/// Content Atomizer output — Phase 2 "The Magic".
enum PostDraftKind {
  clinicalBa,
  whisper,
  tipCard,
  mentoringRequest;

  String get label => switch (this) {
        PostDraftKind.clinicalBa => 'Clinical B/A',
        PostDraftKind.whisper => 'Whisper',
        PostDraftKind.tipCard => 'Tip Card',
        PostDraftKind.mentoringRequest => 'Mentoring',
      };

  String get subtitle => switch (this) {
        PostDraftKind.clinicalBa => '임상 Before/After 케이스',
        PostDraftKind.whisper => '감성 일상',
        PostDraftKind.tipCard => '홈케어 팁',
        PostDraftKind.mentoringRequest => '멘토링 요청',
      };
}

/// VisitSession Done → Publish Rail prefill SSOT.
class PostDraft {
  const PostDraft({
    required this.kind,
    required this.title,
    required this.body,
    this.enabled = true,
    this.selected = true,
    this.dropReason,
    this.sourceChartId,
    this.imageUrls = const [],
    this.styleTags = const [],
  });

  final PostDraftKind kind;
  final String title;
  final String body;
  final bool enabled;
  final bool selected;
  final String? dropReason;
  final String? sourceChartId;
  final List<String> imageUrls;
  final List<String> styleTags;

  PostDraft copyWith({
    bool? enabled,
    bool? selected,
    String? title,
    String? body,
  }) {
    return PostDraft(
      kind: kind,
      title: title ?? this.title,
      body: body ?? this.body,
      enabled: enabled ?? this.enabled,
      selected: selected ?? this.selected,
      dropReason: dropReason,
      sourceChartId: sourceChartId,
      imageUrls: imageUrls,
      styleTags: styleTags,
    );
  }
}

class AtomizerResult {
  const AtomizerResult({
    required this.drafts,
    required this.sessionId,
    required this.chartId,
  });

  final List<PostDraft> drafts;
  final String sessionId;
  final String chartId;

  List<PostDraft> get publishable =>
      drafts.where((d) => d.enabled && d.selected).toList();

  int get enabledCount => drafts.where((d) => d.enabled).length;
}
