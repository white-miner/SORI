import '../models/customer_chart.dart';
import '../models/home_care_prescriptions.dart';
import '../visit_kernel/models/visit_session.dart';
import 'atomizer_consent_gate.dart';
import 'models/post_draft.dart';

/// Chart + VisitSession → up to 4 PostDrafts (PO Phase 2).
abstract final class ContentAtomizer {
  static AtomizerResult atomize({
    required VisitSession session,
    required CustomerChart chart,
    String shopName = '',
  }) {
    final drafts = <PostDraft>[
      _whisper(chart, shopName),
      _tipCard(chart),
      _clinicalBa(chart),
      _mentoringRequest(chart),
    ];

    return AtomizerResult(
      drafts: drafts,
      sessionId: session.id,
      chartId: chart.id,
    );
  }

  static PostDraft _whisper(CustomerChart chart, String shopName) {
    final care = chart.careName.trim();
    final chips = chart.concernChips.where((c) => c.trim().isNotEmpty).take(2);
    final chipLine =
        chips.isEmpty ? '' : '\n오늘 체크: ${chips.join(' · ')}';

    final body = [
      if (shopName.trim().isNotEmpty) '$shopName에서',
      '오늘 방문해 주신 고객님과 따뜻한 케어 시간을 보냈어요.',
      if (care.isNotEmpty) '오늘의 케어: $care',
      '소통의 밀도가 곧 브랜드가 된다고 믿어요 ✨',
    ].join('\n') +
        chipLine;

    return PostDraft(
      kind: PostDraftKind.whisper,
      title: 'Whisper',
      body: body.trim(),
      enabled: true,
      selected: true,
      sourceChartId: chart.id,
      styleTags: const ['감성', '비식별'],
    );
  }

  static PostDraft _tipCard(CustomerChart chart) {
    final tags =
        HomecareDictionary.sanitizeTagIds(chart.homeCarePrescriptions);
    final tips = <String>[];
    for (final id in tags.take(3)) {
      final directive = HomecareDictionary.directiveOf(id);
      final label = HomecareDictionary.chipLabelOf(id);
      if (directive != null && directive.isNotEmpty) {
        tips.add('• ${label ?? id}: $directive');
      } else if (label != null) {
        tips.add('• $label');
      }
    }

    if (tips.isEmpty) {
      tips.add('• 미지근한 물로 가볍게 클렌징하고 보습을 충분히 채워 주세요.');
      tips.add('• 자외선 차단은 실내에서도 잊지 마세요.');
    }

    return PostDraft(
      kind: PostDraftKind.tipCard,
      title: '홈케어 Tip',
      body: '오늘의 홈케어 처방 💧\n\n${tips.join('\n')}',
      enabled: true,
      selected: true,
      sourceChartId: chart.id,
      styleTags: const ['홈케어', '팁'],
    );
  }

  static PostDraft _clinicalBa(CustomerChart chart) {
    final allowed = allowsPhotoMarketingContent(chart);
    final care =
        chart.careName.trim().isEmpty ? '케어 케이스' : chart.careName.trim();
    final summary = chart.treatmentSummary.trim();
    final insight = chart.directorInsight.trim();

    final urls = <String>[];
    final before = (chart.beforeImageUrl ?? '').trim();
    final after = (chart.afterImageUrl ?? '').trim();
    if (before.startsWith('http') || before.startsWith('data:')) urls.add(before);
    if (after.startsWith('http') || after.startsWith('data:')) urls.add(after);

    return PostDraft(
      kind: PostDraftKind.clinicalBa,
      title: '$care · Clinical B/A',
      body: [
        if (summary.isNotEmpty) summary,
        if (insight.isNotEmpty) insight,
        if (summary.isEmpty && insight.isEmpty)
          '$care 임상 기록 (고객 정보 비식별)',
      ].join('\n\n'),
      enabled: allowed && urls.isNotEmpty,
      selected: allowed && urls.isNotEmpty,
      dropReason: allowed ? (urls.isEmpty ? 'B/A 사진 없음' : null) : photoContentDropReason(chart),
      sourceChartId: chart.id,
      imageUrls: urls,
      styleTags: const ['케이스공유', 'B/A'],
    );
  }

  static PostDraft _mentoringRequest(CustomerChart chart) {
    final allowed = allowsPhotoMarketingContent(chart);
    final chips = chart.concernChips.where((c) => c.trim().isNotEmpty).toList();
    final chipText =
        chips.isEmpty ? '피부 컨디션 케어' : chips.join(' · ');

    final urls = <String>[];
    final before = (chart.beforeImageUrl ?? '').trim();
    if (before.startsWith('http') || before.startsWith('data:')) {
      urls.add(before);
    }

    return PostDraft(
      kind: PostDraftKind.mentoringRequest,
      title: '이 케이스, 다음엔?',
      body: '오늘 케어 포인트: $chipText\n\n'
          '비슷한 고민을 겪었던 원장님들, 다음 관리 방향 조언 부탁드려요 🙏',
      enabled: allowed,
      selected: allowed,
      dropReason: allowed ? null : photoContentDropReason(chart),
      sourceChartId: chart.id,
      imageUrls: urls,
      styleTags: const ['멘토링', '조언구함'],
    );
  }
}
