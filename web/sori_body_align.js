/**
 * SORI Smart Guide Camera — MediaPipe PoseLandmarker bridge.
 * 얼굴 브릿지(sori_face_align.js)와 완전히 별개다. 복부/하체/전신 프리셋을
 * 고를 때만 로드된다 — 얼굴만 찍는 동안에는 이 모델을 받지 않는다.
 */
(function () {
  'use strict';

  var landmarker = null;
  var initPromise = null;
  var rafId = 0;
  var running = false;
  var lastVideoTime = -1;
  var lastInferMs = 0;
  // 전신은 얼굴보다 느슨해도 된다 — 프레임당 연산이 무거워 간격을 넓게 잡는다.
  var INTERVAL_MS = 110;
  var videoEl = null;
  var onPose = null;

  // MediaPipe Pose 33포인트 중 이 앱이 쓰는 지점.
  var KEYS = {
    leftShoulder: 11,
    rightShoulder: 12,
    leftHip: 23,
    rightHip: 24,
    leftKnee: 25,
    rightKnee: 26,
    leftAnkle: 27,
    rightAnkle: 28,
  };

  function pick(lms, index) {
    var p = lms[index];
    if (!p) return null;
    return {
      x: p.x,
      y: p.y,
      v: typeof p.visibility === 'number' ? p.visibility : 1,
    };
  }

  function pointsFrom(lms) {
    var out = {};
    var name;
    for (name in KEYS) {
      if (!Object.prototype.hasOwnProperty.call(KEYS, name)) continue;
      var p = pick(lms, KEYS[name]);
      if (p) out[name] = p;
    }
    return out;
  }

  function emit(pose) {
    if (typeof onPose !== 'function') return;
    try {
      onPose(pose);
    } catch (_) {}
  }

  function emitNone(error) {
    emit({ detected: false, points: {}, error: error || null });
  }

  function loop(ts) {
    if (!running) return;
    rafId = requestAnimationFrame(loop);
    if (!landmarker || !videoEl) return;
    if (videoEl.readyState < 2) return;
    if (ts - lastInferMs < INTERVAL_MS) return;
    if (videoEl.currentTime === lastVideoTime) return;
    lastVideoTime = videoEl.currentTime;
    lastInferMs = ts;

    var result;
    try {
      result = landmarker.detectForVideo(videoEl, ts);
    } catch (e) {
      emitNone(String(e));
      return;
    }

    var poses = (result && result.landmarks) || [];
    if (!poses.length) {
      emitNone(null);
      return;
    }

    emit({ detected: true, points: pointsFrom(poses[0]), error: null });
  }

  async function ensureInit() {
    if (landmarker) return;
    if (initPromise) return initPromise;
    initPromise = (async function () {
      var vision = await import(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/+esm'
      );
      var PoseLandmarker = vision.PoseLandmarker;
      var FilesetResolver = vision.FilesetResolver;
      var fileset = await FilesetResolver.forVisionTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm'
      );
      var modelPath =
        'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task';
      try {
        landmarker = await PoseLandmarker.createFromOptions(fileset, {
          baseOptions: { modelAssetPath: modelPath, delegate: 'GPU' },
          runningMode: 'VIDEO',
          numPoses: 1,
        });
      } catch (gpuErr) {
        console.warn('[SoriBodyAlign] GPU failed, fallback WASM', gpuErr);
        landmarker = await PoseLandmarker.createFromOptions(fileset, {
          baseOptions: { modelAssetPath: modelPath, delegate: 'CPU' },
          runningMode: 'VIDEO',
          numPoses: 1,
        });
      }
    })();
    try {
      await initPromise;
    } catch (e) {
      initPromise = null;
      throw e;
    }
  }

  window.SoriBodyAlign = {
    init: function () {
      return ensureInit();
    },
    start: function (video, callback) {
      videoEl = video;
      onPose = callback;
      running = true;
      lastVideoTime = -1;
      lastInferMs = 0;
      if (rafId) cancelAnimationFrame(rafId);
      rafId = requestAnimationFrame(loop);
    },
    stop: function () {
      running = false;
      onPose = null;
      videoEl = null;
      if (rafId) {
        cancelAnimationFrame(rafId);
        rafId = 0;
      }
    },
    isReady: function () {
      return !!landmarker;
    },
  };
})();
