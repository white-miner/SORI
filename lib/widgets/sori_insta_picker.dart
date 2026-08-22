import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import '../views/custom_insta_picker_page.dart';
import 'media_permission_dialogs.dart';

/// 인스타 스타일 인앱 피커를 열고 크롭된 JPEG 바이트 목록을 반환한다.
Future<List<Uint8List>> openSoriInstaPicker(
  BuildContext context, {
  int maxAssets = 20,
  String title = '새 게시물',
}) async {
  final skipGuide = MediaPermissionSession.guideAccepted;
  if (!skipGuide) {
    final proceed = await showMediaPermissionGuideDialog(context);
    if (!proceed) return const [];
    MediaPermissionSession.guideAccepted = true;
  }
  if (!context.mounted) return const [];

  final result = await Navigator.of(context, rootNavigator: true)
      .push<List<Uint8List>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CustomInstaPickerPage(
        maxAssets: maxAssets.clamp(1, 20),
        title: title,
      ),
    ),
  );
  return result ?? const [];
}

/// 피커 진행 중 안내 스낵 (웹 폴백 등).
void showSoriPickerSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: SoriTokens.primary,
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + kSoriFloatingNavClearance),
    ),
  );
}
