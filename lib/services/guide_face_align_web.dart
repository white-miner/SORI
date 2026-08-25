import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'guide_face_align.dart';

GuideFaceAlign createGuideFaceAlign() => WebGuideFaceAlign();

class WebGuideFaceAlign implements GuideFaceAlign {
  final _ctrl = StreamController<GuideFacePose>.broadcast();
  JSFunction? _jsCallback;
  bool _started = false;
  bool _prepared = false;
  GuideFacePose _last = GuideFacePose.none;
  static Future<void>? _scriptLoad;

  @override
  Stream<GuideFacePose> get poses => _ctrl.stream;

  JSObject? get _api {
    final v = globalContext.getProperty('SoriFaceAlign'.toJS);
    if (v == null || v.isUndefinedOrNull) return null;
    return v as JSObject;
  }

  Future<void> _ensureScript() async {
    if (_api != null) return;
    _scriptLoad ??= () async {
      final existing = web.document.querySelector('script[data-sori-face-align]');
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
            'sori_face_align.js?v=${const String.fromEnvironment('SORI_ASSET_V', defaultValue: '2026082515')}'
        ..async = true
        ..setAttribute('data-sori-face-align', '1');
      script.onload = ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      script.onerror = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('sori_face_align.js load failed'));
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
      debugPrint('SoriFaceAlign JS not loaded');
      return;
    }
    try {
      final init = api.callMethod('init'.toJS);
      if (init != null) {
        await (init as JSPromise<JSAny?>).toDart;
      }
      _prepared = true;
    } catch (e) {
      debugPrint('SoriFaceAlign.prepare failed: $e');
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
      debugPrint('SoriFaceAlign JS not loaded');
      return;
    }
    if (videoElement is! JSAny) {
      debugPrint('GuideFaceAlign: expected HTMLVideoElement');
      return;
    }
    final video = videoElement as web.HTMLVideoElement;

    _jsCallback = ((JSAny? raw) {
      final pose = _parsePose(raw);
      if (!_shouldEmit(pose)) return;
      _last = pose;
      if (!_ctrl.isClosed) _ctrl.add(pose);
    }).toJS;

    try {
      api.callMethod('start'.toJS, video, _jsCallback);
      _started = true;
    } catch (e) {
      debugPrint('SoriFaceAlign.start failed: $e');
      _started = false;
    }
  }

  bool _shouldEmit(GuideFacePose next) {
    if (next.detected != _last.detected) return true;
    if (next.inCircle != _last.inCircle) return true;
    if (!next.detected) return false;
    if ((next.pitch - _last.pitch).abs() >= 0.8) return true;
    if ((next.yaw - _last.yaw).abs() >= 0.8) return true;
    if ((next.roll - _last.roll).abs() >= 0.8) return true;
    if (next.isAligned != _last.isAligned) return true;
    return false;
  }

  GuideFacePose _parsePose(JSAny? raw) {
    if (raw == null || raw.isUndefinedOrNull || !raw.isA<JSObject>()) {
      return GuideFacePose.none;
    }
    final o = raw as JSObject;
    final detected = _bool(o.getProperty('detected'.toJS)) ?? false;
    final inCircle = _bool(o.getProperty('inCircle'.toJS)) ?? false;
    final pitch = _num(o.getProperty('pitch'.toJS)) ?? 0;
    final yaw = _num(o.getProperty('yaw'.toJS)) ?? 0;
    final roll = _num(o.getProperty('roll'.toJS)) ?? 0;
    return GuideFacePose(
      detected: detected,
      inCircle: inCircle,
      pitch: pitch,
      yaw: yaw,
      roll: roll,
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

  @override
  Future<void> stop() async {
    if (!_started && _jsCallback == null) return;
    try {
      _api?.callMethod('stop'.toJS);
    } catch (_) {}
    _jsCallback = null;
    _started = false;
    _last = GuideFacePose.none;
  }

  @override
  void dispose() {
    unawaited(stop());
    unawaited(_ctrl.close());
  }
}
