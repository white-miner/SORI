import 'package:web/web.dart';

/// 브라우저 autoplay 정책: 사용자 제스처 안에서 AudioContext + SpeechSynthesis 활성화.
void unlockSpeechAudio() {
  try {
    final ctx = AudioContext();
    ctx.resume();
  } catch (_) {}
  try {
    final synth = window.speechSynthesis;
    synth.cancel();
    final warm = SpeechSynthesisUtterance(' ');
    warm.volume = 0;
    warm.rate = 10;
    synth.speak(warm);
    synth.cancel();
  } catch (_) {}
}
