import '../../content_atomizer/models/post_draft.dart';
import '../../models/community_post.dart';
import '../../models/customer_chart.dart';
import '../../models/whisper.dart';
import '../../services/sori_store.dart';

/// Publish Rail — batch publish PostDrafts (Phase 2).
class PublishRailResult {
  const PublishRailResult({
    required this.published,
    required this.skipped,
    required this.errors,
  });

  final int published;
  final int skipped;
  final List<String> errors;

  bool get ok => errors.isEmpty && published > 0;
}

abstract final class PublishRailService {
  static Future<PublishRailResult> publishAll({
    required SoriStore store,
    required CustomerChart chart,
    required List<PostDraft> drafts,
  }) async {
    var published = 0;
    var skipped = 0;
    final errors = <String>[];

    for (final draft in drafts) {
      if (!draft.enabled || !draft.selected) {
        skipped++;
        continue;
      }

      try {
        final ok = await _publishOne(store: store, chart: chart, draft: draft);
        if (ok) {
          published++;
        } else {
          skipped++;
          errors.add('${draft.kind.label}: 발행 실패');
        }
      } catch (e) {
        skipped++;
        errors.add('${draft.kind.label}: $e');
      }
    }

    if (published > 0) {
      await store.refreshUnifiedCommunityFeed(force: true);
    }

    return PublishRailResult(
      published: published,
      skipped: skipped,
      errors: errors,
    );
  }

  static Future<bool> _publishOne({
    required SoriStore store,
    required CustomerChart chart,
    required PostDraft draft,
  }) async {
    switch (draft.kind) {
      case PostDraftKind.clinicalBa:
        final post = await store.publishChartCaseToCommunity(
          chart,
          title: draft.title,
          body: draft.body,
        );
        return post != null;

      case PostDraftKind.whisper:
        await store.sendWhisper(
          body: draft.body,
          spec: WhisperAudienceSpec(
            atoms: const [WhisperAtoms.everyone],
            shopId: store.shop.id,
          ),
        );
        return true;

      case PostDraftKind.tipCard:
        final post = await store.createCommunityPost(
          postType: CommunityPostType.whisper,
          title: draft.title,
          body: draft.body,
          styleTags: draft.styleTags,
          sourceChartId: draft.sourceChartId,
        );
        return post != null;

      case PostDraftKind.mentoringRequest:
        final post = await store.createCommunityPost(
          postType: CommunityPostType.caseShare,
          title: draft.title,
          body: draft.body,
          styleTags: draft.styleTags,
          sourceChartId: draft.sourceChartId,
        );
        return post != null;
    }
  }
}
