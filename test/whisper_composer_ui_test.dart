import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/whisper.dart';

void main() {
  test('composer chips are the 8 PO audience options with exact labels', () {
    expect(WhisperAtoms.composerChips, [
      WhisperAtoms.everyone,
      WhisperAtoms.followers,
      WhisperAtoms.following,
      WhisperAtoms.superFans,
      WhisperAtoms.visited,
      WhisperAtoms.peerDirectors,
      WhisperAtoms.customerMode,
      WhisperAtoms.explicit,
    ]);
    expect(WhisperAtoms.composerChips, isNot(contains(WhisperAtoms.seminarHosts)));
    expect(WhisperAtoms.label(WhisperAtoms.everyone), '전체 공개');
    expect(WhisperAtoms.label(WhisperAtoms.followers), '내 팔로워');
    expect(WhisperAtoms.label(WhisperAtoms.following), '내 팔로우');
    expect(WhisperAtoms.label(WhisperAtoms.superFans), '내 서포터');
    expect(WhisperAtoms.label(WhisperAtoms.visited), '차트 고객');
    expect(WhisperAtoms.label(WhisperAtoms.peerDirectors), '원장 유저');
    expect(WhisperAtoms.label(WhisperAtoms.customerMode), '일반 유저');
    expect(WhisperAtoms.label(WhisperAtoms.explicit), '계정 지정');
  });
}
