import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// InteractiveViewer 변환 + 뷰포트에서 원본 픽셀 크롭 영역을 계산한다.
Rect visibleCropRect({
  required Size imageSize,
  required Size displaySize,
  required Size viewport,
  required Matrix4 matrix,
}) {
  if (imageSize.width <= 0 ||
      imageSize.height <= 0 ||
      displaySize.width <= 0 ||
      viewport.width <= 0) {
    return Rect.fromLTWH(0, 0, imageSize.width, imageSize.height);
  }

  Matrix4 inverted;
  try {
    inverted = Matrix4.inverted(matrix);
  } catch (_) {
    inverted = Matrix4.identity();
  }
  final tl = MatrixUtils.transformPoint(inverted, Offset.zero);
  final br = MatrixUtils.transformPoint(
    inverted,
    Offset(viewport.width, viewport.height),
  );
  final displayRect = Rect.fromPoints(tl, br);
  final sx = imageSize.width / displaySize.width;
  final sy = imageSize.height / displaySize.height;
  final left = (displayRect.left * sx).clamp(0, imageSize.width);
  final top = (displayRect.top * sy).clamp(0, imageSize.height);
  final right = (displayRect.right * sx).clamp(0, imageSize.width);
  final bottom = (displayRect.bottom * sy).clamp(0, imageSize.height);
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    math.max(left + 1, right).toDouble(),
    math.max(top + 1, bottom).toDouble(),
  );
}

/// Cover-fit 시 디스플레이 크기 (뷰포트에 이미지가 가득 차도록).
Size coverDisplaySize(Size image, Size viewport) {
  if (image.width <= 0 || image.height <= 0 || viewport.width <= 0) {
    return viewport;
  }
  final scale = math.max(
    viewport.width / image.width,
    viewport.height / image.height,
  );
  return Size(image.width * scale, image.height * scale);
}

/// Cover가 뷰포트 중앙에 오도록 초기 Matrix.
Matrix4 centeredCoverMatrix(Size display, Size viewport) {
  final dx = (viewport.width - display.width) / 2;
  final dy = (viewport.height - display.height) / 2;
  return Matrix4.identity()..translateByDouble(dx, dy, 0, 1);
}

/// JPEG 바이트로 크롭 결과를 반환한다. 긴 변은 [maxEdge]로 제한.
Uint8List? cropJpegBytes({
  required Uint8List source,
  required Rect crop,
  int maxEdge = 1600,
  int quality = 85,
}) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return source;
  var x = crop.left.round().clamp(0, decoded.width - 1);
  var y = crop.top.round().clamp(0, decoded.height - 1);
  var w = crop.width.round().clamp(1, decoded.width - x);
  var h = crop.height.round().clamp(1, decoded.height - y);
  var out = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
  final longest = math.max(out.width, out.height);
  if (longest > maxEdge) {
    final s = maxEdge / longest;
    out = img.copyResize(
      out,
      width: (out.width * s).round().clamp(1, maxEdge),
      height: (out.height * s).round().clamp(1, maxEdge),
      interpolation: img.Interpolation.linear,
    );
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}
