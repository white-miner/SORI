import 'package:image_picker/image_picker.dart';

import 'media_permission_query_stub.dart'
    if (dart.library.js_interop) 'media_permission_query_web.dart' as impl;

enum MediaPermissionState {
  /// Permissions API 미지원 / 조회 불가 / prompt
  unknown,

  /// 이미 허용됨 — 재안내·재요청 불필요
  granted,

  /// 명시적 거부
  denied,
}

Future<MediaPermissionState> queryMediaPermissionState(ImageSource source) {
  return impl.queryMediaPermissionState(source);
}
