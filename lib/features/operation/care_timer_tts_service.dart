import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'care_timer_tts_stub_unlock.dart'
    if (dart.library.html) 'care_timer_tts_web_unlock.dart';

/// 하이엔드 에스테틱 케어 안내 TTS — 우아·차분한 20대 후반 여성 톤.
abstract final class CareTimerTtsService {
  static FlutterTts? _tts;
  static bool _ready = false;
  static bool _muted = false;
  static bool _primed = false;

  /// 스파 안내: 여유롭되 늘어지지 않게. 웹은 SpeechSynthesis 스케일이 달라 보정.
  static double get spaSpeechRate {
    if (kIsWeb) return 0.92; // web: 1.0 ≈ 기본, 살짝 느리게
    // iOS/Android flutter_tts: 0.5 ≈ 보통 → 0.43 스파 페이스
    return 0.43;
  }

  /// 밝고 우아한 톤 — 우울·힘 빠짐 방지.
  static double get spaPitch {
    if (kIsWeb) return 1.12;
    return 1.18;
  }

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
    await tts.setSpeechRate(spaSpeechRate);
    await tts.setPitch(spaPitch);
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(true);

    final picked = await _pickPremiumKoreanFemaleVoice(tts);
    if (picked != null) {
      try {
        await tts.setVoice(picked);
        // 일부 엔진은 setVoice 후 rate/pitch가 리셋된다 — 재적용.
        await tts.setLanguage(picked['locale'] ?? 'ko-KR');
        await tts.setSpeechRate(spaSpeechRate);
        await tts.setPitch(spaPitch);
        debugPrint(
          'CareTimerTts voice → ${picked['name']} (${picked['locale']}) '
          'rate=$spaSpeechRate pitch=$spaPitch',
        );
      } catch (e) {
        debugPrint('CareTimerTts setVoice failed: $e');
      }
    } else {
      debugPrint('CareTimerTts: no premium ko female voice; locale ko-KR only');
    }

    _tts = tts;
    _ready = true;
  }

  /// getVoices를 스캔해 프리미엄 한국어 여성 보이스를 점수 순으로 고른다.
  static Future<Map<String, String>?> _pickPremiumKoreanFemaleVoice(
    FlutterTts tts,
  ) async {
    try {
      final voicesRaw = await tts.getVoices;
      if (voicesRaw is! List) return null;
      final scored = <({Map<String, String> voice, int score})>[];
      for (final v in voicesRaw) {
        if (v is! Map) continue;
        final map = Map<String, String>.from(
          v.map((k, val) => MapEntry('$k', '$val')),
        );
        final score = scoreKoreanSpaVoice(
          name: map['name'] ?? '',
          locale: map['locale'] ?? '',
        );
        if (score <= 0) continue;
        scored.add((voice: map, score: score));
      }
      if (scored.isEmpty) return null;
      scored.sort((a, b) => b.score.compareTo(a.score));
      return scored.first.voice;
    } catch (e) {
      debugPrint('CareTimerTts voice pick skipped: $e');
      return null;
    }
  }

  /// 보이스 품질 점수 — 테스트·튜닝용으로 공개.
  /// 0 이하면 후보 제외(남성·비한국어·저품질).
  @visibleForTesting
  static int scoreKoreanSpaVoice({
    required String name,
    required String locale,
  }) {
    final n = name.toLowerCase().trim();
    final loc = locale.toLowerCase().trim();
    if (n.isEmpty) return 0;
    final isKo = loc.contains('ko') ||
        n.contains('korean') ||
        n.contains('한국') ||
        n.contains('yuna') ||
        n.contains('heami') ||
        n.contains('sunhi') ||
        n.contains('sora');
    if (!isKo && !loc.startsWith('ko')) return 0;

    // 명시적 남성 / 저품질 제외
    const maleHints = [
      'male',
      'man',
      'injoon',
      'in-joon',
      'bongjin',
      'bong-jin',
      'hyunsu',
      'jinho',
      'standard-c',
      'standard-d',
      'wavenet-c',
      'wavenet-d',
      'neural2-c',
      'neural2-d',
    ];
    for (final m in maleHints) {
      if (n.contains(m)) return 0;
    }

    var score = 10; // 한국어 기본

    // —— 프리미엄 / Enhanced / Neural ——
    if (n.contains('enhanced') || n.contains('premium') || n.contains('quality')) {
      score += 40;
    }
    if (n.contains('neural') || n.contains('neural2') || n.contains('wavenet')) {
      score += 35;
    }
    if (n.contains('natural') || n.contains('siri')) score += 25;
    if (n.contains('google') || n.contains('microsoft') || n.contains('apple')) {
      score += 15;
    }

    // —— 알려진 고품질 한국어 여성 ——
    // iOS: Yuna (Enhanced)
    if (n.contains('yuna')) score += 50;
    // Windows / Azure: Heami
    if (n.contains('heami') || n.contains('he-ami')) score += 48;
    // Azure: SunHi / Sun-Hi
    if (n.contains('sunhi') || n.contains('sun-hi') || n.contains('sun_hi')) {
      score += 46;
    }
    // 일부 기기: Sora (여성)
    if (n.contains('sora') && !n.contains('sora-male')) score += 30;
    // Google: Standard-A / Wavenet-A / Neural2-A (여성)
    if (n.contains('standard-a') ||
        n.contains('wavenet-a') ||
        n.contains('neural2-a') ||
        n.contains('chirp-a') ||
        n.contains('chirp3-hd')) {
      score += 42;
    }
    if (n.contains('standard-b') ||
        n.contains('wavenet-b') ||
        n.contains('neural2-b')) {
      score += 38;
    }

    // 일반 여성 힌트
    if (n.contains('female') ||
        n.contains('woman') ||
        n.contains('girl') ||
        n.contains('여성')) {
      score += 20;
    }

    // 로케일 정확도
    if (loc == 'ko-kr' || loc == 'ko_kr') score += 8;
    if (loc.startsWith('ko')) score += 4;

    // 컴팩트/저품질 감점
    if (n.contains('compact') || n.contains('eloquence')) score -= 15;
    if (n.contains('robot') || n.contains('festival')) score -= 20;

    return score;
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
      // 발화 직전 톤 재고정 (엔진/보이스 전환 후 드리프트 방지).
      await tts.setSpeechRate(spaSpeechRate);
      await tts.setPitch(spaPitch);
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
      await tts.setSpeechRate(spaSpeechRate);
      await tts.setPitch(spaPitch);
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
