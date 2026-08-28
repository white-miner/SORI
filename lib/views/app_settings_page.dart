import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/session_user.dart';
import '../routing/sori_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/review_qr_modal.dart';
import 'my_info_edit_page.dart';

/// 앱 시스템 설정 — 모드 토글 · 로그아웃 · 계정 (마이 프로필과 분리).
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
              const _SettingsSectionLabel('모드'),
              _SettingsCard(
                child: Column(
                  children: [
                    if (session.canToggleMode)
                      SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
                        secondary: const Icon(
                          Icons.swap_horiz_rounded,
                          color: SoriTokens.primary,
                        ),
                        title: Text(
                          isDirector ? '원장 모드' : '고객 모드',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          isDirector
                              ? '고객 모드로 전환하면 팔로워 홈을 볼 수 있어요'
                              : '원장 모드로 전환하면 샵 관리 대시보드를 열어요',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        value: isDirector,
                        activeThumbColor: SoriTokens.primary,
                        onChanged: (_) {
                          s.toggleActiveMode();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isDirector ? '고객 모드로 전환' : '원장 모드로 전환',
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: SoriTokens.primary,
                            ),
                          );
                        },
                      )
                    else
                      ListTile(
                        leading: const Icon(
                          Icons.lock_outline_rounded,
                          color: SoriTokens.primary,
                        ),
                        title: Text(
                          isDirector ? '원장 모드' : '고객 모드',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text('이 계정은 모드 전환이 제한됩니다'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
              const _SettingsSectionLabel('세션'),
              _SettingsCard(
                child: _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: '로그아웃',
                  danger: true,
                  onTap: () {
                    s.logout();
                    context.go(AppPaths.home);
                  },
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
    return ListTile(
      leading: Icon(
        icon,
        color: danger ? SoriTokens.systemRed : SoriTokens.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: danger ? SoriTokens.systemRed : SoriTokens.textPrimary,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }
}
