import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../../models/customer_chart.dart';
import '../../services/sori_store.dart';

/// Lightweight B/A thumb for BaRecall overlay (PRD v3.1-C).
class ChartBaThumb {
  const ChartBaThumb({
    required this.chartId,
    required this.visitNumber,
    this.beforeUrl,
    this.afterUrl,
    this.careName = '',
  });

  final String chartId;
  final int visitNumber;
  final String? beforeUrl;
  final String? afterUrl;
  final String careName;

  bool get hasAnyPhoto {
    final b = beforeUrl?.trim() ?? '';
    final a = afterUrl?.trim() ?? '';
    return b.isNotEmpty || a.isNotEmpty;
  }

  List<String> get imageUrls {
    final out = <String>[];
    final b = beforeUrl?.trim() ?? '';
    final a = afterUrl?.trim() ?? '';
    if (b.isNotEmpty) out.add(b);
    if (a.isNotEmpty) out.add(a);
    return out;
  }

  factory ChartBaThumb.fromChart(CustomerChart chart) {
    return ChartBaThumb(
      chartId: chart.id,
      visitNumber: chart.visitNumber,
      beforeUrl: chart.beforeImageUrl,
      afterUrl: chart.afterImageUrl,
      careName: chart.careName,
    );
  }
}

/// Client-side BaRecall prefetch cache — warm ≤ 1s SLA (PRD v3.1).
class BaRecallCache {
  BaRecallCache._();
  static final BaRecallCache instance = BaRecallCache._();

  /// Warm SLA target after prefetch completes.
  static const Duration warmSla = Duration(seconds: 1);

  final Map<String, List<ChartBaThumb>> _thumbs = {};
  final Map<String, DateTime> _warmAt = {};
  final Map<String, Future<void>> _inflight = {};

  bool isWarm(String customerId) {
    final id = customerId.trim();
    return _warmAt.containsKey(id) && (_thumbs[id]?.isNotEmpty ?? false);
  }

  DateTime? warmedAt(String customerId) => _warmAt[customerId.trim()];

  List<ChartBaThumb> thumbsFor(String customerId) {
    return List<ChartBaThumb>.unmodifiable(
      _thumbs[customerId.trim()] ?? const [],
    );
  }

  void invalidate(String customerId) {
    final id = customerId.trim();
    _thumbs.remove(id);
    _warmAt.remove(id);
    _inflight.remove(id);
  }

  void invalidateAll() {
    _thumbs.clear();
    _warmAt.clear();
    _inflight.clear();
  }

  /// Prefetch chart B/A list + decode network images into disk/memory cache.
  Future<void> prefetch(
    SoriStore store,
    String customerId, {
    BuildContext? imageContext,
  }) {
    final id = customerId.trim();
    if (id.isEmpty) return Future.value();

    final existing = _inflight[id];
    if (existing != null) return existing;

    final future = _doPrefetch(store, id, imageContext: imageContext);
    _inflight[id] = future;
    return future.whenComplete(() {
      if (identical(_inflight[id], future)) {
        _inflight.remove(id);
      }
    });
  }

  Future<void> _doPrefetch(
    SoriStore store,
    String customerId, {
    BuildContext? imageContext,
  }) async {
    final charts = store.chartsForCustomer(customerId);
    final thumbs = charts
        .map(ChartBaThumb.fromChart)
        .where((t) => t.hasAnyPhoto)
        .toList()
      ..sort((a, b) => a.visitNumber.compareTo(b.visitNumber));

    _thumbs[customerId] = thumbs;

    if (imageContext != null && imageContext.mounted) {
      await precacheThumbImages(imageContext, thumbs);
    }

    _warmAt[customerId] = DateTime.now();
  }

  /// Decode URLs into Flutter/CachedNetworkImage cache (best-effort).
  static Future<void> precacheThumbImages(
    BuildContext context,
    List<ChartBaThumb> thumbs, {
    int maxImages = 24,
  }) async {
    final urls = <String>[];
    for (final t in thumbs) {
      for (final u in t.imageUrls) {
        if (u.startsWith('http') || u.startsWith('https')) {
          urls.add(u);
        }
        if (urls.length >= maxImages) break;
      }
      if (urls.length >= maxImages) break;
    }

    await Future.wait(
      urls.map((url) async {
        try {
          await precacheImage(
            CachedNetworkImageProvider(url),
            context,
          );
        } catch (_) {
          // Best-effort — overlay still opens from network if needed.
        }
      }),
    );
  }

  /// Build thumbs synchronously from store (used when opening cold).
  static List<ChartBaThumb> buildFromStore(
    SoriStore store,
    String customerId,
  ) {
    return store
        .chartsForCustomer(customerId)
        .map(ChartBaThumb.fromChart)
        .where((t) => t.hasAnyPhoto)
        .toList()
      ..sort((a, b) => a.visitNumber.compareTo(b.visitNumber));
  }
}
