import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/shop_media_storage.dart';
import '../theme/sori_tokens.dart';
import '../utils/storage_image_url.dart';

/// Storage public URL · data URL 을 캐시와 함께 로드.
class SoriNetworkImage extends StatelessWidget {
  const SoriNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.error,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    final raw = url.trim();
    if (raw.isEmpty) return error ?? const SizedBox.shrink();

    if (raw.startsWith('data:image')) {
      final comma = raw.indexOf(',');
      if (comma > 0) {
        try {
          final bytes = base64Decode(raw.substring(comma + 1));
          return Image.memory(bytes, fit: fit, alignment: alignment);
        } catch (_) {}
      }
    }

    final resolved =
        StorageImageUrl.resolve(raw, bucket: ShopMediaStorage.bucket) ?? raw;
    if (!StorageImageUrl.isNetworkUrl(resolved)) {
      return error ?? const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: resolved,
      fit: fit,
      alignment: alignment,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => const ColoredBox(color: Color(0xFF18181B)),
      errorWidget: (_, _, _) =>
          error ??
          const ColoredBox(
            color: SoriTokens.primaryDark,
            child: Center(
              child: Icon(Icons.broken_image_outlined,
                  color: SoriTokens.textSecondary),
            ),
          ),
    );
  }
}
