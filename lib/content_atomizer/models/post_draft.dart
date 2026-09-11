import '../../utils/category_presentation_map.dart';

/// Content Atomizer output — Phase 2 "The Magic".
enum PostDraftKind {
  clinicalBa,
  whisper,
  tipCard,
  mentoringRequest;

  String get label => switch (this) {
        PostDraftKind.clinicalBa => '전후 케이스',
        PostDraftKind.whisper =>
          CategoryPresentationMap.labelOf('whisper', fallback: '조용한 이야기'),
        PostDraftKind.tipCard =>
          CategoryPresentationMap.labelOf('tip', fallback: '현장 팁'),
        PostDraftKind.mentoringRequest =>
          CategoryPresentationMap.labelOf('question', fallback: '질문'),
      };

  String get subtitle => switch (this) {
        PostDraftKind.clinicalBa => '임상 전후 케이스',
        PostDraftKind.whisper =>
          CategoryPresentationMap.descriptionOf('whisper'),
        PostDraftKind.tipCard =>
          CategoryPresentationMap.descriptionOf('tip'),
        PostDraftKind.mentoringRequest =>
          CategoryPresentationMap.descriptionOf('question'),
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
