import 'package:image_picker/image_picker.dart';

import 'gallery_source.dart';

GallerySource createGallerySource() => WebGallerySource();

class WebGallerySource implements GallerySource {
  final List<GalleryAsset> _seeded = [];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<List<GalleryAlbum>> loadAlbums() async => [
        const GalleryAlbum(id: 'web-recent', name: '최근 항목'),
      ];

  @override
  Future<List<GalleryAsset>> loadAssets(
    GalleryAlbum album, {
    required int page,
    int pageSize = 80,
  }) async {
    if (page > 0) return const [];
    return List.unmodifiable(_seeded);
  }

  @override
  Future<List<GalleryAsset>> pickLocalFiles({int limit = 20}) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
      limit: limit,
      imageQuality: 95,
    );
    final out = <GalleryAsset>[];
    var i = 0;
    for (final f in files.take(limit)) {
      final bytes = await f.readAsBytes();
      final id = 'web-${DateTime.now().microsecondsSinceEpoch}-$i';
      i++;
      out.add(
        GalleryAsset(
          id: id,
          width: 0,
          height: 0,
          thumbnail: () async => bytes,
          originBytes: () async => bytes,
        ),
      );
    }
    _seeded
      ..clear()
      ..addAll(out);
    return out;
  }
}
