import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/community_post.dart';
import 'package:sori/models/whisper.dart';
import 'package:sori/utils/whisper_feed.dart';

void main() {
  test('whisper zones split incoming vs authored', () async {
    const viewer = 'memory-sender';
    final repo = MemorySoriRepository();

    await repo.sendWhisper(
      body: '동료에게만',
      spec: const WhisperAudienceSpec(
        shopId: 'shop-demo',
        op: 'union',
        atoms: [WhisperAtoms.peerDirectors],
      ),
    );

    final posts = await repo.loadCommunityPosts();
    final whispers = posts.where((p) => p.isWhisper);
    final authored = whisperAuthoredPosts(whispers, viewerId: viewer);
    final incoming = whisperIncomingPosts(whispers, viewerId: viewer);

    expect(authored, isNotEmpty);
    expect(authored.every((p) => p.authorUserId == viewer), isTrue);
    expect(incoming.every((p) => p.authorUserId != viewer), isTrue);
    expect(incoming.every((p) => !p.isBodyLocked), isTrue);
  });

  test('locked whispers never appear in incoming zone', () {
    const viewer = 'user-a';
    final posts = [
      CommunityPost(
        id: 'w1',
        shopId: 's1',
        authorUserId: 'user-b',
        postType: CommunityPostType.caseShare,
        body: 'hidden',
        isWhisper: true,
        isBodyLocked: true,
      ),
      CommunityPost(
        id: 'w2',
        shopId: 's1',
        authorUserId: 'user-b',
        postType: CommunityPostType.caseShare,
        body: 'visible',
        isWhisper: true,
      ),
    ];

    final incoming = whisperIncomingPosts(posts, viewerId: viewer);
    expect(incoming.map((p) => p.id), ['w2']);
  });
}
