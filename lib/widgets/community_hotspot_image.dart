import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_post.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/sori_bottom_sheet.dart';
import 'sori_network_image.dart';

/// 뷰어: 정규화 좌표 핀 + 탭 시 바텀시트.
class CommunityHotspotImage extends StatefulWidget {
  const CommunityHotspotImage({
    super.key,
    required this.imageUrl,
    required this.tags,
    this.aspectRatio = 16 / 11,
    this.fit = BoxFit.cover,
    this.bytes,
    this.store,
    this.ownerShopId,
    this.postId,
  });

  final String? imageUrl;
  final Uint8List? bytes;
  final List<CommunityPostTag> tags;
  final double aspectRatio;
  final BoxFit fit;
  final SoriStore? store;
  final String? ownerShopId;
  final String? postId;

  @override
  State<CommunityHotspotImage> createState() => _CommunityHotspotImageState();
}

class _CommunityHotspotImageState extends State<CommunityHotspotImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _openTag(CommunityPostTag tag) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _HotspotTagSheet(
        tag: tag,
        store: widget.store,
        ownerShopId: widget.ownerShopId,
        postId: widget.postId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.bytes != null)
                Image.memory(widget.bytes!, fit: widget.fit)
              else if (widget.imageUrl != null &&
                  widget.imageUrl!.trim().isNotEmpty)
                SoriNetworkImage(url: widget.imageUrl!, fit: widget.fit)
              else
                const ColoredBox(
                  color: Color(0xFF1A1028),
                  child: Icon(
                    Icons.apartment_outlined,
                    color: SoriTokens.primary,
                    size: 40,
                  ),
                ),
              for (final tag in widget.tags)
                Positioned(
                  left: (tag.normX.clamp(0.0, 1.0) * w) - 9,
                  top: (tag.normY.clamp(0.0, 1.0) * h) - 9,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openTag(tag),
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) {
                        final t = Curves.easeInOut.transform(_pulse.value);
                        // 은밀한 반투명 점 — 시야를 가리지 않음.
                        return Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(
                              alpha: 0.28 + 0.12 * t,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: 0.55 + 0.2 * t,
                              ),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 4 + 2 * t,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: Icon(
                        Icons.add,
                        size: 10,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HotspotTagSheet extends StatelessWidget {
  const _HotspotTagSheet({
    required this.tag,
    this.store,
    this.ownerShopId,
    this.postId,
  });
  final CommunityPostTag tag;
  final SoriStore? store;
  final String? ownerShopId;
  final String? postId;

  @override
  Widget build(BuildContext context) {
    final url = tag.externalUrl?.trim() ?? '';
    final vendor = tag.vendorName.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + soriSheetBottomPadding(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tag.label.trim().isEmpty ? '태그' : tag.label.trim(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (vendor.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              vendor,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SoriTokens.textSecondary,
              ),
            ),
          ],
          if (url.isNotEmpty) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
                final shopId = ownerShopId?.trim() ?? '';
                if (store != null && shopId.isNotEmpty) {
                  await store!.openAffiliateExternalUrl(
                    url: url,
                    ownerShopId: shopId,
                    label: tag.label,
                    postId: postId,
                    postTagId: tag.id,
                    partnerId: tag.partnerId,
                  );
                }
                final uri = Uri.tryParse(
                  url.startsWith('http') ? url : 'https://$url',
                );
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('외부 링크 열기'),
              style: FilledButton.styleFrom(
                backgroundColor: SoriTokens.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 작성 시트에서 쓰는 핀 모델.
class HotspotPinDraft {
  HotspotPinDraft({
    required this.normX,
    required this.normY,
    this.label = '',
    this.vendorName = '',
    this.externalUrl = '',
  });

  double normX;
  double normY;
  String label;
  String vendorName;
  String externalUrl;

  CommunityTagDraft toTagDraft(int mediaIndex) => CommunityTagDraft(
        mediaIndex: mediaIndex,
        label: label,
        vendorName: vendorName,
        externalUrl: externalUrl,
        normX: normX,
        normY: normY,
      );
}

Future<HotspotPinDraft?> showHotspotPinForm(
  BuildContext context, {
  required double normX,
  required double normY,
  HotspotPinDraft? existing,
}) async {
  final labelCtrl = TextEditingController(text: existing?.label ?? '');
  final vendorCtrl = TextEditingController(text: existing?.vendorName ?? '');
  final urlCtrl = TextEditingController(text: existing?.externalUrl ?? '');

  final result = await showModalBottomSheet<HotspotPinDraft>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: SoriTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16 +
              MediaQuery.viewInsetsOf(ctx).bottom +
              soriSheetBottomPadding(ctx),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '핫스팟 핀',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: '제품명 / 시공 영역',
                hintText: '예: 리셉션 카운터',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: vendorCtrl,
              decoration: const InputDecoration(
                labelText: '업체명',
                hintText: '예: OO 인테리어',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: '외부 URL (선택)',
                hintText: 'https://…',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                if (label.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('제품명/시공 영역을 입력해 주세요')),
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  HotspotPinDraft(
                    normX: normX,
                    normY: normY,
                    label: label,
                    vendorName: vendorCtrl.text.trim(),
                    externalUrl: urlCtrl.text.trim(),
                  ),
                );
              },
              style:
                  FilledButton.styleFrom(backgroundColor: SoriTokens.primary, foregroundColor: SoriTokens.onPrimary),
              child: const Text('핀 저장'),
            ),
          ],
        ),
      );
    },
  );

  labelCtrl.dispose();
  vendorCtrl.dispose();
  urlCtrl.dispose();
  return result;
}

/// 편집용 오버레이 (HotspotPinDraft 리스트).
class CommunityHotspotDraftEditor extends StatelessWidget {
  const CommunityHotspotDraftEditor({
    super.key,
    required this.bytes,
    required this.pins,
    required this.onChanged,
    this.aspectRatio = 4 / 3,
  });

  final Uint8List bytes;
  final List<HotspotPinDraft> pins;
  final ValueChanged<List<HotspotPinDraft>> onChanged;
  final double aspectRatio;

  Future<void> _addAt(BuildContext context, double nx, double ny) async {
    final draft = await showHotspotPinForm(context, normX: nx, normY: ny);
    if (draft == null) return;
    onChanged([...pins, draft]);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(bytes, fit: BoxFit.cover),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) {
                      final nx = (d.localPosition.dx / w).clamp(0.02, 0.98);
                      final ny = (d.localPosition.dy / h).clamp(0.02, 0.98);
                      _addAt(context, nx, ny);
                    },
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        pins.isEmpty
                            ? '사진을 탭해 핀 추가'
                            : '핀 ${pins.length}개 · 길게 눌러 삭제',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < pins.length; i++)
                  Positioned(
                    left: (pins[i].normX * w) - 16,
                    top: (pins[i].normY * h) - 16,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final updated = await showHotspotPinForm(
                          context,
                          normX: pins[i].normX,
                          normY: pins[i].normY,
                          existing: pins[i],
                        );
                        if (updated == null) return;
                        final next = [...pins];
                        next[i] = updated;
                        onChanged(next);
                      },
                      onLongPress: () {
                        final next = [...pins]..removeAt(i);
                        onChanged(next);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SoriTokens.primary,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.push_pin,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
