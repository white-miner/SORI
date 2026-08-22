import 'package:flutter/material.dart';

import '../models/shop_gallery_slide.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'sori_insta_picker.dart';

/// Shop 탭 갤러리 — 아웃박스 타이틀 + 3열 가로 스와이프 (edge bleed).
class ShopGalleryHomeSection extends StatelessWidget {
  const ShopGalleryHomeSection({
    super.key,
    required this.store,
    required this.isOwner,
  });

  final SoriStore store;
  final bool isOwner;

  Future<void> _add(BuildContext context) async {
    final remaining = 20 - store.gallerySlides.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('갤러리는 최대 20장까지 등록할 수 있어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final files = await openSoriInstaPicker(
      context,
      maxAssets: remaining,
      title: '샵 갤러리',
    );
    if (files.isEmpty || !context.mounted) return;

    var okCount = 0;
    var failCount = 0;
    for (final bytes in files) {
      if (store.gallerySlides.length >= 20) break;
      try {
        final ok = await store.uploadShopGalleryImage(bytes);
        if (ok) {
          okCount++;
        } else {
          failCount++;
        }
      } catch (_) {
        failCount++;
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failCount == 0
              ? '$okCount장을 갤러리에 추가했어요'
              : '$okCount장 추가 · $failCount장 실패',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: okCount > 0 ? SoriTokens.primary : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = store.gallerySlides;
    final width = MediaQuery.sizeOf(context).width;
    // 3열 + 살짝 다음 카드가 보이도록
    final gap = 8.0;
    final sidePad = 16.0;
    final cardW = (width - sidePad - gap * 2) / 3;
    final cardH = cardW * 1.15;
    final itemCount = slides.length + (isOwner ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '샵 갤러리',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: SoriTokens.textPrimary,
                  ),
                ),
              ),
              if (isOwner)
                Text(
                  '${slides.length}/20',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SoriTokens.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: cardH,
          child: itemCount == 0
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '아직 등록된 사진이 없어요',
                      style: TextStyle(
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  itemCount: itemCount,
                  separatorBuilder: (_, _) => SizedBox(width: gap),
                  itemBuilder: (context, i) {
                    if (isOwner && i == 0) {
                      return _AddTile(
                        width: cardW,
                        height: cardH,
                        onTap: () => _add(context),
                      );
                    }
                    final slide = slides[isOwner ? i - 1 : i];
                    return _GalleryTile(
                      width: cardW,
                      height: cardH,
                      slide: slide,
                      isOwner: isOwner,
                      onDelete: () async {
                        await store.removeShopGalleryItem(slide.id);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.width,
    required this.height,
    required this.onTap,
  });

  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF18181B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: width,
          height: height,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 28, color: SoriTokens.primary),
              SizedBox(height: 6),
              Text(
                '추가',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: SoriTokens.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.width,
    required this.height,
    required this.slide,
    required this.isOwner,
    required this.onDelete,
  });

  final double width;
  final double height;
  final ShopGallerySlide slide;
  final bool isOwner;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (slide.hasNetworkImage)
              Image.network(
                slide.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF18181B),
                  child: Icon(Icons.image_outlined,
                      color: SoriTokens.textSecondary),
                ),
              )
            else
              const ColoredBox(
                color: Color(0xFF18181B),
                child: Icon(Icons.image_outlined,
                    color: SoriTokens.textSecondary),
              ),
            if (isOwner)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
