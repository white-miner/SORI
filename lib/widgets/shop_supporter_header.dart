import 'package:flutter/material.dart';

import '../models/fan_supporter.dart';
import '../models/shop_supporter_header.dart';
import 'fan_sponsor_credits.dart';
import 'supporter_dashboard_sheet.dart';

/// 원장 마이페이지 히어로 — 팔로워 수 + 후원자 Facepile (탑 후원자 맨 앞).
class ShopSupporterHeaderBanner extends StatelessWidget {
  const ShopSupporterHeaderBanner({
    super.key,
    required this.header,
    this.onRefresh,
  });

  final ShopSupporterHeader header;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final hero = header.specialHero;
    var ranked = FanSupporterEntry.ranked(header.facepile);
    if (hero != null && hero.name.trim().isNotEmpty) {
      ranked = [
        hero,
        ...ranked.where((e) => e.customerId != hero.customerId),
      ];
    }
    final top = header.topSupporter;

    return GestureDetector(
      onTap: ranked.isEmpty
          ? null
          : () => showSupporterDashboardSheet(
                context,
                supporters: ranked,
                followerCount: header.followerCount,
                supporterCount: header.supporterCount,
              ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ranked.isNotEmpty) ...[
            SupporterFacepile(supporters: ranked, size: 28, maxVisible: 3),
            const SizedBox(height: 8),
          ],
          Text(
            header.metricsLine,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.88),
              letterSpacing: 0.1,
            ),
          ),
          if (top != null && top.name.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hero != null
                  ? '플래티넘 스페셜 ${hero.name.trim()}'
                  : '탑 후원자 ${top.name.trim()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
