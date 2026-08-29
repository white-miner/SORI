import 'package:flutter_test/flutter_test.dart';
import 'package:sori/data/memory_sori_repository.dart';
import 'package:sori/models/whisper.dart';

void main() {
  test('sendWhisper creates feed post with materialized recipients', () async {
    final repo = MemorySoriRepository();
    final preview = await repo.previewWhisperAudience(
      const WhisperAudienceSpec(
        op: 'union',
        atoms: [WhisperAtoms.peerDirectors, WhisperAtoms.superFans],
      ),
    );
    expect(preview.count, greaterThanOrEqualTo(3));

    final result = await repo.sendWhisper(
      body: '동료와 찐팬에게만 속삭입니다',
      spec: const WhisperAudienceSpec(
        op: 'union',
        atoms: [WhisperAtoms.peerDirectors, WhisperAtoms.superFans],
      ),
    );
    expect(result.recipientCount, preview.count);

    final ids = MemorySoriRepository.debugWhisperRecipientIds(result.postId);
    expect(ids, containsAll(['peer-director-a', 'peer-director-b', 'fan-boost-user']));
    expect(ids, isNot(contains('normal-follower')));

    // peer directors carry bit 4; super fans bit 8
    expect(
      MemorySoriRepository.debugWhisperAtomBits(
        result.postId,
        'peer-director-a',
      ) &
          4,
      isNonZero,
    );
    expect(
      MemorySoriRepository.debugWhisperAtomBits(
        result.postId,
        'fan-boost-user',
      ) &
          8,
      isNonZero,
    );
  });

  test('intersect peer ∩ super keeps only overlap', () async {
    final repo = MemorySoriRepository();
    // No overlap between peer directors and super fans in seed → 0
    final preview = await repo.previewWhisperAudience(
      const WhisperAudienceSpec(
        op: 'intersect',
        atoms: [WhisperAtoms.peerDirectors, WhisperAtoms.superFans],
      ),
    );
    expect(preview.count, 0);

    // visited ∩ followers includes normal-follower and 민지
    final overlap = await repo.previewWhisperAudience(
      const WhisperAudienceSpec(
        op: 'intersect',
        atoms: [WhisperAtoms.visited, WhisperAtoms.followers],
      ),
    );
    expect(overlap.count, greaterThanOrEqualTo(1));
    expect(
      overlap.preview.map((e) => e.userId),
      contains('normal-follower'),
    );
  });

  test('preset save roundtrip', () async {
    final repo = MemorySoriRepository();
    final saved = await repo.saveWhisperPreset(
      name: '동료+찐팬',
      spec: const WhisperAudienceSpec(
        op: 'union',
        atoms: [WhisperAtoms.peerDirectors, WhisperAtoms.superFans],
      ),
    );
    final list = await repo.loadWhisperPresets();
    expect(list.map((e) => e.id), contains(saved.id));
    expect(list.first.atomsOrSpecContainsPeers, isTrue);
  });

  test('everyone atom exposes broad audience preview', () async {
    final repo = MemorySoriRepository();
    final preview = await repo.previewWhisperAudience(
      const WhisperAudienceSpec(
        op: 'union',
        atoms: [WhisperAtoms.everyone],
      ),
    );
    expect(preview.count, greaterThanOrEqualTo(5));
    expect(preview.preview.first.userId, isNotEmpty);
  });

  test('following atom resolves users the sender follows', () async {
    final repo = MemorySoriRepository();
    final preview = await repo.previewWhisperAudience(
      const WhisperAudienceSpec(
        op: 'union',
        atoms: [WhisperAtoms.following],
      ),
    );
    expect(preview.count, greaterThanOrEqualTo(1));
    expect(
      preview.preview.map((e) => e.userId),
      contains('peer-director-a'),
    );
  });

  test('peer_directors atom includes all director roles', () async {
    final repo = MemorySoriRepository();
    final preview = await repo.previewWhisperAudience(
      const WhisperAudienceSpec(
        op: 'union',
        atoms: [WhisperAtoms.peerDirectors],
      ),
    );
    expect(
      preview.preview.map((e) => e.userId),
      containsAll(['peer-director-a', 'peer-director-b']),
    );
  });
}

extension on WhisperAudiencePreset {
  bool get atomsOrSpecContainsPeers =>
      spec.atoms.contains(WhisperAtoms.peerDirectors);
}
