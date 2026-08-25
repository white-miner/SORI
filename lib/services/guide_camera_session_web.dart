import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'guide_camera_session.dart';

GuideCameraSession createGuideCameraSession() => WebGuideCameraSession();

/// 미리보기 스트림 목표 해상도 (UI 부담 ↓). 캡처는 동일 스트림 + 중앙 크롭.
const int _kPreviewIdealWidth = 1280;
const int _kPreviewIdealHeight = 960;

class WebGuideCameraSession implements GuideCameraSession {
  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;
  web.MediaStreamTrack? _videoTrack;
  String? _viewType;
  bool _mirrored = false;
  double _zoomFactor = 1.7;
  bool _usingHardwareZoom = false;
  StreamController<double?>? _rollCtrl;
  web.EventListener? _orientListener;
  DateTime? _lastRollEmit;

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
  double get zoomFactor => _zoomFactor;

  @override
  bool get usingHardwareZoom => _usingHardwareZoom;

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
  Future<void> start({required bool front, double zoom = 1.7}) async {
    await stop();
    _mirrored = front;
    _zoomFactor = zoom.clamp(1.0, 3.0);
    _usingHardwareZoom = false;

    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.setProperty('transform-origin', 'center center')
      // 플랫폼 뷰가 컨트롤 영역까지 터치를 가로채는 문제 방지
      ..style.pointerEvents = 'none';

    web.MediaStream stream;
    try {
      final constraints = {
        'audio': false,
        'video': {
          'facingMode': {'ideal': front ? 'user' : 'environment'},
          'width': {'ideal': _kPreviewIdealWidth, 'max': 1920},
          'height': {'ideal': _kPreviewIdealHeight, 'max': 1440},
          'frameRate': {'ideal': 24, 'max': 30},
        },
      }.jsify()! as web.MediaStreamConstraints;
      stream =
          await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
    } catch (e) {
      debugPrint('getUserMedia facingMode failed, retry soft: $e');
      final soft = {
        'audio': false,
        'video': {
          'width': {'ideal': _kPreviewIdealWidth},
          'height': {'ideal': _kPreviewIdealHeight},
        },
      }.jsify()! as web.MediaStreamConstraints;
      stream =
          await web.window.navigator.mediaDevices.getUserMedia(soft).toDart;
    }

    _stream = stream;
    final tracks = stream.getVideoTracks().toDart;
    _videoTrack = tracks.isNotEmpty ? tracks.first : null;

    video.srcObject = stream;
    await video.play().toDart;

    _video = video;
    await _applyZoom(_zoomFactor);

    _viewType =
        'sori-guide-cam-${DateTime.now().microsecondsSinceEpoch}-${front ? 'f' : 'b'}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType!,
      (int viewId) => video,
    );

    _attachOrientation();
  }

  @override
  Future<void> setZoom(double zoom) async {
    _zoomFactor = zoom.clamp(1.0, 3.0);
    if (_video == null) return;
    await _applyZoom(_zoomFactor);
  }

  Future<void> _applyZoom(double zoom) async {
    final video = _video;
    if (video == null) return;

    var hwOk = false;
    final track = _videoTrack;
    if (track != null) {
      hwOk = await _tryHardwareZoom(track, zoom);
    }
    _usingHardwareZoom = hwOk;

    // HW 줌 성공 시 디지털 배율은 1. HW 실패 시 CSS scale로 디지털 줌.
    final digital = hwOk ? 1.0 : zoom;
    final parts = <String>[];
    if (_mirrored) parts.add('scaleX(-1)');
    if (digital > 1.01) parts.add('scale(${digital.toStringAsFixed(3)})');
    video.style.transform = parts.isEmpty ? 'none' : parts.join(' ');
  }

  Future<bool> _tryHardwareZoom(web.MediaStreamTrack track, double zoom) async {
    try {
      final capsAny = track.getCapabilities() as JSObject?;
      if (capsAny == null) return false;
      final zoomCap = capsAny.getProperty('zoom'.toJS);
      if (zoomCap == null || zoomCap.isUndefinedOrNull) return false;

      double? minZ;
      double? maxZ;
      if (zoomCap.isA<JSObject>()) {
        final zObj = zoomCap as JSObject;
        minZ = _jsNum(zObj.getProperty('min'.toJS));
        maxZ = _jsNum(zObj.getProperty('max'.toJS));
      }
      if (minZ == null || maxZ == null || maxZ <= minZ) return false;

      final target = zoom.clamp(minZ, maxZ);
      final constraints = {
        'advanced': [
          {'zoom': target},
        ],
      }.jsify()! as web.MediaTrackConstraints;
      await track.applyConstraints(constraints).toDart;
      return true;
    } catch (e) {
      debugPrint('hardware zoom unavailable: $e');
      return false;
    }
  }

  double? _jsNum(JSAny? v) {
    if (v == null || v.isUndefinedOrNull) return null;
    if (v.isA<JSNumber>()) return (v as JSNumber).toDartDouble;
    return null;
  }

  void _attachOrientation() {
    _detachOrientation();
    _rollCtrl ??= StreamController<double?>.broadcast();
    void handler(web.Event e) {
      final oe = e as web.DeviceOrientationEvent;
      final gamma = oe.gamma?.toDouble();
      // ~10Hz + 미세 변화 무시 → UI setState 폭주 방지
      final now = DateTime.now();
      if (_lastRollEmit != null &&
          now.difference(_lastRollEmit!) < const Duration(milliseconds: 100)) {
        return;
      }
      _lastRollEmit = now;
      if (!(_rollCtrl?.isClosed ?? true)) {
        _rollCtrl?.add(gamma);
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
    _videoTrack = null;
    _video?.srcObject = null;
    _video = null;
    _viewType = null;
    _usingHardwareZoom = false;
  }

  @override
  Future<Uint8List?> captureJpeg({double quality = 0.92}) async {
    final video = _video;
    if (video == null) return null;
    final w = video.videoWidth;
    final h = video.videoHeight;
    if (w <= 0 || h <= 0) return null;

    // 디지털 줌이면 중앙 crop. HW 줌이면 이미 센서 화각이 좁혀진 상태.
    final zoom =
        (!_usingHardwareZoom && _zoomFactor > 1.01) ? _zoomFactor : 1.0;
    final cropW = w / zoom;
    final cropH = h / zoom;
    final sx = (w - cropW) / 2;
    final sy = (h - cropH) / 2;

    // 출력은 고정 3:4로 레터/필 크롭해 저장 비율 통일
    final out = _fitOutputSize(cropW, cropH);
    final canvas = web.HTMLCanvasElement()
      ..width = out.$1
      ..height = out.$2;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) return null;

    final srcAspect = cropW / cropH;
    const dstAspect = kGuideCameraAspectRatio;
    double drawSx = sx, drawSy = sy, drawSw = cropW, drawSh = cropH;
    if (srcAspect > dstAspect) {
      // 너무 가로로 넓음 → 좌우 크롭
      drawSw = cropH * dstAspect;
      drawSx = sx + (cropW - drawSw) / 2;
    } else if (srcAspect < dstAspect) {
      drawSh = cropW / dstAspect;
      drawSy = sy + (cropH - drawSh) / 2;
    }

    ctx.drawImage(
      video,
      drawSx,
      drawSy,
      drawSw,
      drawSh,
      0,
      0,
      out.$1.toDouble(),
      out.$2.toDouble(),
    );

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

  /// 캡처 캔버스 크기 — 긴 변 기준 최대 1600, 비율 3:4.
  (int, int) _fitOutputSize(double cropW, double cropH) {
    const maxLong = 1600.0;
    final portrait = kGuideCameraAspectRatio; // w/h = 3/4
    var outH = math.min(maxLong, math.max(cropH, cropW / portrait));
    var outW = outH * portrait;
    if (outW > maxLong) {
      outW = maxLong;
      outH = outW / portrait;
    }
    return (outW.round().clamp(480, 2400), outH.round().clamp(640, 3200));
  }
}
