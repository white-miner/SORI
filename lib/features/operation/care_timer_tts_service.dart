import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'care_timer_tts_stub_unlock.dart'
    if (dart.library.html) 'care_timer_tts_web_unlock.dart';

/// PRD UT-1 / v5.2 — Korean care timer voice prompts (device TTS, no audio files).
abstract final class CareTimerTtsService {
  static FlutterTts? _tts;
  static bool _ready = false;
  static bool _muted = false;
  static bool _primed = false;

  static bool get isMuted => _muted;

  static void setMuted(bool muted) {
    _muted = muted;
    if (muted) unawaited(_tts?.stop());
  }

  /// 사용자 터치(케어 시작 등) 직후 호출 — 웹 autoplay 차단·iOS 오디오 세션 워밍.
  static Future<void> primeFromUserGesture() async {
    unlockSpeechAudio();
    await _ensureReady();
    _primed = true;
  }

  static Future<void> _ensureReady() async {
    if (_ready && _tts != null) return;
    final tts = FlutterTts();
    try {
      if (!kIsWeb) {
        await tts.setSharedInstance(true);
        await tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
    } catch (e) {
      debugPrint('CareTimerTts iOS audio session skipped: $e');
    }
    await tts.setLanguage('ko-KR');
    // 차분한 20대 후반 여성: 조금 느리고 피치는 살짝 높게.
    await tts.setSpeechRate(0.40);
    await tts.setPitch(1.14);
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(true);
    try {
      final voicesRaw = await tts.getVoices;
      if (voicesRaw is List) {
        Map<String, String>? picked;
        for (final v in voicesRaw) {
          if (v is! Map) continue;
          final name = '${v['name'] ?? ''}'.toLowerCase();
          final locale = '${v['locale'] ?? ''}'.toLowerCase();
          if (!locale.contains('ko')) continue;
          if (name.contains('yuna') ||
              name.contains('heami') ||
              name.contains('sunhi') ||
              name.contains('female') ||
              name.contains('woman') ||
              name.contains('neural')) {
            picked = Map<String, String>.from(
              v.map((k, val) => MapEntry('$k', '$val')),
            );
            break;
          }
          picked ??= Map<String, String>.from(
            v.map((k, val) => MapEntry('$k', '$val')),
          );
        }
        if (picked != null) {
          await tts.setVoice(picked);
        }
      }
    } catch (e) {
      debugPrint('CareTimerTts voice pick skipped: $e');
    }
    _tts = tts;
    _ready = true;
  }

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty || _muted) return;
    try {
      if (!_primed) {
        unlockSpeechAudio();
        _primed = true;
      }
      await _ensureReady();
      final tts = _tts;
      if (tts == null) return;
      // 웹 플러그인은 stop 직후 state가 playing이면 speak를 무시한다 — 짧은 간격 필요.
      await tts.stop();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final result = await tts.speak(text);
      debugPrint('CareTimerTts speak("$text") → $result');
    } catch (e) {
      debugPrint('CareTimerTts speak failed: $e');
    }
  }

  static Future<void> announceCareStartIntro() async =>
      speakAndWait('케어를 시작합니다.');

  static Future<void> speakAndWait(
    String text, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (text.trim().isEmpty || _muted) return;
    try {
      if (!_primed) {
        unlockSpeechAudio();
        _primed = true;
      }
      await _ensureReady();
      final tts = _tts;
      if (tts == null) return;
      await tts.stop();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final completer = Completer<void>();
      tts.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
      await tts.speak(text);
      await completer.future.timeout(timeout, onTimeout: () {});
    } catch (e) {
      debugPrint('CareTimerTts speakAndWait failed: $e');
    }
  }

  static Future<void> announceCareStart() => speak('케어를 시작합니다.');

  static Future<void> announceCareEnd() => speak('케어를 종료합니다.');

  static Future<void> announceStepStart(String stepLabel) {
    final name = stepLabel.trim();
    if (name.isEmpty) return announceNextStep();
    return speak('$name${_objectParticle(name)} 진행합니다.');
  }

  static String _objectParticle(String word) {
    final last = word.runes.last;
    if (last < 0xAC00 || last > 0xD7A3) return '를';
    return ((last - 0xAC00) % 28 == 0) ? '를' : '을';
  }

  static Future<void> announceNextStep() => speak('다음 케어를 진행합니다.');

  static Future<void> announceCarePlanComplete() => speak('케어가 종료되었습니다.');
}
