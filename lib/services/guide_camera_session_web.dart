import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'guide_camera_session.dart';

GuideCameraSession createGuideCameraSession() => WebGuideCameraSession();

class WebGuideCameraSession implements GuideCameraSession {
  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;
  String? _viewType;
  bool _mirrored = false;
  StreamController<double?>? _rollCtrl;
  web.EventListener? _orientListener;

  @override
  String? get viewType => _viewType;

  @override
  bool get isRunning => _stream != null && _video != null;

  @override
  bool get mirrored => _mirrored;

  @override
  int get videoWidth => _video?.videoWidth ?? 0;

  @override
  int get videoHeight => _video?.videoHeight ?? 0;

  @override
  Stream<double?> get rollDegrees {
    _rollCtrl ??= StreamController<double?>.broadcast();
    return _rollCtrl!.stream;
  }

  @override
  Future<bool> requestOrientationPermission() async {
    try {
      final doe = globalContext.getProperty('DeviceOrientationEvent'.toJS);
      if (doe == null || doe.isUndefinedOrNull) return true;
      final req = (doe as JSObject).getProperty('requestPermission'.toJS);
      if (req == null || req.isUndefinedOrNull) return true;
      final promise = (req as JSFunction).callAsFunction();
      if (promise == null) return true;
      final result = await (promise as JSPromise<JSAny?>).toDart;
      final s = (result as JSString?)?.toDart ?? 'denied';
      return s == 'granted';
    } catch (e) {
      debugPrint('requestOrientationPermission: $e');
      return false;
    }
  }

  @override
  Future<void> start({required bool front}) async {
    await stop();
    _mirrored = front;

    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.transform = front ? 'scaleX(-1)' : 'none'
      ..style.setProperty('transform-origin', 'center center');

    web.MediaStream stream;
    try {
      final constraints = {
        'audio': false,
        'video': {
          'facingMode': front ? 'user' : 'environment',
          'width': {'ideal': 1920},
          'height': {'ideal': 1440},
        },
      }.jsify()! as web.MediaStreamConstraints;
      stream =
          await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
    } catch (e) {
      debugPrint('getUserMedia facingMode failed, retry soft: $e');
      final soft = {
        'audio': false,
        'video': true,
      }.jsify()! as web.MediaStreamConstraints;
      stream =
          await web.window.navigator.mediaDevices.getUserMedia(soft).toDart;
    }

    _stream = stream;
    video.srcObject = stream;
    await video.play().toDart;

    _video = video;
    _viewType =
        'sori-guide-cam-${DateTime.now().microsecondsSinceEpoch}-${front ? 'f' : 'b'}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType!,
      (int viewId) => video,
    );

    _attachOrientation();
  }

  void _attachOrientation() {
    _detachOrientation();
    _rollCtrl ??= StreamController<double?>.broadcast();
    void handler(web.Event e) {
      final oe = e as web.DeviceOrientationEvent;
      final gamma = oe.gamma;
      if (!(_rollCtrl?.isClosed ?? true)) {
        _rollCtrl?.add(gamma?.toDouble());
      }
    }

    _orientListener = handler.toJS;
    web.window.addEventListener('deviceorientation', _orientListener!);
  }

  void _detachOrientation() {
    if (_orientListener != null) {
      web.window.removeEventListener('deviceorientation', _orientListener!);
      _orientListener = null;
    }
  }

  @override
  Future<void> stop() async {
    _detachOrientation();
    final stream = _stream;
    if (stream != null) {
      final tracks = stream.getTracks().toDart;
      for (final t in tracks) {
        t.stop();
      }
    }
    _stream = null;
    _video?.srcObject = null;
    _video = null;
    _viewType = null;
  }

  @override
  Future<Uint8List?> captureJpeg({double quality = 0.92}) async {
    final video = _video;
    if (video == null) return null;
    final w = video.videoWidth;
    final h = video.videoHeight;
    if (w <= 0 || h <= 0) return null;

    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) return null;
    ctx.drawImage(video, 0, 0, w.toDouble(), h.toDouble());

    final completer = Completer<Uint8List?>();
    canvas.toBlob(
      ((web.Blob? blob) {
        if (blob == null) {
          completer.complete(null);
          return;
        }
        unawaited(() async {
          try {
            final ab = await blob.arrayBuffer().toDart;
            completer.complete(ab.toDart.asUint8List());
          } catch (e) {
            debugPrint('captureJpeg arrayBuffer failed: $e');
            completer.complete(null);
          }
        }());
      }).toJS,
      'image/jpeg',
      quality.toJS,
    );
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  }
}
