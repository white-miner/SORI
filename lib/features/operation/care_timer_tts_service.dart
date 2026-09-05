import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// PRD UT-1 / v5.2 — Korean care timer voice prompts.
abstract final class CareTimerTtsService {
  static FlutterTts? _tts;
  static bool _ready = false;
  static bool _muted = false;

  static bool get isMuted => _muted;

  static void setMuted(bool muted) {
    _muted = muted;
    if (muted) unawaited(_tts?.stop());
  }

  static Future<void> _ensureReady() async {
    if (_ready && _tts != null) return;
    final tts = FlutterTts();
    await tts.setLanguage('ko-KR');
    // 차분한 20대 후반 여성: 조금 느리고 피치는 살짝 높게.
    await tts.setSpeechRate(0.40);
    await tts.setPitch(1.14);
    await tts.setVolume(1.0);
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
      await _ensureReady();
      final tts = _tts;
      if (tts == null) return;
      await tts.stop();
      await tts.speak(text);
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
      await _ensureReady();
      final tts = _tts;
      if (tts == null) return;
      await tts.stop();
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

  static Future<void> announceStepStart(String stepLabel) {
    final name = stepLabel.trim();
    if (name.isEmpty) return announceNextStep();
    return speak('$name${_objectParticle(name)} 시작합니다.');
  }

  static String _objectParticle(String word) {
    final last = word.runes.last;
    if (last < 0xAC00 || last > 0xD7A3) return '를';
    return ((last - 0xAC00) % 28 == 0) ? '를' : '을';
  }

  static Future<void> announceNextStep() => speak('다음 케어를 진행합니다.');

  static Future<void> announceCarePlanComplete() => speak('케어가 종료되었습니다.');
}
