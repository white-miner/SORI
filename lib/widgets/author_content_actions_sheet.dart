import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';

enum AuthorContentAction { draft, edit, delete }

/// Shared kebab actions for content authors (seminar / B/A / Whisper).
Future<AuthorContentAction?> showAuthorContentActionsSheet(
  BuildContext context, {
  bool showDraft = false,
  String draftLabel = '임시저장',
  bool showEdit = true,
  bool showDelete = true,
  String editLabel = '수정',
  String deleteLabel = '삭제',
}) {
  return showModalBottomSheet<AuthorContentAction>(
    context: context,
    useRootNavigator: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SoriTokens.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 8),
            if (showDraft)
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(draftLabel),
                onTap: () => Navigator.pop(ctx, AuthorContentAction.draft),
              ),
            if (showEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(editLabel),
                onTap: () => Navigator.pop(ctx, AuthorContentAction.edit),
              ),
            if (showDelete)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: SoriTokens.systemRed,
                ),
                title: Text(
                  deleteLabel,
                  style: const TextStyle(color: SoriTokens.systemRed),
                ),
                onTap: () => Navigator.pop(ctx, AuthorContentAction.delete),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('닫기'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    },
  );
}
