import 'dart:js_interop';

import 'package:web/web.dart' as web;

void soriLightHaptic() {
  try {
    web.window.navigator.vibrate(18.toJS);
  } catch (_) {
    // Vibration unsupported — ignore
  }
}
