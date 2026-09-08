import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'guide_body_align.dart';

GuideBodyAlign createGuideBodyAlign() => WebGuideBodyAlign();

class WebGuideBodyAlign implements GuideBodyAlign {
  final _ctrl = StreamController<GuideBodyPose>.broadcast();
  JSFunction? _jsCallback;
  bool _started = false;
  bool _prepared = false;
  static Future<void>? _scriptLoad;

  @override
  Stream<GuideBodyPose> get poses => _ctrl.stream;

  JSObject? get _api {
    final v = globalContext.getProperty('SoriBodyAlign'.toJS);
    if (v == null || v.isUndefinedOrNull) return null;
    return v as JSObject;
  }

  Future<void> _ensureScript() async {
    if (_api != null) return;
    _scriptLoad ??= () async {
      final existing =
          web.document.querySelector('script[data-sori-body-align]');
      if (existing != null) {
        // 다른 인스턴스가 로딩 중일 수 있음 — API 노출까지 폴링
        for (var i = 0; i < 40; i++) {
          if (_api != null) return;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        return;
      }
      final completer = Completer<void>();
      final script = web.HTMLScriptElement()
        ..src =
            'sori_body_align.js?v=${const String.fromEnvironment('SORI_ASSET_V', defaultValue: '2026082614')}'
        ..async = true
        ..setAttribute('data-sori-body-align', '1');
      script.onload = ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      script.onerror = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('sori_body_align.js load failed'));
        }
      }).toJS;
      web.document.head?.append(script);
      await completer.future.timeout(const Duration(seconds: 15));
    }();
    await _scriptLoad;
  }

  @override
  Future<void> prepare() async {
    if (_prepared) return;
    await _ensureScript();
    final api = _api;
    if (api == null) {
      debugPrint('SoriBodyAlign JS not loaded');
      return;
    }
    try {
      final init = api.callMethod('init'.toJS);
      if (init != null) {
        await (init as JSPromise<JSAny?>).toDart;
      }
      _prepared = true;
    } catch (e) {
      debugPrint('SoriBodyAlign.prepare failed: $e');
      _prepared = false;
      rethrow;
    }
  }

  @override
  Future<void> start(Object videoElement) async {
    await stop();
    await prepare();
    final api = _api;
    if (api == null) {
      debugPrint('SoriBodyAlign JS not loaded');
      return;
    }
    final web.HTMLVideoElement video;
    try {
      video = videoElement as web.HTMLVideoElement;
    } catch (_) {
      debugPrint('GuideBodyAlign: expected HTMLVideoElement');
      return;
    }

    // 프로토타입 단계는 흔들림을 그대로 봐야 하므로 변화량 필터를 걸지 않는다.
    _jsCallback = ((JSAny? raw) {
      final pose = _parsePose(raw);
      if (!_ctrl.isClosed) _ctrl.add(pose);
    }).toJS;

    try {
      api.callMethod('start'.toJS, video, _jsCallback);
      _started = true;
    } catch (e) {
      debugPrint('SoriBodyAlign.start failed: $e');
      _started = false;
    }
  }

  GuideBodyPose _parsePose(JSAny? raw) {
    if (raw == null || raw.isUndefinedOrNull || !raw.isA<JSObject>()) {
      return GuideBodyPose.none;
    }
    final o = raw as JSObject;
    final detected = _bool(o.getProperty('detected'.toJS)) ?? false;
    final error = _string(o.getProperty('error'.toJS));
    final rawPoints = o.getProperty('points'.toJS);
    final points = rawPoints != null &&
            !rawPoints.isUndefinedOrNull &&
            rawPoints.isA<JSObject>()
        ? rawPoints as JSObject
        : null;
    if (!detected || points == null) {
      return GuideBodyPose(detected: false, error: error);
    }
    return GuideBodyPose(
      detected: true,
      leftShoulder: _landmark(points, 'leftShoulder'),
      rightShoulder: _landmark(points, 'rightShoulder'),
      leftHip: _landmark(points, 'leftHip'),
      rightHip: _landmark(points, 'rightHip'),
      leftKnee: _landmark(points, 'leftKnee'),
      rightKnee: _landmark(points, 'rightKnee'),
      leftAnkle: _landmark(points, 'leftAnkle'),
      rightAnkle: _landmark(points, 'rightAnkle'),
      error: error,
    );
  }

  GuideBodyLandmark? _landmark(JSObject points, String name) {
    final v = points.getProperty(name.toJS);
    if (v == null || v.isUndefinedOrNull || !v.isA<JSObject>()) return null;
    final o = v as JSObject;
    final x = _num(o.getProperty('x'.toJS));
    final y = _num(o.getProperty('y'.toJS));
    if (x == null || y == null) return null;
    return GuideBodyLandmark(
      x: x,
      y: y,
      visibility: _num(o.getProperty('v'.toJS)) ?? 1,
    );
  }

  double? _num(JSAny? v) {
    if (v == null || v.isUndefinedOrNull) return null;
    if (v.isA<JSNumber>()) return (v as JSNumber).toDartDouble;
    return null;
  }

  bool? _bool(JSAny? v) {
    if (v == null || v.isUndefinedOrNull) return null;
    if (v.isA<JSBoolean>()) return (v as JSBoolean).toDart;
    return null;
  }

  String? _string(JSAny? v) {
    if (v == null || v.isUndefinedOrNull) return null;
    if (v.isA<JSString>()) return (v as JSString).toDart;
    return null;
  }

  @override
  Future<void> stop() async {
    if (!_started && _jsCallback == null) return;
    try {
      _api?.callMethod('stop'.toJS);
    } catch (_) {}
    _jsCallback = null;
    _started = false;
  }

  @override
  void dispose() {
    unawaited(stop());
    unawaited(_ctrl.close());
  }
}
