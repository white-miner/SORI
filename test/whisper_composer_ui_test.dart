import 'package:flutter_test/flutter_test.dart';
import 'package:sori/models/whisper.dart';

void main() {
  test('composer chips omit peer_directors and label super_fans as Supporter', () {
    expect(WhisperAtoms.composerChips, isNot(contains(WhisperAtoms.peerDirectors)));
    expect(WhisperAtoms.composerChips, contains(WhisperAtoms.superFans));
    expect(WhisperAtoms.label(WhisperAtoms.superFans), 'Supporter');
    expect(WhisperAtoms.label(WhisperAtoms.everyone), '전체');
  });
}
