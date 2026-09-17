import 'package:flutter/material.dart';

import '../../services/sori_store.dart';
import '../../utils/sori_nav.dart';
import '../../views/director_fandom_profile_page.dart';

/// Phase 5.1 — 공개 프로필 미리보기 단일 진입 (featured/CTA 로직 비수정).
Future<void> openShopPublicPreview(
  BuildContext context,
  SoriStore store, {
  required bool isOwner,
}) {
  return pushRootPage<void>(
    context,
    DirectorFandomProfilePage(
      store: store,
      isOwner: isOwner,
    ),
  );
}
