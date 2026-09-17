import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/community_post.dart';
import 'package:sori/models/recommend_feed_category.dart';
import 'package:sori/models/unified_feed_item.dart';
import 'package:sori/utils/category_presentation_map.dart';

void main() {
  test('CategoryPresentationMap keeps whisper key, Korean label', () {
    expect(CategoryPresentationMap.whisper.key, 'whisper');
    expect(CategoryPresentationMap.whisper.label, '조용한 이야기');
    expect(CategoryPresentationMap.labelOf('whisper', fallback: 'x'), '조용한 이야기');
  });

  test('shared getters expose Korean Whisper without renaming enums', () {
    expect(CommunityPostType.whisper.name, 'whisper');
    expect(CommunityPostType.whisper.dbValue, 'whisper');
    expect(CommunityPostType.whisper.label, '조용한 이야기');
    expect(RecommendFeedCategory.whisper.id, 'whisper');
    expect(RecommendFeedCategory.whisper.label, '조용한 이야기');
    expect(CommunityFeedFilter.whisper.label, '조용한 이야기');
  });

  test('compose chrome helpers are Korean verbs', () {
    expect(CategoryPresentationMap.composeTitle, '글 쓰기');
    expect(CategoryPresentationMap.composePublishCta, '게시하기');
    expect(CategoryPresentationMap.composeDraftCta, '임시 저장');
    expect(CategoryPresentationMap.analytics, '경영');
    expect(CategoryPresentationMap.dashboard, '사장 책상');
    expect(CategoryPresentationMap.boostPromo, '홍보');
    expect(CategoryPresentationMap.viewPost, '게시물 보기');
  });
}
