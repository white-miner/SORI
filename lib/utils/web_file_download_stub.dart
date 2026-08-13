import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

Future<void> downloadBytesToDevice({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  // 모바일/데스크톱: 공유 시트로 저장 유도.
  await Printing.sharePdf(bytes: bytes, filename: filename);
  if (kDebugMode && !mimeType.contains('pdf')) {
    // PNG 등도 sharePdf로 전달 가능(파일명 확장자 기준).
  }
}
