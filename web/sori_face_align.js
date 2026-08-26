/**
 * SORI Smart Guide Camera — MediaPipe FaceLandmarker bridge.
 * Alignment requires: (1) frontal pose AND (2) face landmarks inside the circular guide.
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

  // Must match Flutter _CircularFaceAlignPainter (3:4 frame).
  var GUIDE_CX = 0.5;
  var GUIDE_CY = 0.46;
  var GUIDE_R = 0.34; // slightly tighter than painted 0.36
  var FRAME_ASPECT = 3 / 4; // w/h
  var INV_ASPECT = 4 / 3; // h/w for circular metric in normalized coords

  function matrixData(m) {
    if (!m) return null;
    if (m.data) return m.data;
    if (typeof m.length === 'number') return m;
    return null;
  }

  function eulerFromMatrix(data) {
    if (!data || data.length < 16) return null;
    var r02 = data[8];
    var r10 = data[1], r11 = data[5], r12 = data[9];
    var r22 = data[10];
    var pitch = Math.asin(Math.max(-1, Math.min(1, -r12))) * (180 / Math.PI);
    var yaw = Math.atan2(r02, r22) * (180 / Math.PI);
    var roll = Math.atan2(r10, r11) * (180 / Math.PI);
    return { pitch: pitch, yaw: yaw, roll: roll };
  }

  function faceCenterFromLandmarks(lms) {
    if (!lms || lms.length < 300) return null;
    var leftEye = lms[33];
    var rightEye = lms[263];
    var nose = lms[1];
    var chin = lms[152];
    var forehead = lms[10];
    if (!leftEye || !rightEye || !nose || !chin || !forehead) return null;
    var cx = (leftEye.x + rightEye.x + nose.x) / 3;
    var cy = (leftEye.y + rightEye.y + nose.y) / 3;
    var iod = Math.hypot(rightEye.x - leftEye.x, rightEye.y - leftEye.y) || 1e-6;
    var faceH =
      Math.hypot(chin.x - forehead.x, chin.y - forehead.y) || iod * 2;
    var radius = Math.max(iod * 1.05, faceH * 0.42);
    return { centerX: cx, centerY: cy, faceRadius: radius };
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
    var roll = Math.atan2(rightEye.y - leftEye.y, rightEye.x - leftEye.x) * (180 / Math.PI);
    var yaw = ((nose.x - midEyeX) / iod) * 48;
    var faceH = Math.hypot(chin.x - forehead.x, chin.y - forehead.y) || 1e-6;
    var midFaceY = (forehead.y + chin.y) / 2;
    var pitch = ((nose.y - midFaceY) / faceH) * 70;
    return { pitch: pitch, yaw: yaw, roll: roll };
  }

  /** Point inside painted circle (square metric in pixel space of 3:4 view). */
  function pointInGuide(x, y) {
    var dx = x - GUIDE_CX;
    var dy = (y - GUIDE_CY) * INV_ASPECT;
    return dx * dx + dy * dy <= GUIDE_R * GUIDE_R;
  }

  /**
   * Key landmarks + face bbox must sit fully inside the circle.
   * Indices: forehead 10, nose 1, chin 152, L/R eye 33/263, L/R cheek 234/454, jaw 172/397
   */
  function faceInsideGuide(lms) {
    if (!lms || lms.length < 400) return false;
    var keys = [10, 1, 152, 33, 263, 234, 454, 172, 397, 61, 291];
    var i;
    for (i = 0; i < keys.length; i++) {
      var p = lms[keys[i]];
      if (!p || !pointInGuide(p.x, p.y)) return false;
    }
    // Bounding box of sampled face outline must also fit
    var minX = 1,
      maxX = 0,
      minY = 1,
      maxY = 0;
    for (i = 0; i < keys.length; i++) {
      var q = lms[keys[i]];
      if (q.x < minX) minX = q.x;
      if (q.x > maxX) maxX = q.x;
      if (q.y < minY) minY = q.y;
      if (q.y > maxY) maxY = q.y;
    }
    // Corners of bbox must be inside (strict containment)
    if (!pointInGuide(minX, minY)) return false;
    if (!pointInGuide(maxX, minY)) return false;
    if (!pointInGuide(minX, maxY)) return false;
    if (!pointInGuide(maxX, maxY)) return false;
    // Face must be large enough inside circle (reject tiny distant faces)
    var bw = maxX - minX;
    var bh = maxY - minY;
    if (bw < 0.18 || bh < 0.22) return false;
    if (bw > GUIDE_R * 2.05 || bh > GUIDE_R * 2.4) return false;
    return true;
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
      emit({
        detected: false,
        inCircle: false,
        pitch: 0,
        yaw: 0,
        roll: 0,
        centerX: 0.5,
        centerY: 0.5,
        faceRadius: 0,
        error: String(e),
      });
      return;
    }

    var faces = (result && result.faceLandmarks) || [];
    if (!faces.length) {
      emit({
        detected: false,
        inCircle: false,
        pitch: 0,
        yaw: 0,
        roll: 0,
        centerX: 0.5,
        centerY: 0.5,
        faceRadius: 0,
      });
      return;
    }

    var lms = faces[0];
    var euler = null;
    var mats = result.facialTransformationMatrixes;
    if (mats && mats.length) {
      euler = eulerFromMatrix(matrixData(mats[0]));
    }
    if (!euler) {
      euler = poseFromLandmarks(lms);
    }
    if (!euler) {
      emit({
        detected: false,
        inCircle: false,
        pitch: 0,
        yaw: 0,
        roll: 0,
        centerX: 0.5,
        centerY: 0.5,
        faceRadius: 0,
      });
      return;
    }

    var inCircle = faceInsideGuide(lms);
    var center = faceCenterFromLandmarks(lms);
    emit({
      detected: true,
      inCircle: inCircle,
      pitch: euler.pitch,
      yaw: euler.yaw,
      roll: euler.roll,
      centerX: center ? center.centerX : 0.5,
      centerY: center ? center.centerY : 0.5,
      faceRadius: center ? center.faceRadius : 0.18,
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
