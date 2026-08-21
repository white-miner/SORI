import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import 'service_menu_page.dart';
import 'shop_settings_page.dart';

/// 원장 샵 프로필 편집 허브 — 샵 정보 / 서비스 메뉴 분리 진입.
class DirectorProfileEditPage extends StatelessWidget {
  const DirectorProfileEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text(
          '프로필 편집',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: SoriTokens.surface,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text(
            '샵 브랜드 프로필을 관리합니다. 시스템 설정(모드·로그아웃)은 상단 ⚙️에서 변경하세요.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: SoriTokens.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _EditEntryCard(
            icon: Icons.storefront_outlined,
            title: '샵 정보',
            subtitle: '샵 이름 · 원장명 · 소개 · 영업시간 · SNS',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ShopSettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _EditEntryCard(
            icon: Icons.spa_outlined,
            title: '서비스 메뉴',
            subtitle: '케어 라인업 · 고객 안내 문구',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ServiceMenuPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EditEntryCard extends StatelessWidget {
  const _EditEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SoriTokens.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: SoriTokens.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SoriTokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: SoriTokens.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
