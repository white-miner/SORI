import 'dart:typed_data';
import 'dart:ui';

class GalleryAlbum {
  const GalleryAlbum({
    required this.id,
    required this.name,
    this.nativePath,
  });

  final String id;
  final String name;
  final Object? nativePath;
}

class GalleryAsset {
  const GalleryAsset({
    required this.id,
    required this.thumbnail,
    required this.originBytes,
    this.width = 0,
    this.height = 0,
  });

  final String id;
  final Future<Uint8List?> Function() thumbnail;
  final Future<Uint8List?> Function() originBytes;
  final int width;
  final int height;

  Size get size => Size(
        width > 0 ? width.toDouble() : 1,
        height > 0 ? height.toDouble() : 1,
      );
}

abstract class GallerySource {
  Future<bool> requestPermission();
  Future<List<GalleryAlbum>> loadAlbums();
  Future<List<GalleryAsset>> loadAssets(
    GalleryAlbum album, {
    required int page,
    int pageSize = 80,
  });

  /// 웹: 파일 피커로 로컬 에셋 시드. 네이티브는 no-op.
  Future<List<GalleryAsset>> pickLocalFiles({int limit = 20});
}
