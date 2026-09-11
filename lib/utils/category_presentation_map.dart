/// UI-only category presentation — internal keys (enum/DB/analytics) stay English.
/// R3 Expand: reuse everywhere Whisper/Compose categories are shown.
class CategoryPresentation {
  const CategoryPresentation({
    required this.key,
    required this.label,
    required this.description,
  });

  /// Stable internal key (`whisper`, `tip`, …) — never rename.
  final String key;
  final String label;
  final String description;
}

/// Single source for user-facing category language (Korean).
abstract final class CategoryPresentationMap {
  static const whisper = CategoryPresentation(
    key: 'whisper',
    label: '조용한 이야기',
    description: '가볍게 묻고 나누는 글',
  );

  static const tip = CategoryPresentation(
    key: 'tip',
    label: '현장 팁',
    description: '내가 해본 방법을 나눠요',
  );

  static const tipDevice = CategoryPresentation(
    key: 'tip_device',
    label: '현장 팁',
    description: '기기에서 겪은 방법을 나눠요',
  );

  static const tipProduct = CategoryPresentation(
    key: 'tip_product',
    label: '현장 팁',
    description: '제품에서 겪은 방법을 나눠요',
  );

  static const question = CategoryPresentation(
    key: 'question',
    label: '질문',
    description: '궁금한 점을 물어보세요',
  );

  static const seminar = CategoryPresentation(
    key: 'seminar',
    label: '세미나',
    description: '함께 배우는 모임',
  );

  static const notice = CategoryPresentation(
    key: 'notice',
    label: '알림',
    description: '꼭 확인할 내용',
  );

  static const draft = CategoryPresentation(
    key: 'draft',
    label: '임시 저장',
    description: '아직 게시하지 않은 글',
  );

  /// Compose chrome (not a post_type).
  static const composeTitle = '글 쓰기';
  static const composePublishCta = '게시하기';
  static const composeDraftCta = '임시 저장';
  static const composeMoreCategories = '더 보기';

  /// Product chrome (UI only — analytics/event keys unchanged).
  static const analytics = '경영';
  static const dashboard = '사장 책상';
  static const insights = '이번 달 흐름';
  static const insightsAlt = '이런 변화가 보여요';
  static const featured = '대표 사례';
  static const save = '저장';
  static const saved = '저장한 콘텐츠';
  static const unpublish = '커뮤니티 공개 중단';
  static const delete = '삭제';
  static const more = '더 보기';
  static const viewPost = '게시물 보기';
  static const recommendFeed = '추천 글';
  static const boostPromo = '홍보';
  static const viewCustomerMode = '고객 화면으로 보기';
  static const viewDirectorDesk = '사장 책상으로 돌아가기';

  static const Map<String, CategoryPresentation> _byKey = {
    'whisper': whisper,
    'tip': tip,
    'tip_device': tipDevice,
    'tip_product': tipProduct,
    'question': question,
    'mentor_ask': question,
    'seminar': seminar,
    'notice': notice,
    'draft': draft,
  };

  static CategoryPresentation? of(String key) {
    final k = key.trim().toLowerCase();
    if (k.isEmpty) return null;
    return _byKey[k];
  }

  /// Display label for a known key; [fallback] if unmapped.
  static String labelOf(String key, {required String fallback}) {
    return of(key)?.label ?? fallback;
  }

  static String descriptionOf(String key, {String fallback = ''}) {
    return of(key)?.description ?? fallback;
  }
}
