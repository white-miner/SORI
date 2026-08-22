import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_post.dart';
import '../models/session_user.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import '../widgets/sori_insta_picker.dart';
import '../widgets/sori_network_image.dart';
import 'customer_management_cases_page.dart';
import 'seminar_class_detail_page.dart';
import 'success_cases_page.dart';

/// 글로벌 Community 탭 — B2B 광장 (케이스·인테리어·기기·중고·세미나).
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.store});

  final SoriStore store;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  SoriStore get store => widget.store;

  bool get _isDirector =>
      store.session?.activeMode == UserRole.director;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.refreshCommunityPosts();
      store.refreshCommunityHotCases();
      store.refreshSeminarClasses();
    });
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _tabs.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _composeInterior() async {
    if (!_isDirector) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원장 모드에서만 인테리어를 올릴 수 있어요')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _InteriorComposerSheet(store: store),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SoriTokens.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Community',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (_isDirector)
                    IconButton(
                      tooltip: '인테리어 올리기',
                      onPressed: _composeInterior,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      color: SoriTokens.primary,
                    ),
                ],
              ),
            ),
            Material(
              color: SoriTokens.background,
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: SoriTokens.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: Colors.white,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2.5,
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                tabs: const [
                  Tab(text: '추천'),
                  Tab(text: '케이스'),
                  Tab(text: '인테리어'),
                  Tab(text: '기기·중고'),
                  Tab(text: '세미나'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _RecommendSegment(store: store),
                  _isDirector
                      ? SuccessCasesPage(store: store)
                      : CustomerManagementCasesPage(store: store),
                  _InteriorSegment(
                    store: store,
                    isOwner: _isDirector,
                    onCompose: _composeInterior,
                  ),
                  _MarketSegment(store: store),
                  _SeminarSegment(store: store),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendSegment extends StatelessWidget {
  const _RecommendSegment({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final interiors = store.communityPosts
        .where((p) => p.postType == CommunityPostType.interior)
        .take(6)
        .toList();
    final markets = store.communityPosts
        .where(
          (p) =>
              p.postType == CommunityPostType.marketplace ||
              p.postType == CommunityPostType.deviceReview,
        )
        .take(4)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        const Text(
          '업계 광장에서 인테리어·실사용 기기·중고를 한곳에서',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: SoriTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '인테리어 쇼룸',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (interiors.isEmpty)
          const _EmptyHint(text: '아직 올라온 인테리어가 없어요. 첫 쇼룸을 올려보세요.')
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: interiors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) =>
                  _InteriorCard(post: interiors[i], width: 140),
            ),
          ),
        const SizedBox(height: 22),
        const Text(
          '기기 · 중고',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (markets.isEmpty)
          const _EmptyHint(
            text: '실사용 리뷰와 중고 매물이 여기에 모입니다. (채팅·연락 기반)',
          )
        else
          ...markets.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MarketCard(post: p),
              )),
      ],
    );
  }
}

class _InteriorSegment extends StatelessWidget {
  const _InteriorSegment({
    required this.store,
    required this.isOwner,
    required this.onCompose,
  });

  final SoriStore store;
  final bool isOwner;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final posts = store.communityPosts
        .where((p) => p.postType == CommunityPostType.interior)
        .toList();

    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.apartment_outlined,
                  size: 48, color: SoriTokens.textSecondary),
              const SizedBox(height: 14),
              const Text(
                '인테리어 쇼룸',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '샵 사진을 올리고 소품·시공에 링크를 태그하세요.\n다른 원장이 랜선으로 투어합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: SoriTokens.textSecondary,
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onCompose,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('쇼룸 올리기'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: posts.length + (isOwner ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (isOwner && i == 0) {
          return OutlinedButton.icon(
            onPressed: onCompose,
            icon: const Icon(Icons.add),
            label: const Text('인테리어 추가'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SoriTokens.primary,
              side: const BorderSide(color: SoriTokens.outlinePurple),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          );
        }
        final post = posts[isOwner ? i - 1 : i];
        return _InteriorFeedTile(post: post, store: store);
      },
    );
  }
}

class _InteriorFeedTile extends StatelessWidget {
  const _InteriorFeedTile({required this.post, required this.store});

  final CommunityPost post;
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final img = post.primaryImageUrl;
    final tags = post.styleTags;
    return Container(
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 11,
            child: img == null
                ? const ColoredBox(
                    color: Color(0xFF1A1028),
                    child: Icon(Icons.apartment_outlined,
                        color: SoriTokens.primary, size: 40),
                  )
                : SoriNetworkImage(url: img, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.title.trim().isNotEmpty)
                  Text(
                    post.title.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                if (post.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    post.body.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: SoriTokens.textSecondary,
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags
                        .take(5)
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: SoriTokens.primarySoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              t.startsWith('#') ? t : '#$t',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: SoriTokens.primary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (post.shopId == store.shop.id) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => store.removeCommunityPost(post.id),
                      child: const Text('삭제', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteriorCard extends StatelessWidget {
  const _InteriorCard({required this.post, required this.width});
  final CommunityPost post;
  final double width;

  @override
  Widget build(BuildContext context) {
    final img = post.primaryImageUrl;
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              SoriNetworkImage(url: img, fit: BoxFit.cover)
            else
              const ColoredBox(color: Color(0xFF18181B)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC0A0A0C)],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                post.title.trim().isEmpty
                    ? (post.body.trim().isEmpty ? '인테리어' : post.body.trim())
                    : post.title.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketSegment extends StatelessWidget {
  const _MarketSegment({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final posts = store.communityPosts
        .where(
          (p) =>
              p.postType == CommunityPostType.marketplace ||
              p.postType == CommunityPostType.deviceReview,
        )
        .toList();

    if (posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.devices_other_outlined,
                  size: 48, color: SoriTokens.textSecondary),
              SizedBox(height: 14),
              Text(
                '기기 리뷰 · 중고 장터',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                '실사용 후기와 중고 매물을 연결합니다.\nPhase 1은 채팅·연락처로 가볍게 거래해요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: posts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _MarketCard(post: posts[i]),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.post});
  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final listing = post.listing;
    final status = listing?.status ?? MarketListingStatus.active;
    final phone = listing?.contactPhone?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(status: status),
              const Spacer(),
              if (listing != null && listing.price > 0)
                Text(
                  '${_formatWon(listing.price)}원',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: SoriTokens.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            listing?.deviceName.trim().isNotEmpty == true
                ? listing!.deviceName
                : (post.title.trim().isEmpty ? post.body : post.title),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          if (post.body.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              post.body.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: SoriTokens.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (phone.isNotEmpty)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('연락하기'),
                ),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('문의 메시지를 남기면 판매자에게 전달됩니다 (Phase 1)'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('채팅 문의'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatWon(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rev = s.length - i;
      buf.write(s[i]);
      if (rev > 1 && rev % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final MarketListingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MarketListingStatus.active => SoriTokens.primary,
      MarketListingStatus.reserved => const Color(0xFFFBBF24),
      MarketListingStatus.sold => SoriTokens.textSecondary,
      _ => SoriTokens.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _SeminarSegment extends StatelessWidget {
  const _SeminarSegment({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    final classes = store.seminarClasses;
    if (classes.isEmpty) {
      return const Center(
        child: Text(
          '모집 중 세미나가 없어요',
          style: TextStyle(color: SoriTokens.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: classes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = classes[i];
        final when = c.eventDate;
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: SoriTokens.outlinePurple),
          ),
          tileColor: SoriTokens.surface,
          leading: const Icon(Icons.school_outlined, color: SoriTokens.primary),
          title: Text(
            c.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            when == null
                ? '정원 ${c.currentEnrollment}/${c.maxCapacity}'
                : '${when.month}/${when.day} · 정원 ${c.currentEnrollment}/${c.maxCapacity}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => SeminarClassDetailPage.open(
            context,
            store: store,
            classId: c.id,
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: SoriTokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InteriorComposerSheet extends StatefulWidget {
  const _InteriorComposerSheet({required this.store});
  final SoriStore store;

  @override
  State<_InteriorComposerSheet> createState() => _InteriorComposerSheetState();
}

class _InteriorComposerSheetState extends State<_InteriorComposerSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final List<Uint8List> _images = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await openSoriInstaPicker(
      context,
      maxAssets: (12 - _images.length).clamp(1, 12),
      title: '인테리어 사진',
    );
    if (files.isEmpty || !mounted) return;
    setState(() => _images.addAll(files));
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_images.isEmpty && _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 또는 소개글을 입력해 주세요')),
      );
      return;
    }
    setState(() => _saving = true);
    final tags = _tagCtrl.text
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.replaceFirst('#', '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final post = await widget.store.createCommunityPost(
      postType: CommunityPostType.interior,
      title: _titleCtrl.text,
      body: _bodyCtrl.text,
      imageBytesList: List.from(_images),
      styleTags: tags,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시 실패 — DB 마이그레이션(049)을 확인해 주세요'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('인테리어 쇼룸이 등록되었어요'),
        backgroundColor: SoriTokens.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + soriSheetBottomPadding(context),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '인테리어 쇼룸',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '예: 20평 의료미용 리뉴얼',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '소개',
                hintText: '조명·카운터·시술실 포인트',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagCtrl,
              decoration: const InputDecoration(
                labelText: '스타일 태그',
                hintText: '미니멀 조명 카운터',
              ),
            ),
            const SizedBox(height: 12),
            if (_images.isNotEmpty)
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _images[i],
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _saving ? null : _pick,
                  icon: const Icon(Icons.photo_library_outlined),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: SoriTokens.primary,
                  ),
                  child: Text(_saving ? '등록 중…' : '게시'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
