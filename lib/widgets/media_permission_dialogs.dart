import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media_permission_query.dart';
import '../theme/sori_tokens.dart';

const _kCameraGuideAlwaysKey = 'sori_media_camera_guide_always_v1';

/// 세션 내 미디어 사전 안내 수락 여부 (허용 후 재프롬프트 방지).
class MediaPermissionSession {
  MediaPermissionSession._();

  static bool guideAccepted = false;
  static bool? _prefsAlwaysAllow;

  /// SharedPreferences «항상 허용» — 앱 재시작 후에도 사전 안내 스킵.
  static Future<bool> isAlwaysAllowPersisted() async {
    if (_prefsAlwaysAllow != null) return _prefsAlwaysAllow!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefsAlwaysAllow = prefs.getBool(_kCameraGuideAlwaysKey) ?? false;
    } catch (_) {
      _prefsAlwaysAllow = false;
    }
    return _prefsAlwaysAllow!;
  }

  static Future<void> setAlwaysAllowPersisted(bool value) async {
    _prefsAlwaysAllow = value;
    guideAccepted = value || guideAccepted;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kCameraGuideAlwaysKey, value);
    } catch (_) {}
  }
}

/// 안내 다이얼로그 결과.
enum MediaPermissionGuideChoice {
  cancel,
  proceedOnce,
  alwaysAllow,
}

/// 1차: 시스템 권한 팝업 직전 사전 안내 (미허용·미안내 시에만).
Future<MediaPermissionGuideChoice> showMediaPermissionGuideDialog(
  BuildContext context,
) async {
  final result = await showDialog<MediaPermissionGuideChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: SoriTokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '카메라 및 사진첩 접근 안내',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 17,
          color: SoriTokens.textCharcoal,
        ),
      ),
      content: const Text(
        '고객님의 관리 전/후(B/A) 경과 비교 및 동의서 생성을 위해 '
        '사진첩 접근과 카메라 권한이 필요합니다.\n\n'
        '「항상 허용」을 선택하면 이 기기에서 사전 안내를 다시 묻지 않습니다.',
        style: TextStyle(
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: SoriTokens.textCharcoal,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, MediaPermissionGuideChoice.cancel),
                  style: TextButton.styleFrom(
                    backgroundColor: SoriTokens.chipIdleBg,
                    foregroundColor: SoriTokens.tabUnselected,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: SoriTokens.tabUnselected,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    MediaPermissionGuideChoice.proceedOnce,
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: SoriTokens.chipIdleBg,
                    foregroundColor: SoriTokens.tabUnselected,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '이번만',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: SoriTokens.tabUnselected,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    MediaPermissionGuideChoice.alwaysAllow,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                    foregroundColor: SoriTokens.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '항상 허용',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return result ?? MediaPermissionGuideChoice.cancel;
}

/// 2차: 권한 거부/차단 시 설정 가이드.
Future<void> showMediaPermissionDeniedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SoriTokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '접근 권한 필요',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 17,
          color: SoriTokens.textCharcoal,
        ),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사진 촬영 및 불러오기를 위해 카메라/사진첩 접근 권한이 필요합니다. '
            '기기 설정에서 권한을 허용해 주세요.',
            style: TextStyle(
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: SoriTokens.textCharcoal,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '[설정] > [브라우저(Safari/Chrome)] > [카메라 및 사진 접근 허용]',
            style: TextStyle(
              height: 1.4,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SoriTokens.tabUnselected,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          style: FilledButton.styleFrom(
            backgroundColor: SoriTokens.primary,
            foregroundColor: SoriTokens.onPrimary,
          ),
          child: const Text(
            '확인',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: SoriTokens.onPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

bool isMediaPermissionDeniedError(Object error) {
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    final message = '${error.message ?? ''} ${error.details ?? ''}'.toLowerCase();
    const codes = {
      'photo_access_denied',
      'camera_access_denied',
      'permission_denied',
      'permissiondenied',
      'access_denied',
      'unauthorized',
    };
    if (codes.contains(code)) return true;
    if (message.contains('permission') ||
        message.contains('denied') ||
        message.contains('not allowed') ||
        message.contains('권한')) {
      return true;
    }
  }
  final text = error.toString().toLowerCase();
  return text.contains('permission') ||
      text.contains('denied') ||
      text.contains('notallowederror') ||
      text.contains('not allowed');
}

Future<void> applyMediaPermissionGuideChoice(
  MediaPermissionGuideChoice choice,
) async {
  if (choice == MediaPermissionGuideChoice.alwaysAllow) {
    await MediaPermissionSession.setAlwaysAllowPersisted(true);
  } else if (choice == MediaPermissionGuideChoice.proceedOnce) {
    MediaPermissionSession.guideAccepted = true;
  }
}

/// 이미 허용되었거나 세션/영속 «항상 허용»이면 사전 다이얼로그를 건너뛴다.
Future<bool> shouldSkipMediaPermissionGuide(ImageSource source) async {
  if (MediaPermissionSession.guideAccepted) return true;
  if (await MediaPermissionSession.isAlwaysAllowPersisted()) {
    MediaPermissionSession.guideAccepted = true;
    return true;
  }

  // 웹 갤러리(파일 선택기)는 브라우저가 별도 권한 세션을 요구하지 않음.
  if (kIsWeb && source == ImageSource.gallery) return true;

  final state = await queryMediaPermissionState(source);
  if (state == MediaPermissionState.granted) {
    MediaPermissionSession.guideAccepted = true;
    // 브라우저가 이미 허용한 경우 앱 안내는 다시 안 띄움 + 영속화
    await MediaPermissionSession.setAlwaysAllowPersisted(true);
    return true;
  }
  return false;
}

/// 카메라 사전 안내 — Permissions API `granted` / 항상 허용이면 다이얼로그 없이 true.
Future<bool> ensureCameraPermissionGuide(BuildContext context) async {
  final skip = await shouldSkipMediaPermissionGuide(ImageSource.camera);
  if (skip) return true;
  if (!context.mounted) return false;
  final choice = await showMediaPermissionGuideDialog(context);
  if (choice == MediaPermissionGuideChoice.cancel) return false;
  await applyMediaPermissionGuideChoice(choice);
  return true;
}

/// 이미 허용되었거나 세션에서 안내를 수락했다면 사전 다이얼로그를 건너뛴다.
Future<bool> _shouldSkipPermissionGuide(ImageSource source) =>
    shouldSkipMediaPermissionGuide(source);

/// 사전 안내(필요 시만) → ImagePicker → 거부 시 2차 안내.
/// 권한을 앱에서 reset/revoke 하지 않으며, Granted면 즉시 피커를 연다.
Future<XFile?> pickImageWithPermissionGuards({
  required BuildContext context,
  required ImageSource source,
  double? maxWidth,
  int? imageQuality,
}) async {
  final skipGuide = await _shouldSkipPermissionGuide(source);
  if (!skipGuide) {
    if (!context.mounted) return null;
    final choice = await showMediaPermissionGuideDialog(context);
    if (choice == MediaPermissionGuideChoice.cancel) return null;
    await applyMediaPermissionGuideChoice(choice);
  }
  if (!context.mounted) return null;

  try {
    final picker = ImagePicker();
    return await picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
  } catch (e) {
    if (!context.mounted) return null;
    if (isMediaPermissionDeniedError(e)) {
      MediaPermissionSession.guideAccepted = false;
      await MediaPermissionSession.setAlwaysAllowPersisted(false);
      await showMediaPermissionDeniedDialog(context);
      return null;
    }
    rethrow;
  }
}

/// 갤러리에서 여러 장 선택 (최대 [limit], 기본 20).
Future<List<XFile>> pickMultiImagesWithPermissionGuards({
  required BuildContext context,
  int limit = 20,
  double? maxWidth,
  int? imageQuality,
}) async {
  final skipGuide = await _shouldSkipPermissionGuide(ImageSource.gallery);
  if (!skipGuide) {
    if (!context.mounted) return const [];
    final choice = await showMediaPermissionGuideDialog(context);
    if (choice == MediaPermissionGuideChoice.cancel) return const [];
    await applyMediaPermissionGuideChoice(choice);
  }
  if (!context.mounted) return const [];

  try {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
      limit: limit,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
    if (files.length > limit) {
      return files.take(limit).toList();
    }
    return files;
  } catch (e) {
    if (!context.mounted) return const [];
    if (isMediaPermissionDeniedError(e)) {
      MediaPermissionSession.guideAccepted = false;
      await MediaPermissionSession.setAlwaysAllowPersisted(false);
      await showMediaPermissionDeniedDialog(context);
      return const [];
    }
    rethrow;
  }
}
