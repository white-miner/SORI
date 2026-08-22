import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/gallery_factory.dart';
import '../services/gallery_source.dart';
import '../theme/sori_tokens.dart';
import '../utils/insta_crop.dart';
import '../widgets/media_permission_dialogs.dart';

/// 인스타그램 '새 게시물' 스타일 인앱 포토 피커.
class CustomInstaPickerPage extends StatefulWidget {
  const CustomInstaPickerPage({
    super.key,
    this.maxAssets = 20,
    this.title = '새 게시물',
  });

  final int maxAssets;
  final String title;

  @override
  State<CustomInstaPickerPage> createState() => _CustomInstaPickerPageState();
}

class _CustomInstaPickerPageState extends State<CustomInstaPickerPage> {
  static const _aspects = <(String, double)>[
    ('1:1', 1),
    ('4:5', 4 / 5),
  ];

  final _source = createGallerySource();
  final _transform = TransformationController();
  final _thumbCache = <String, Uint8List>{};
  final _originCache = <String, Uint8List>{};
  final _matrixByAsset = <String, Matrix4>{};

  List<GalleryAlbum> _albums = const [];
  GalleryAlbum? _album;
  final List<GalleryAsset> _assets = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _denied = false;
  bool _multi = false;
  int _aspectIndex = 0;
  GalleryAsset? _focused;
  final List<GalleryAsset> _selected = [];
  Size? _decodedSize;
  bool _exporting = false;

  double get _aspect => _aspects[_aspectIndex].$2;

  bool get _allowsMulti => widget.maxAssets > 1;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final ok = await _source.requestPermission();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _denied = true;
        _loading = false;
      });
      return;
    }
    if (kIsWeb) {
      final files = await _source.pickLocalFiles(limit: widget.maxAssets);
      if (!mounted) return;
      _assets
        ..clear()
        ..addAll(files);
      _albums = [const GalleryAlbum(id: 'web-recent', name: '최근 항목')];
      _album = _albums.first;
      _focused = _assets.isEmpty ? null : _assets.first;
      if (_focused != null) _selected.add(_focused!);
      setState(() => _loading = false);
      if (_focused != null) await _preparePreview(_focused!);
      return;
    }
    final albums = await _source.loadAlbums();
    if (!mounted) return;
    _albums = albums;
    _album = albums.isEmpty ? null : albums.first;
    setState(() {});
    await _reloadAlbum();
  }

  Future<void> _reloadAlbum() async {
    _page = 0;
    _hasMore = true;
    _assets.clear();
    await _loadMore();
    if (_assets.isNotEmpty) {
      _focused ??= _assets.first;
      if (_selected.isEmpty) _selected.add(_focused!);
      await _preparePreview(_focused!);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _album == null) return;
    _loadingMore = true;
    final next = await _source.loadAssets(
      _album!,
      page: _page,
      pageSize: 80,
    );
    if (!mounted) return;
    _assets.addAll(next);
    _hasMore = next.length >= 80;
    _page += 1;
    _loadingMore = false;
    setState(() {});
  }

  Future<void> _preparePreview(GalleryAsset asset) async {
    _saveCurrentMatrix();
    final bytes =
        _originCache[asset.id] ?? await asset.originBytes();
    if (bytes == null || !mounted) return;
    _originCache[asset.id] = bytes;
    final decoded = await _decodeSize(bytes);
    _decodedSize = decoded;
    final restored = _matrixByAsset[asset.id];
    if (restored != null) {
      _transform.value = Matrix4.copy(restored);
    } else {
      _transform.value = Matrix4.identity();
    }
    if (mounted) setState(() {});
  }

  Future<Size> _decodeSize(Uint8List bytes) async {
    final c = CompleterImage(bytes);
    return c.size;
  }

  void _saveCurrentMatrix() {
    final id = _focused?.id;
    if (id == null) return;
    _matrixByAsset[id] = Matrix4.copy(_transform.value);
  }

  void _onTapAsset(GalleryAsset asset) {
    if (_multi && _allowsMulti) {
      final idx = _selected.indexWhere((e) => e.id == asset.id);
      setState(() {
        if (idx >= 0) {
          _selected.removeAt(idx);
          if (_focused?.id == asset.id) {
            _focused = _selected.isEmpty ? asset : _selected.last;
          }
        } else {
          if (_selected.length >= widget.maxAssets) return;
          _selected.add(asset);
          _focused = asset;
        }
      });
    } else {
      setState(() {
        _focused = asset;
        _selected
          ..clear()
          ..add(asset);
      });
    }
    _preparePreview(_focused!);
  }

  int? _badgeIndex(String id) {
    final i = _selected.indexWhere((e) => e.id == id);
    return i < 0 ? null : i + 1;
  }

  Future<void> _openCamera() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final id = 'cam-${DateTime.now().microsecondsSinceEpoch}';
      final asset = GalleryAsset(
        id: id,
        width: 0,
        height: 0,
        thumbnail: () async => bytes,
        originBytes: () async => bytes,
      );
      _originCache[id] = bytes;
      _thumbCache[id] = bytes;
      setState(() {
        _assets.insert(0, asset);
        _focused = asset;
        if (_multi && _allowsMulti) {
          if (_selected.length < widget.maxAssets) _selected.add(asset);
        } else {
          _selected
            ..clear()
            ..add(asset);
        }
      });
      await _preparePreview(asset);
    } catch (e) {
      if (!mounted) return;
      if (isMediaPermissionDeniedError(e)) {
        await showMediaPermissionDeniedDialog(context);
      }
    }
  }

  Future<void> _pickWebMore() async {
    final files = await _source.pickLocalFiles(limit: widget.maxAssets);
    if (!mounted || files.isEmpty) return;
    setState(() {
      _assets
        ..clear()
        ..addAll(files);
      _focused = _assets.first;
      _selected
        ..clear()
        ..add(_assets.first);
    });
    await _preparePreview(_focused!);
  }

  Future<void> _chooseAlbum() async {
    if (kIsWeb) {
      await _pickWebMore();
      return;
    }
    if (_albums.isEmpty) return;
    final picked = await showModalBottomSheet<GalleryAlbum>(
      context: context,
      useRootNavigator: true,
      backgroundColor: SoriTokens.surface,
      builder: (ctx) => ListView(
        children: [
          for (final a in _albums)
            ListTile(
              title: Text(a.name),
              selected: a.id == _album?.id,
              onTap: () => Navigator.pop(ctx, a),
            ),
        ],
      ),
    );
    if (picked == null || picked.id == _album?.id) return;
    setState(() {
      _album = picked;
      _loading = true;
      _focused = null;
      _selected.clear();
    });
    await _reloadAlbum();
  }

  Future<void> _export() async {
    if (_exporting) return;
    final targets = _selected.isNotEmpty
        ? _selected
        : (_focused == null ? <GalleryAsset>[] : [_focused!]);
    if (targets.isEmpty) return;
    setState(() => _exporting = true);
    _saveCurrentMatrix();

    final previewSize = _previewSize();
    final out = <Uint8List>[];
    for (final asset in targets) {
      final bytes =
          _originCache[asset.id] ?? await asset.originBytes();
      if (bytes == null) continue;
      final imgSize = asset.width > 0
          ? asset.size
          : await CompleterImage(bytes).size;
      final display = coverDisplaySize(imgSize, previewSize);
      var matrix = _matrixByAsset[asset.id];
      matrix ??= centeredCoverMatrix(display, previewSize);
      final crop = visibleCropRect(
        imageSize: imgSize,
        displaySize: display,
        viewport: previewSize,
        matrix: matrix,
      );
      final cropped = cropJpegBytes(source: bytes, crop: crop);
      if (cropped != null) out.add(cropped);
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    Navigator.pop(context, out);
  }

  Size _previewSize() {
    final w = MediaQuery.sizeOf(context).width;
    return Size(w, w / _aspect);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewSize();
    final albumLabel = _album?.name.trim().isNotEmpty == true
        ? _album!.name
        : '최근 항목';

    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        backgroundColor: SoriTokens.background,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
            child: FilledButton(
              onPressed: _exporting || _selected.isEmpty ? null : _export,
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
              ),
              child: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('다음', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: _denied
          ? _DeniedBody(
              onSettings: () async {
                await showMediaPermissionDeniedDialog(context);
              },
            )
          : Column(
              children: [
                SizedBox(
                  width: preview.width,
                  height: preview.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: const Color(0xFF111113),
                        child: _focused == null
                            ? const Center(
                                child: Icon(Icons.photo_outlined,
                                    color: SoriTokens.textSecondary, size: 40),
                              )
                            : _PreviewViewer(
                                bytes: _originCache[_focused!.id],
                                imageSize: _decodedSize ?? _focused!.size,
                                viewport: preview,
                                controller: _transform,
                                onReady: () {
                                  if (_matrixByAsset[_focused!.id] != null) {
                                    return;
                                  }
                                  final display = coverDisplaySize(
                                    _decodedSize ?? _focused!.size,
                                    preview,
                                  );
                                  _transform.value =
                                      centeredCoverMatrix(display, preview);
                                  _matrixByAsset[_focused!.id] =
                                      Matrix4.copy(_transform.value);
                                },
                              ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: _AspectButton(
                          label: _aspects[_aspectIndex].$1,
                          onTap: () {
                            setState(() {
                              _aspectIndex =
                                  (_aspectIndex + 1) % _aspects.length;
                              _matrixByAsset.clear();
                            });
                            if (_focused != null) {
                              _transform.value = Matrix4.identity();
                              _preparePreview(_focused!);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: SoriTokens.background,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _chooseAlbum,
                        child: Row(
                          children: [
                            Text(
                              albumLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 20),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '카메라',
                        onPressed: _openCamera,
                        icon: const Icon(Icons.photo_camera_outlined),
                      ),
                      if (_allowsMulti)
                        _MultiToggle(
                          active: _multi,
                          onTap: () {
                            setState(() {
                              _multi = !_multi;
                              if (!_multi && _focused != null) {
                                _selected
                                  ..clear()
                                  ..add(_focused!);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n.metrics.pixels >
                                n.metrics.maxScrollExtent - 400) {
                              _loadMore();
                            }
                            return false;
                          },
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 1.5,
                              crossAxisSpacing: 1.5,
                            ),
                            itemCount: _assets.length + 1,
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                return _CameraTile(onTap: _openCamera);
                              }
                              final asset = _assets[i - 1];
                              final badge =
                                  _multi ? _badgeIndex(asset.id) : null;
                              final focused = _focused?.id == asset.id;
                              return _ThumbTile(
                                asset: asset,
                                cache: _thumbCache,
                                badge: badge,
                                focused: focused,
                                onTap: () => _onTapAsset(asset),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class CompleterImage {
  CompleterImage(this.bytes);
  final Uint8List bytes;

  Future<Size> get size async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final s = Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();
    codec.dispose();
    return s;
  }
}

class _PreviewViewer extends StatefulWidget {
  const _PreviewViewer({
    required this.bytes,
    required this.imageSize,
    required this.viewport,
    required this.controller,
    required this.onReady,
  });

  final Uint8List? bytes;
  final Size imageSize;
  final Size viewport;
  final TransformationController controller;
  final VoidCallback onReady;

  @override
  State<_PreviewViewer> createState() => _PreviewViewerState();
}

class _PreviewViewerState extends State<_PreviewViewer> {
  var _ready = false;

  @override
  void didUpdateWidget(covariant _PreviewViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) _ready = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final display = coverDisplaySize(widget.imageSize, widget.viewport);
    return ClipRect(
      child: InteractiveViewer(
        transformationController: widget.controller,
        constrained: false,
        minScale: 1,
        maxScale: 4,
        panEnabled: true,
        scaleEnabled: true,
        child: SizedBox(
          width: display.width,
          height: display.height,
          child: Image.memory(
            widget.bytes!,
            fit: BoxFit.cover,
            width: display.width,
            height: display.height,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) {
              if (!_ready && (sync || frame != null)) {
                _ready = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onReady();
                });
              }
              return child;
            },
          ),
        ),
      ),
    );
  }
}

class _AspectButton extends StatelessWidget {
  const _AspectButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.crop_free_rounded, color: Colors.white, size: 18),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MultiToggle extends StatelessWidget {
  const _MultiToggle({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.filter_none_rounded,
              size: 18,
              color: active ? SoriTokens.primary : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              '선택',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: active ? SoriTokens.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF27272A),
      child: InkWell(
        onTap: onTap,
        child: const Center(
          child: Icon(Icons.photo_camera_outlined, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({
    required this.asset,
    required this.cache,
    required this.onTap,
    this.badge,
    this.focused = false,
  });

  final GalleryAsset asset;
  final Map<String, Uint8List> cache;
  final VoidCallback onTap;
  final int? badge;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final cached = cache[asset.id];
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cached != null)
            Image.memory(cached, fit: BoxFit.cover, gaplessPlayback: true)
          else
            FutureBuilder<Uint8List?>(
              future: asset.thumbnail(),
              builder: (context, snap) {
                final data = snap.data;
                if (data != null) cache[asset.id] = data;
                if (data == null) {
                  return const ColoredBox(color: Color(0xFF18181B));
                }
                return Image.memory(data, fit: BoxFit.cover);
              },
            ),
          if (focused)
            const DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 2),
                ),
                color: Color(0x33FFFFFF),
              ),
            ),
          if (badge != null)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeniedBody extends StatelessWidget {
  const _DeniedBody({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '사진 접근 권한이 필요해요',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text(
              '갤러리에서 사진을 고르려면 설정에서 접근을 허용해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SoriTokens.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onSettings,
              style: FilledButton.styleFrom(backgroundColor: SoriTokens.primary),
              child: const Text('안내 보기'),
            ),
          ],
        ),
      ),
    );
  }
}
