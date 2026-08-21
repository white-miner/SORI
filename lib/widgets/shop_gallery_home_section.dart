import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/shop_gallery_slide.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'media_permission_dialogs.dart';

/// Home 샵 갤러리 가로 캐러셀 (최대 20, Owner + 슬롯).
class ShopGalleryHomeSection extends StatelessWidget {
  const ShopGalleryHomeSection({
    super.key,
    required this.store,
    required this.isOwner,
  });

  final SoriStore store;
  final bool isOwner;

  Future<void> _add(BuildContext context) async {
    if (store.gallerySlides.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('갤러리는 최대 20장까지 등록할 수 있어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final file = await pickImageWithPermissionGuards(
      context: context,
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null || !context.mounted) return;
    try {
      final bytes = await file.readAsBytes();
      final ok = await store.uploadShopGalleryImage(bytes);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '갤러리에 추가했어요' : '업로드에 실패했어요'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? SoriTokens.primary : Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = store.gallerySlides;
    final itemCount = slides.length + (isOwner ? 1 : 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SoriTokens.outlinePurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '샵 갤러리',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: SoriTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOwner
                ? '최대 20장 · ${slides.length}/20'
                : '인테리어 · 제품 · 케어 공간을 넘겨보세요',
            style: const TextStyle(
              fontSize: 12,
              color: SoriTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 148,
            child: itemCount == 0
                ? const Center(
                    child: Text(
                      '아직 등록된 사진이 없어요',
                      style: TextStyle(color: SoriTokens.textSecondary),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (_) => true,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: itemCount,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        if (isOwner && i == 0) {
                          return _AddTile(onTap: () => _add(context));
                        }
                        final slide = slides[isOwner ? i - 1 : i];
                        return _GalleryTile(
                          slide: slide,
                          isOwner: isOwner,
                          onDelete: () async {
                            await store.removeShopGalleryItem(slide.id);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.primarySoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const SizedBox(
          width: 110,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 36, color: SoriTokens.primary),
              SizedBox(height: 6),
              Text(
                '추가',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
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
    required this.slide,
    required this.isOwner,
    required this.onDelete,
  });

  final ShopGallerySlide slide;
  final bool isOwner;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 196,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (slide.hasNetworkImage)
              Image.network(
                slide.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF1F1830),
                  child: Icon(Icons.image_outlined,
                      color: SoriTokens.textSecondary),
                ),
              )
            else
              Image.network(
                'https://picsum.photos/seed/sori-gallery-${slide.id}/600/400',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF1F1830),
                  child: Icon(Icons.image_outlined,
                      color: SoriTokens.textSecondary),
                ),
              ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC0A0A0C)],
                  ),
                ),
                child: Text(
                  slide.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
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
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 16, color: Colors.white),
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
