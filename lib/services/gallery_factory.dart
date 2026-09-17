import 'gallery_source.dart';
import 'gallery_source_stub.dart'
    if (dart.library.io) 'gallery_source_io.dart'
    if (dart.library.js_interop) 'gallery_source_web.dart' as impl;

GallerySource createGallerySource() => impl.createGallerySource();
