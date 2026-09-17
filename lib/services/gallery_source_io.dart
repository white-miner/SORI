import 'package:photo_manager/photo_manager.dart';

import 'gallery_source.dart';

GallerySource createGallerySource() => IoGallerySource();

class IoGallerySource implements GallerySource {
  @override
  Future<bool> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.hasAccess;
  }

  @override
  Future<List<GalleryAlbum>> loadAlbums() async {
    final all = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    final rest = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: false,
    );
    final seen = {for (final p in all) p.id};
    return [
      for (final p in all)
        GalleryAlbum(
          id: p.id,
          name: p.isAll ? '최근 항목' : p.name,
          nativePath: p,
        ),
      for (final p in rest)
        if (!seen.contains(p.id))
          GalleryAlbum(id: p.id, name: p.name, nativePath: p),
    ];
  }

  @override
  Future<List<GalleryAsset>> loadAssets(
    GalleryAlbum album, {
    required int page,
    int pageSize = 80,
  }) async {
    final path = album.nativePath;
    if (path is! AssetPathEntity) return const [];
    final list = await path.getAssetListPaged(page: page, size: pageSize);
    return [
      for (final e in list)
        GalleryAsset(
          id: e.id,
          width: e.width,
          height: e.height,
          thumbnail: () => e.thumbnailDataWithSize(
            const ThumbnailSize(300, 300),
          ),
          originBytes: () async {
            final file = await e.file;
            if (file != null) return file.readAsBytes();
            return e.originBytes;
          },
        ),
    ];
  }

  @override
  Future<List<GalleryAsset>> pickLocalFiles({int limit = 20}) async =>
      const [];
}
