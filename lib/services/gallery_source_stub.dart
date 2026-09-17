import 'gallery_source.dart';

GallerySource createGallerySource() => _UnsupportedGallerySource();

class _UnsupportedGallerySource implements GallerySource {
  @override
  Future<List<GalleryAlbum>> loadAlbums() async => const [];

  @override
  Future<List<GalleryAsset>> loadAssets(
    GalleryAlbum album, {
    required int page,
    int pageSize = 80,
  }) async =>
      const [];

  @override
  Future<List<GalleryAsset>> pickLocalFiles({int limit = 20}) async =>
      const [];

  @override
  Future<bool> requestPermission() async => false;
}
