import 'package:flutter_test/flutter_test.dart';
import 'package:sori/features/operation/care_timer_tts_service.dart';

void main() {
  group('CareTimerTtsService.scoreKoreanSpaVoice', () {
    test('Yuna Enhanced outranks generic ko-KR', () {
      final yuna = CareTimerTtsService.scoreKoreanSpaVoice(
        name: 'Yuna (Enhanced)',
        locale: 'ko-KR',
      );
      final generic = CareTimerTtsService.scoreKoreanSpaVoice(
        name: 'Korean',
        locale: 'ko-KR',
      );
      expect(yuna, greaterThan(generic));
      expect(yuna, greaterThan(40));
    });

    test('Microsoft Heami / SunHi beat unknown female', () {
      final heami = CareTimerTtsService.scoreKoreanSpaVoice(
        name: 'Microsoft Heami Online (Natural) - Korean (Korea)',
        locale: 'ko-KR',
      );
      final sunhi = CareTimerTtsService.scoreKoreanSpaVoice(
        name: 'Microsoft SunHi Online (Natural) - Korean (Korea)',
        locale: 'ko-KR',
      );
      final plain = CareTimerTtsService.scoreKoreanSpaVoice(
        name: 'ko-KR female',
        locale: 'ko-KR',
      );
      expect(heami, greaterThan(plain));
      expect(sunhi, greaterThan(plain));
    });

    test('Google Neural2-A female beats Neural2-C male', () {
      final female = CareTimerTtsService.scoreKoreanSpaVoice(
        name: 'ko-KR-Neural2-A',
        locale: 'ko-KR',
      );
      final male = CareTimerTtsService.scoreKoreanSpaVoice(
        name: 'ko-KR-Neural2-C',
        locale: 'ko-KR',
      );
      expect(female, greaterThan(0));
      expect(male, 0);
    });

    test('rejects non-Korean and explicit male voices', () {
      expect(
        CareTimerTtsService.scoreKoreanSpaVoice(
          name: 'Samantha',
          locale: 'en-US',
        ),
        0,
      );
      expect(
        CareTimerTtsService.scoreKoreanSpaVoice(
          name: 'InJoon',
          locale: 'ko-KR',
        ),
        0,
      );
    });

    test('spa rate/pitch stay in elegant band', () {
      expect(CareTimerTtsService.spaSpeechRate, inInclusiveRange(0.35, 1.0));
      expect(CareTimerTtsService.spaPitch, inInclusiveRange(1.05, 1.25));
    });
  });
}
