import 'dart:typed_data';

import 'web_file_download_stub.dart'
    if (dart.library.html) 'web_file_download_web.dart' as impl;

/// 브라우저 Anchor/Blob 다운로드 (웹) 또는 share 폴백 (기타).
Future<void> downloadBytesToDevice({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  return impl.downloadBytesToDevice(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );
}
