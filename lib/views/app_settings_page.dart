import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/session_user.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../utils/category_presentation_map.dart';
import '../widgets/review_qr_modal.dart';
import 'my_info_edit_page.dart';
import 'shop_settings_page.dart';

/// 앱 시스템 설정 — R4 IA: 계정 → 샵 공개 → 알림 → 앱 환경 → 고급.
/// 모드 전환 toggle은 숨김(셸 결과형 action만).
class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key, this.store});

  final SoriStore? store;

  @override
  Widget build(BuildContext context) {
    final s = store ?? SoriStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final session = s.session;
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('설정')),
            body: const Center(child: Text('로그인이 필요합니다')),
          );
        }
        final isDirector = session.activeMode == UserRole.director;

        return Scaffold(
          backgroundColor: SoriTokens.background,
          appBar: AppBar(
            title: const Text(
              '설정',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            backgroundColor: SoriTokens.surface,
            foregroundColor: SoriTokens.textPrimary,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const _SettingsSectionLabel('계정'),
              _SettingsCard(
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.manage_accounts_outlined,
                      title: '내 계정 정보',
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MyInfoEditPage(),
                          ),
                        );
                      },
                    ),
                    if (isDirector)
                      _SettingsTile(
                        icon: Icons.qr_code_2_rounded,
                        title: '고객 리뷰 QR',
                        onTap: () => showShopReviewQrModal(context, store: s),
                      ),
                    _SettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: '고객센터',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('고객센터 연결 준비 중입니다'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _SettingsSectionLabel('내 샵과 공개'),
              _SettingsCard(
                child: Column(
                  children: [
                    if (isDirector)
                      _SettingsTile(
                        icon: Icons.storefront_outlined,
                        title: '샵 공개 · 프로필',
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ShopSettingsPage(),
                            ),
                          );
                        },
                      )
                    else
                      const ListTile(
                        leading: Icon(
                          Icons.storefront_outlined,
                          color: SoriTokens.primary,
                        ),
                        title: Text(
                          '샵 공개 설정',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('원장 모드에서 관리할 수 있어요'),
                      ),
                    ListTile(
                      leading: const Icon(
                        Icons.info_outline_rounded,
                        color: SoriTokens.textSecondary,
                      ),
                      title: const Text(
                        '모드 전환',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        session.canToggleMode
                            ? '상단 셸의「${isDirector ? CategoryPresentationMap.viewCustomerMode : CategoryPresentationMap.viewDirectorDesk}」에서 전환해요'
                            : '이 계정은 모드 전환이 제한됩니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _SettingsSectionLabel('알림'),
              _SettingsCard(
                child: _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: '알림 수신',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('알림 세부 설정은 준비 중입니다. 종 아이콘에서 확인할 수 있어요.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const _SettingsSectionLabel('앱 환경'),
              _SettingsCard(
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.language_rounded,
                      title: '표시 언어',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('지금은 한국어만 지원해요'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.display_settings_outlined,
                      title: '화면 밀도',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('화면 밀도 설정은 준비 중입니다'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _SettingsSectionLabel('고급'),
              _SettingsCard(
                child: Column(
                  children: [
                    if (kDebugMode)
                      _SettingsTile(
                        icon: Icons.bug_report_outlined,
                        title: '진단 · 디버그',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('개발 빌드 진단은 이 메뉴에서만 열려요'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    _SettingsTile(
                      icon: Icons.payments_outlined,
                      title: '결제 · 정산',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('결제·정산 계약이 준비되면 여기서 열려요'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      title: '로그아웃',
                      danger: true,
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('로그아웃'),
                            content: const Text('이 기기에서 로그아웃할까요?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: SoriTokens.destructive,
                                ),
                                child: const Text('로그아웃'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        s.logout();
                        if (context.mounted) context.go(AppPaths.home);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${session.phone} · ${session.providerLabel}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.03),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? SoriTokens.destructive : SoriTokens.primary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: danger ? SoriTokens.destructive : SoriTokens.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }
}
