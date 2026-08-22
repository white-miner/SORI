import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/seminar_class.dart';
import '../models/shop_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import '../views/seminar_class_detail_page.dart';
import 'sori_insta_picker.dart';
import 'sori_network_image.dart';

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

  Future<void> _confirmDelete(BuildContext context, ShopPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SoriTokens.surface,
        title: const Text('소식을 삭제할까요?'),
        content: const Text('삭제하면 피드에서 바로 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final removed = await store.removeShopPost(post.id);
    if (!context.mounted) return;
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 글을 삭제할 권한이 없어요'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final posts = store.shopPosts;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '최근 소식',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              decoration: BoxDecoration(
                color: SoriTokens.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SoriTokens.outlinePurple),
              ),
              child: posts.isEmpty
                  ? Padding(
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
                  : Column(
                      children: [
                        for (var i = 0; i < posts.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Divider(height: 1, color: SoriTokens.border),
                            ),
                          _PostCard(
                            store: store,
                            post: posts[i],
                            ownerLabel: ownerLabel,
                            avatarUrl: avatarUrl,
                            isOwner: isOwner,
                            seminar: store.seminarClassById(
                              posts[i].seminarClassId,
                            ),
                            onDelete: () => _confirmDelete(context, posts[i]),
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.store,
    required this.post,
    required this.ownerLabel,
    required this.isOwner,
    required this.onDelete,
    this.avatarUrl,
    this.seminar,
  });

  final SoriStore store;
  final ShopPost post;
  final String ownerLabel;
  final String? avatarUrl;
  final bool isOwner;
  final SeminarClass? seminar;
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
    final av = (avatarUrl ?? '').trim();
    final urls = post.imageUrls
        .map((e) => e.trim())
        .where((e) => e.startsWith('http') || e.startsWith('data:'))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
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
          const SizedBox(height: 10),
          if (post.isSeminar || seminar != null)
            _SeminarEmbedCard(store: store, post: post, seminar: seminar)
          else
            Text(
              post.body,
              softWrap: true,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                letterSpacing: -0.1,
                color: SoriTokens.textPrimary,
              ),
            ),
          if (urls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PostImageStrip(urls: urls),
          ],
        ],
      ),
    );
  }
}

class _PostImageStrip extends StatelessWidget {
  const _PostImageStrip({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: SoriNetworkImage(url: urls.first, fit: BoxFit.cover),
        ),
      );
    }
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 132,
              child: SoriNetworkImage(url: urls[i], fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

class _SeminarEmbedCard extends StatelessWidget {
  const _SeminarEmbedCard({
    required this.store,
    required this.post,
    this.seminar,
  });

  final SoriStore store;
  final ShopPost post;
  final SeminarClass? seminar;

  String get _title {
    final t = seminar?.title.trim() ?? '';
    if (t.isNotEmpty) return t;
    final body = post.body.trim();
    final first = body.split('\n').first.replaceFirst('[모집 중] ', '');
    return first.isEmpty ? '세미나 모집' : first;
  }

  String get _when {
    final d = seminar?.eventDate;
    if (d != null) {
      return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    for (final line in post.body.split('\n')) {
      if (line.trim().startsWith('일시')) return line.trim().replaceFirst('일시 ', '');
    }
    return '';
  }

  String get _capacity {
    if (seminar != null) {
      return '${seminar!.currentEnrollment}/${seminar!.maxCapacity}명';
    }
    for (final line in post.body.split('\n')) {
      if (line.trim().startsWith('정원')) return line.trim().replaceFirst('정원 ', '');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final when = _when;
    final capa = _capacity;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoriTokens.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.school_outlined, size: 16, color: SoriTokens.primary),
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
            _title,
            style: const TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w900,
              color: SoriTokens.textPrimary,
            ),
          ),
          if (when.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '일시  $when',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textSecondary,
              ),
            ),
          ],
          if (capa.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '정원  $capa',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: SoriTokens.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final id = (seminar?.id ?? post.seminarClassId ?? '').trim();
                if (id.isEmpty) return;
                SeminarClassDetailPage.open(
                  context,
                  store: store,
                  classId: id,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                '신청하기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
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
  final List<Uint8List> _images = [];
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 8 - _images.length;
    if (remaining <= 0) return;
    final files = await openSoriInstaPicker(
      context,
      maxAssets: remaining,
      title: '새 소식',
    );
    if (files.isEmpty || !mounted) return;
    setState(() => _images.addAll(files));
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.createShopPost(
        body: text,
        imageBytesList: List<Uint8List>.from(_images),
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
            maxLines: 6,
            maxLength: 2000,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: '팬덤에게 전할 팁이나 프로모션을 적어주세요',
              filled: true,
              fillColor: SoriTokens.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _images[i],
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _saving ? null : _pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                tooltip: '사진 첨부',
                style: IconButton.styleFrom(
                  foregroundColor: SoriTokens.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _images.isEmpty
                      ? '사진 첨부 (선택, 최대 8장)'
                      : '${_images.length}장 선택됨',
                  style: const TextStyle(
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
