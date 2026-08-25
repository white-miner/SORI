/**
 * SORI Smart Guide Camera — MediaPipe FaceLandmarker bridge.
 * Inference is throttled inside requestAnimationFrame (~11fps) so Flutter UI stays responsive.
 */
(function () {
  'use strict';

  var landmarker = null;
  var initPromise = null;
  var rafId = 0;
  var running = false;
  var lastVideoTime = -1;
  var lastInferMs = 0;
  var INTERVAL_MS = 90;
  var videoEl = null;
  var onPose = null;

  function matrixData(m) {
    if (!m) return null;
    if (m.data) return m.data;
    if (typeof m.length === 'number') return m;
    return null;
  }

  /** Column-major 4x4 → pitch/yaw/roll (degrees). */
  function eulerFromMatrix(data) {
    if (!data || data.length < 16) return null;
    var r00 = data[0], r01 = data[4], r02 = data[8];
    var r10 = data[1], r11 = data[5], r12 = data[9];
    var r20 = data[2], r21 = data[6], r22 = data[10];
    var pitch = Math.asin(Math.max(-1, Math.min(1, -r12))) * (180 / Math.PI);
    var yaw = Math.atan2(r02, r22) * (180 / Math.PI);
    var roll = Math.atan2(r10, r11) * (180 / Math.PI);
    return { pitch: pitch, yaw: yaw, roll: roll };
  }

  function poseFromLandmarks(lms) {
    if (!lms || lms.length < 300) return null;
    var leftEye = lms[33];
    var rightEye = lms[263];
    var nose = lms[1];
    var chin = lms[152];
    var forehead = lms[10];
    if (!leftEye || !rightEye || !nose || !chin || !forehead) return null;

    var iod = Math.hypot(rightEye.x - leftEye.x, rightEye.y - leftEye.y) || 1e-6;
    var midEyeX = (leftEye.x + rightEye.x) / 2;
    var midEyeY = (leftEye.y + rightEye.y) / 2;
    var roll = Math.atan2(rightEye.y - leftEye.y, rightEye.x - leftEye.x) * (180 / Math.PI);
    var yaw = ((nose.x - midEyeX) / iod) * 48;
    var faceH = Math.hypot(chin.x - forehead.x, chin.y - forehead.y) || 1e-6;
    var midFaceY = (forehead.y + chin.y) / 2;
    var pitch = ((nose.y - midFaceY) / faceH) * 70;
    return { pitch: pitch, yaw: yaw, roll: roll };
  }

  function emit(pose) {
    if (typeof onPose !== 'function') return;
    try {
      onPose(pose);
    } catch (_) {}
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
      emit({ detected: false, pitch: 0, yaw: 0, roll: 0, error: String(e) });
      return;
    }

    var faces = (result && result.faceLandmarks) || [];
    if (!faces.length) {
      emit({ detected: false, pitch: 0, yaw: 0, roll: 0 });
      return;
    }

    var euler = null;
    var mats = result.facialTransformationMatrixes;
    if (mats && mats.length) {
      euler = eulerFromMatrix(matrixData(mats[0]));
    }
    if (!euler) {
      euler = poseFromLandmarks(faces[0]);
    }
    if (!euler) {
      emit({ detected: false, pitch: 0, yaw: 0, roll: 0 });
      return;
    }

    emit({
      detected: true,
      pitch: euler.pitch,
      yaw: euler.yaw,
      roll: euler.roll,
    });
  }

  async function ensureInit() {
    if (landmarker) return;
    if (initPromise) return initPromise;
    initPromise = (async function () {
      var vision = await import(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/+esm'
      );
      var FaceLandmarker = vision.FaceLandmarker;
      var FilesetResolver = vision.FilesetResolver;
      var fileset = await FilesetResolver.forVisionTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm'
      );
      try {
        landmarker = await FaceLandmarker.createFromOptions(fileset, {
          baseOptions: {
            modelAssetPath:
              'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task',
            delegate: 'GPU',
          },
          runningMode: 'VIDEO',
          numFaces: 1,
          outputFacialTransformationMatrixes: true,
        });
      } catch (gpuErr) {
        console.warn('[SoriFaceAlign] GPU failed, fallback WASM', gpuErr);
        landmarker = await FaceLandmarker.createFromOptions(fileset, {
          baseOptions: {
            modelAssetPath:
              'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task',
            delegate: 'CPU',
          },
          runningMode: 'VIDEO',
          numFaces: 1,
          outputFacialTransformationMatrixes: true,
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

  window.SoriFaceAlign = {
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
