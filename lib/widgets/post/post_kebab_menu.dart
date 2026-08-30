import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/sori_store.dart';
import '../../theme/sori_tokens.dart';
import '../../utils/post_author.dart';
import '../../utils/sori_bottom_sheet.dart';
import '../../views/post_first_creation_page.dart';
import '../glass/sori_glass_overlay.dart';
import 'post_view_data.dart';

enum PostKebabAction {
  edit,
  delete,
  share,
  hide,
  block,
  report,
}

class PostKebabMenuItem {
  const PostKebabMenuItem({
    required this.action,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final PostKebabAction action;
  final IconData icon;
  final String label;
  final bool destructive;
}

/// GIS kebab — glass bottom sheet (mobile) or anchored dropdown (desktop).
Future<void> showPostKebabMenu(
  BuildContext context, {
  required PostViewData data,
  required SoriStore store,
  Rect? anchor,
}) async {
  final isAuthor = PostAuthor.isAuthor(data, store);
  final items = isAuthor ? _authorItems() : _viewerItems();
  final wide = MediaQuery.sizeOf(context).width >= 800 && anchor != null;

  final action = wide
      ? await _showGlassDropdown(context, items: items, anchor: anchor)
      : await _showGlassBottomSheet(context, items: items);

  if (!context.mounted || action == null) return;
  await _handlePostKebabAction(
    context,
    action: action,
    data: data,
    store: store,
  );
}

List<PostKebabMenuItem> _authorItems() => const [
      PostKebabMenuItem(
        action: PostKebabAction.edit,
        icon: Icons.edit_outlined,
        label: '수정하기',
      ),
      PostKebabMenuItem(
        action: PostKebabAction.delete,
        icon: Icons.delete_outline_rounded,
        label: '삭제하기',
        destructive: true,
      ),
      PostKebabMenuItem(
        action: PostKebabAction.share,
        icon: Icons.link_rounded,
        label: '링크 복사 / 공유하기',
      ),
    ];

List<PostKebabMenuItem> _viewerItems() => const [
      PostKebabMenuItem(
        action: PostKebabAction.hide,
        icon: Icons.visibility_off_outlined,
        label: '게시물 숨기기',
      ),
      PostKebabMenuItem(
        action: PostKebabAction.block,
        icon: Icons.block_outlined,
        label: '이 유저 차단하기',
      ),
      PostKebabMenuItem(
        action: PostKebabAction.report,
        icon: Icons.flag_outlined,
        label: '신고하기',
      ),
      PostKebabMenuItem(
        action: PostKebabAction.share,
        icon: Icons.link_rounded,
        label: '링크 복사 / 공유하기',
      ),
    ];

Future<PostKebabAction?> _showGlassBottomSheet(
  BuildContext context, {
  required List<PostKebabMenuItem> items,
}) {
  return showSoriModalBottomSheet<PostKebabAction>(
    context: context,
    builder: (ctx) => SoriSheetFrame(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items) _GlassMenuTile(item: item),
        ],
      ),
    ),
  );
}

Future<PostKebabAction?> _showGlassDropdown(
  BuildContext context, {
  required List<PostKebabMenuItem> items,
  required Rect anchor,
}) {
  return showGeneralDialog<PostKebabAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: Colors.black.withValues(alpha: 0.08),
    pageBuilder: (ctx, _, _) {
      const menuWidth = 260.0;
      final screen = MediaQuery.sizeOf(ctx);
      var left = anchor.right - menuWidth;
      left = left.clamp(8.0, screen.width - menuWidth - 8);
      var top = anchor.bottom + 6;
      final estHeight = items.length * 52.0 + 16;
      if (top + estHeight > screen.height - 8) {
        top = anchor.top - estHeight - 6;
      }

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: Material(
              color: Colors.transparent,
              child: SoriGlassOverlay(
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in items) _GlassMenuTile(item: item),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _GlassMenuTile extends StatelessWidget {
  const _GlassMenuTile({required this.item});

  final PostKebabMenuItem item;

  @override
  Widget build(BuildContext context) {
    final color =
        item.destructive ? SoriTokens.systemRed : SoriTokens.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(item.action),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(item.icon, size: 22, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _handlePostKebabAction(
  BuildContext context, {
  required PostKebabAction action,
  required PostViewData data,
  required SoriStore store,
}) async {
  switch (action) {
    case PostKebabAction.edit:
      await PostFirstCreationPage.openForEdit(
        context,
        data: data,
        store: store,
      );
    case PostKebabAction.delete:
      await _confirmAndDelete(context, data: data, store: store);
    case PostKebabAction.share:
      await _copyShareLink(context, data: data, store: store);
    case PostKebabAction.hide:
      await store.hideFeedPost(data);
      if (!context.mounted) return;
      _snack(context, '피드에서 게시물을 숨겼습니다.', error: false);
    case PostKebabAction.block:
      await store.blockFeedAuthor(data);
      if (!context.mounted) return;
      _snack(context, '해당 유저를 차단했습니다.', error: false);
    case PostKebabAction.report:
      await _reportPost(context, data: data, store: store);
  }
}

Future<void> _confirmAndDelete(
  BuildContext context, {
  required PostViewData data,
  required SoriStore store,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SoriTokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        '게시물 삭제',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: const Text(
        '이 게시물을 영구적으로 삭제하시겠습니까?',
        style: TextStyle(height: 1.45, fontWeight: FontWeight.w600),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: SoriTokens.systemRed,
          ),
          child: const Text('승인'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final ok = await store.deletePostViewData(data);
  if (!context.mounted) return;
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
  _snack(
    context,
    ok ? '게시물을 삭제했습니다.' : (store.lastError ?? '삭제에 실패했습니다.'),
    error: !ok,
  );
}

Future<void> _copyShareLink(
  BuildContext context, {
  required PostViewData data,
  required SoriStore store,
}) async {
  final link = store.buildPostShareUrl(data);
  await Clipboard.setData(ClipboardData(text: link));
  if (!context.mounted) return;
  _snack(context, '링크를 복사했습니다.', error: false);
}

Future<void> _reportPost(
  BuildContext context, {
  required PostViewData data,
  required SoriStore store,
}) async {
  const reasons = [
    '스팸 또는 광고',
    '부적절한 콘텐츠',
    '허위 정보',
    '기타',
  ];
  final reason = await showSoriModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SoriSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '신고 사유 선택',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 12),
          for (final r in reasons)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(ctx, r),
                child: SizedBox(
                  height: 52,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      r,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  if (reason == null) return;
  await store.reportFeedPost(data, reason: reason);
  if (!context.mounted) return;
  _snack(context, '신고가 접수되었습니다.', error: false);
}

void _snack(BuildContext context, String message, {required bool error}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? SoriTokens.systemRed : SoriTokens.primary,
    ),
  );
}

/// Wrap kebab icon to capture anchor rect for desktop dropdown.
class PostKebabAnchor extends StatelessWidget {
  const PostKebabAnchor({
    super.key,
    required this.data,
    required this.store,
    required this.child,
  });

  final PostViewData data;
  final SoriStore store;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnCtx) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final box = btnCtx.findRenderObject() as RenderBox?;
            final anchor = box != null
                ? box.localToGlobal(Offset.zero) & box.size
                : null;
            showPostKebabMenu(
              btnCtx,
              data: data,
              store: store,
              anchor: anchor,
            );
          },
          child: child,
        );
      },
    );
  }
}
