import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// PRD v6.0 — clipboard-first Kakao assist (MVP).
abstract final class VisitReportKakaoLauncher {
  static Future<void> sendViaKakao(String message) async {
    await Clipboard.setData(ClipboardData(text: message));

    if (kIsWeb) return;

    final encoded = Uri.encodeComponent(message);
    final candidates = [
      Uri.parse('kakaotalk://send?text=$encoded'),
      Uri.parse('kakaolink://send?text=$encoded'),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }
  }
}
