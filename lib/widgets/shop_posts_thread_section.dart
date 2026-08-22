import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/shop_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import 'media_permission_dialogs.dart';

/// Home「최근 소식」쓰레드 + 글쓰기 시트.
class ShopPostsThreadSection extends StatelessWidget {
  const ShopPostsThreadSection({
    super.key,
    required this.store,
    required this.isOwner,
    required this.ownerLabel,
    this.avatarUrl,
  });

  final SoriStore store;
  final bool isOwner;
  final String ownerLabel;
  final String? avatarUrl;

  Future<void> _openComposer(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _ShopPostComposerSheet(store: store),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = store.shopPosts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '최근 소식',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: () => _openComposer(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    '글쓰기',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: SoriTokens.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                isOwner
                    ? '팬덤에게 팁이나 프로모션을 남겨보세요'
                    : '아직 소식이 없어요',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SoriTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...posts.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _PostCard(
                  post: p,
                  ownerLabel: ownerLabel,
                  avatarUrl: avatarUrl,
                  isOwner: isOwner,
                  onDelete: () => store.removeShopPost(p.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.ownerLabel,
    required this.isOwner,
    required this.onDelete,
    this.avatarUrl,
  });

  final ShopPost post;
  final String ownerLabel;
  final String? avatarUrl;
  final bool isOwner;
  final VoidCallback onDelete;

  String _timeLabel(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final img = post.primaryImageUrl;
    final av = (avatarUrl ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: SoriTokens.primarySoft,
              backgroundImage:
                  av.startsWith('http') ? NetworkImage(av) : null,
              child: av.startsWith('http')
                  ? null
                  : const Icon(Icons.person, size: 16, color: SoriTokens.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ownerLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _timeLabel(post.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isOwner)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: SoriTokens.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (post.isSeminar) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SoriTokens.primarySoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SoriTokens.outlinePurple),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.school_outlined,
                        size: 16, color: SoriTokens.primary),
                    SizedBox(width: 6),
                    Text(
                      '세미나 모집',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: SoriTokens.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  post.body,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: SoriTokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Seminar 탭에서 보기 →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: SoriTokens.primary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            post.body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: SoriTokens.textPrimary,
            ),
          ),
        ],
        if (img != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                img,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF1F1830),
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShopPostComposerSheet extends StatefulWidget {
  const _ShopPostComposerSheet({required this.store});

  final SoriStore store;

  @override
  State<_ShopPostComposerSheet> createState() => _ShopPostComposerSheetState();
}

class _ShopPostComposerSheetState extends State<_ShopPostComposerSheet> {
  final _controller = TextEditingController();
  Uint8List? _imageBytes;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await pickImageWithPermissionGuards(
      context: context,
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.createShopPost(
        body: text,
        imageBytes: _imageBytes,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('게시 실패: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + soriSheetBottomPadding(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SoriTokens.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '새 소식 작성',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 5,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: '팬덤에게 전할 팁이나 프로모션을 적어주세요',
              filled: true,
              fillColor: SoriTokens.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (_imageBytes != null) ...[
            const SizedBox(height: 8),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _imageBytes!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _imageBytes = null),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                tooltip: '사진 첨부',
                style: IconButton.styleFrom(
                  foregroundColor: SoriTokens.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '사진 첨부 (선택)',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: SoriTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: SoriTokens.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  _saving ? '등록 중…' : '등록',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
