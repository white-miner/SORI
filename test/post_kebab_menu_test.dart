import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/community_post.dart';
import 'package:sori/models/session_user.dart';
import 'package:sori/services/sori_store.dart';
import 'package:sori/widgets/glass/sori_glass_overlay.dart';
import 'package:sori/widgets/post/post_header.dart';
import 'package:sori/widgets/post/post_view_data.dart';

void main() {
  late SoriStore store;

  setUp(() async {
    store = SoriStore.instance;
    await store.bootstrap(repository: MemorySoriRepository());
    store.session = const SessionUser(
      role: UserRole.director,
      name: '김원장',
      phone: '010-1234-5678',
      provider: SocialProvider.kakao,
      authUserId: 'author-1',
      onboardingComplete: true,
      shopSetupComplete: true,
      activeMode: UserRole.director,
    );
  });

  PostViewData whisperData({required String authorUserId, String? shopId}) {
    final post = CommunityPost(
      id: 'post-kebab-1',
      shopId: shopId ?? store.shop.id,
      postType: CommunityPostType.whisper,
      body: '테스트 본문',
      authorUserId: authorUserId,
      isWhisper: true,
    );
    return PostViewData(
      id: post.id,
      kind: PostViewKind.whisper,
      sortAt: DateTime(2026, 1, 1),
      authorName: '작성자',
      affiliation: 'SORI',
      categoryLabel: 'Whisper',
      bodyText: post.body,
      timeLabel: '1분 전',
      post: post,
    );
  }

  Future<void> openKebabMenu(
    WidgetTester tester, {
    required PostViewData data,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PostHeader(data: data, store: store),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
  }

  testWidgets('author kebab shows edit, delete, and share actions', (tester) async {
    await openKebabMenu(tester, data: whisperData(authorUserId: 'author-1'));

    expect(find.text('수정하기'), findsOneWidget);
    expect(find.text('삭제하기'), findsOneWidget);
    expect(find.text('링크 복사 / 공유하기'), findsOneWidget);
    expect(find.text('게시물 숨기기'), findsNothing);
    expect(find.text('신고하기'), findsNothing);
    expect(find.byType(SoriGlassOverlay), findsWidgets);
  });

  testWidgets('viewer kebab shows hide, block, report, and share actions', (tester) async {
    await openKebabMenu(
      tester,
      data: whisperData(authorUserId: 'other-user', shopId: 'shop-other'),
    );

    expect(find.text('게시물 숨기기'), findsOneWidget);
    expect(find.text('이 유저 차단하기'), findsOneWidget);
    expect(find.text('신고하기'), findsOneWidget);
    expect(find.text('링크 복사 / 공유하기'), findsOneWidget);
    expect(find.text('수정하기'), findsNothing);
    expect(find.text('삭제하기'), findsNothing);
    expect(find.byType(SoriGlassOverlay), findsWidgets);
  });

  testWidgets('delete asks for confirmation before removing post', (tester) async {
    store.communityPosts.add(
      CommunityPost(
        id: 'post-kebab-1',
        shopId: store.shop.id,
        postType: CommunityPostType.whisper,
        body: '테스트 본문',
        authorUserId: 'author-1',
        isWhisper: true,
      ),
    );

    await openKebabMenu(tester, data: whisperData(authorUserId: 'author-1'));
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();

    expect(
      find.text('이 게시물을 영구적으로 삭제하시겠습니까?'),
      findsOneWidget,
    );

    await tester.tap(find.text('승인'));
    await tester.pumpAndSettle();

    expect(store.communityPosts.any((p) => p.id == 'post-kebab-1'), isFalse);
  });
}
