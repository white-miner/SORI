import 'package:image_picker/image_picker.dart';

import 'media_permission_query.dart';

Future<MediaPermissionState> queryMediaPermissionState(ImageSource source) async {
  // 네이티브: image_picker가 OS 권한 세션을 관리. 앱에서 재요청하지 않음.
  return MediaPermissionState.unknown;
}
