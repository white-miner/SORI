import 'dart:js_interop';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

import 'media_permission_query.dart';

Future<MediaPermissionState> queryMediaPermissionState(
  ImageSource source,
) async {
  try {
    // 갤러리는 <input type=file> — 카메라 Permission과 무관, 즉시 허용으로 취급.
    if (source == ImageSource.gallery) {
      return MediaPermissionState.granted;
    }

    final permissions = web.window.navigator.permissions;
    final status = await permissions
        .query({'name': 'camera'}.jsify() as JSObject)
        .toDart;
    final state = status.state;
    if (state == 'granted') return MediaPermissionState.granted;
    if (state == 'denied') return MediaPermissionState.denied;
    return MediaPermissionState.unknown;
  } catch (_) {
    return MediaPermissionState.unknown;
  }
}
