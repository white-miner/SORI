import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/session_user.dart';
import '../routing/app_router.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';
import 'my_app.dart';
import 'onboarding_page.dart';

/// 공통 랜딩: 이메일 매직 링크 + 카카오 OAuth.
class EntryHomePage extends StatefulWidget {
  const EntryHomePage({super.key, this.initialToken});

  final String? initialToken;

  @override
  State<EntryHomePage> createState() => _EntryHomePageState();
}

class _EntryHomePageState extends State<EntryHomePage>
    with SingleTickerProviderStateMixin {
  final _store = SoriStore.instance;
  final _auth = SoriAuthService.instance;
  final _emailController = TextEditingController();
  late final AnimationController _fade;
  StreamSubscription<AuthState>? _authSub;
  bool _busy = false;
  bool _handlingAuth = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    final token = widget.initialToken?.trim();
    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '${AppRouter.review}?token=${Uri.encodeQueryComponent(token)}',
        );
      });
      return;
    }

    _authSub = _auth.onAuthStateChange.listen(_onAuthState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = _auth.currentSession;
      if (session != null) {
        unawaited(_handleSignedIn(session.user));
        return;
      }
      final local = _store.session;
      if (local != null && local.onboardingComplete) {
        Navigator.of(context).pushReplacementNamed(AppRouter.app);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _onAuthState(AuthState data) {
    final event = data.event;
    final session = data.session;
    if (session == null) return;
    if (event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.initialSession) {
      unawaited(_handleSignedIn(session.user));
    }
  }

  Future<void> _handleSignedIn(User user) async {
    if (_handlingAuth || !mounted) return;
    _handlingAuth = true;
    try {
      final sessionUser = _store.syncFromAuthUser(user);
      if (!mounted) return;

      if (sessionUser.onboardingComplete) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.app,
          (_) => false,
        );
        return;
      }

      if (sessionUser.needsProfileCompletion) {
        final profile = await _collectProfile(sessionUser.provider);
        if (!mounted) return;
        if (profile == null) {
          // 프로필 미완료 시에도 온보딩으로 진행 (이름만이라도)
          if (_store.session?.name.trim().isEmpty == true) {
            _store.updateSessionProfile(
              name: SoriAuthService.displayNameFromUser(user).isEmpty
                  ? '소리 회원'
                  : SoriAuthService.displayNameFromUser(user),
              phone: _store.session?.phone ?? '',
            );
          }
        } else {
          _store.updateSessionProfile(name: profile.$1, phone: profile.$2);
        }
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } finally {
      _handlingAuth = false;
    }
  }

  Future<void> _sendMagicLink() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일 주소를 입력해 주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await _auth.signInWithEmailOtp(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('입력하신 이메일로 로그인 링크를 보냈습니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: MyApp.soriPurple,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인 링크 발송에 실패했어요: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _kakaoLogin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _auth.signInWithKakao();
      // 웹/앱은 OAuth 리다이렉트 후 onAuthStateChange로 이어짐
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('카카오 로그인에 실패했어요: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(String, String)?> _collectProfile(SocialProvider provider) async {
    final nameController = TextEditingController(
      text: _store.session?.name ?? '',
    );
    final phoneController = TextEditingController(
      text: _store.session?.phone.isNotEmpty == true
          ? _store.session!.phone
          : '',
    );

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${provider == SocialProvider.kakao ? '카카오' : '이메일'} 로그인',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '소통하는 리뷰를 위해 이름과 전화번호를 확인해 주세요.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '이름 *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '전화번호 *',
                  hintText: '010-0000-0000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty ||
                        SoriStore.normalizePhone(phoneController.text).length <
                            10) {
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MyApp.soriPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('계속하기'),
                ),
              ),
            ],
          ),
        );
      },
    );

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    nameController.dispose();
    phoneController.dispose();
    if (ok == true) return (name, phone);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEDE9FE), Color(0xFFF8F7FC), Colors.white],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '소통하는 리뷰, SORI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '에스테틱 원장과 고객이 시술 차트와 후기로\n1:1 소통하는 CRM',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMagicLink(),
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: '이메일 주소',
                      hintText: 'you@example.com',
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _sendMagicLink,
                      style: FilledButton.styleFrom(
                        backgroundColor: MyApp.soriPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '이메일 링크로 시작하기',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_busy)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: CircularProgressIndicator(
                          color: MyApp.soriPurple,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '또는',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SocialButton(
                    label: '카카오로 시작하기',
                    background: const Color(0xFFFEE500),
                    foreground: const Color(0xFF191919),
                    onTap: _busy ? () {} : _kakaoLogin,
                  ),
                  // 네이버 / Google / Apple — 베타에서는 비활성
                  // _SocialButton(label: '네이버로 시작하기', ...),
                  // _SocialButton(label: 'Google로 시작하기', ...),
                  // _SocialButton(label: 'Apple로 시작하기', ...),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      '로그인 시 이용약관·개인정보 처리에 동의하게 됩니다',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
