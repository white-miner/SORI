import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/community_case_item.dart';
import '../models/customer_chart.dart';
import '../models/customer_review.dart';
import '../utils/case_persona.dart';
import '../utils/pii_mask.dart';

/// 작성자 본인 한정 인스타그램 퀵 게시 (캡션 복사 + B/A 이미지 공유).
abstract final class InstagramQuickPost {
  static bool canShare({
    required String? currentUserId,
    required String? authorId,
  }) {
    final uid = currentUserId?.trim() ?? '';
    final aid = authorId?.trim() ?? '';
    return uid.isNotEmpty && aid.isNotEmpty && uid == aid;
  }

  static String buildCaption({
    required CommunityCaseItem item,
    required CustomerChart chart,
    CustomerReview? review,
  }) {
    final care = chart.serviceMenuLabel;
    final meta = CasePersona.feedLine(
      chart: chart,
      age: item.customerAge ?? chart.age,
      genderLabel: item.customerGenderLabel ?? chart.gender,
    );
    final reviewText = PiiMask.customerNames(review?.displayText.trim() ?? '');
    final tags = item.displayCareTags
        .map((t) => t.trim().startsWith('#') ? t.trim() : '#${t.trim()}')
        .where((t) => t.length > 1)
        .toList();
    final shopName = item.shop.name.trim();

    return [
      if (shopName.isNotEmpty) shopName,
      care,
      if (meta.isNotEmpty) meta,
      if (reviewText.isNotEmpty) reviewText,
      if (tags.isNotEmpty) tags.join(' '),
    ].join('\n');
  }

  static Future<void> copyCaption(String caption) async {
    await Clipboard.setData(ClipboardData(text: caption));
  }

  static Future<void> shareCapturedImage(
    Uint8List bytes, {
    String fileName = 'sori-ba.png',
  }) async {
    if (bytes.isEmpty) return;
    if (kIsWeb) {
      await Share.shareXFiles([
        XFile.fromData(bytes, mimeType: 'image/png', name: fileName),
      ]);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    await XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: fileName,
    ).saveTo(path);
    await Share.shareXFiles([XFile(path, mimeType: 'image/png', name: fileName)]);
  }
}
