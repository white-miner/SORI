import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 차트 사진 클라이언트 선압축 — 긴 축 ≤1200px, WebP quality 80.
abstract final class ChartPhotoCompressor {
  static const int maxLongEdge = 1200;
  static const int quality = 80;
  static const int targetMaxBytes = 500 * 1024;

  /// 원본 바이트 → WebP. 실패 시 null.
  static Future<Uint8List?> toWebp(Uint8List source) async {
    if (source.isEmpty) return null;

    try {
      var out = await FlutterImageCompress.compressWithList(
        source,
        minWidth: maxLongEdge,
        minHeight: maxLongEdge,
        quality: quality,
        format: CompressFormat.webp,
        keepExif: false,
      );

      // 여전히 크면 quality를 단계적으로 낮춰 500KB 근처로 유도
      var q = quality;
      while (out.isNotEmpty && out.length > targetMaxBytes && q > 45) {
        q -= 10;
        out = await FlutterImageCompress.compressWithList(
          source,
          minWidth: maxLongEdge,
          minHeight: maxLongEdge,
          quality: q,
          format: CompressFormat.webp,
          keepExif: false,
        );
      }

      if (out.isEmpty) {
        debugPrint('ChartPhotoCompressor: empty WebP result');
        return null;
      }

      debugPrint(
        'ChartPhotoCompressor: ${source.length}B → ${out.length}B '
        'WebP (q≈$q, longEdge≤$maxLongEdge)',
      );
      return out;
    } catch (e, st) {
      debugPrint('ChartPhotoCompressor.toWebp failed: $e\n$st');
      return null;
    }
  }
}
