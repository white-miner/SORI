import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// 1차: 시스템 권한 팝업 직전 사전 안내.
Future<bool> showMediaPermissionGuideDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '카메라 및 사진첩 접근 안내',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: const Text(
        '고객님의 관리 전/후(B/A) 경과 비교 및 동의서 생성을 위해 '
        '사진첩 접근과 카메라 권한이 필요합니다.',
        style: TextStyle(height: 1.45, fontWeight: FontWeight.w500),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF111827),
            foregroundColor: Colors.white,
          ),
          child: const Text('확인 및 진행'),
        ),
      ],
    ),
  );
  return result == true;
}

/// 2차: 권한 거부/차단 시 설정 가이드.
Future<void> showMediaPermissionDeniedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '접근 권한 필요',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사진 촬영 및 불러오기를 위해 카메라/사진첩 접근 권한이 필요합니다. '
            '기기 설정에서 권한을 허용해 주세요.',
            style: TextStyle(height: 1.45, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 12),
          Text(
            '[설정] > [브라우저(Safari/Chrome)] > [카메라 및 사진 접근 허용]',
            style: TextStyle(
              height: 1.4,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF111827),
            foregroundColor: Colors.white,
          ),
          child: const Text('확인'),
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

/// 사전 안내 → ImagePicker → 거부 시 2차 안내.
Future<XFile?> pickImageWithPermissionGuards({
  required BuildContext context,
  required ImageSource source,
  double? maxWidth,
  int? imageQuality,
}) async {
  final proceed = await showMediaPermissionGuideDialog(context);
  if (!proceed) return null;
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
      await showMediaPermissionDeniedDialog(context);
      return null;
    }
    rethrow;
  }
}
