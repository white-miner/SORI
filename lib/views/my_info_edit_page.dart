import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/sori_logo.dart';

/// 프로필 관리 (닉네임 · 연락처 · 주소 · SNS 연결 · 탈퇴).
class MyInfoEditPage extends StatefulWidget {
  const MyInfoEditPage({super.key});

  @override
  State<MyInfoEditPage> createState() => _MyInfoEditPageState();
}

class _MyInfoEditPageState extends State<MyInfoEditPage> {
  final _store = SoriStore.instance;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late bool _kakaoLinked;
  late bool _naverLinked;
  late bool _googleLinked;

  @override
  void initState() {
    super.initState();
    final session = _store.session!;
    final customer = session.customerId == null
        ? null
        : _store.findCustomer(session.customerId!);
    _name = TextEditingController(text: session.name);
    _phone = TextEditingController(text: session.phone);
    _address = TextEditingController(text: customer?.address ?? '');
    _kakaoLinked = session.provider == SocialProvider.kakao;
    _naverLinked = session.provider == SocialProvider.naver;
    _googleLinked = session.provider == SocialProvider.google;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닉네임을 입력해 주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _store.updateMyProfile(
      name: name,
      phone: phone,
      address: _address.text.trim(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('프로필이 저장되었어요'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: SoriTokens.primary,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _confirmWithdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
          '탈퇴 시 계정 정보가 삭제되며 복구할 수 없어요. 계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('회원탈퇴는 고객센터를 통해 진행해 주세요'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoriTokens.background,
      appBar: AppBar(
        title: const Text('프로필 관리'),
        backgroundColor: SoriTokens.background,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              '저장',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: SoriTokens.primary,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: SoriTokens.primarySoft,
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: SoriLogo(width: 56, height: 56),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: SoriTokens.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('프로필 사진 변경은 준비 중이에요'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _FieldCard(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '휴대폰 번호',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: '주소',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SNS 계정 연결',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _FieldCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('카카오'),
                  value: _kakaoLinked,
                  activeThumbColor: SoriTokens.primary,
                  onChanged: (v) => setState(() => _kakaoLinked = v),
                ),
                SwitchListTile.adaptive(
                  title: const Text('네이버'),
                  value: _naverLinked,
                  activeThumbColor: SoriTokens.primary,
                  onChanged: (v) => setState(() => _naverLinked = v),
                ),
                SwitchListTile.adaptive(
                  title: const Text('Google'),
                  value: _googleLinked,
                  activeThumbColor: SoriTokens.primary,
                  onChanged: (v) => setState(() => _googleLinked = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          TextButton(
            onPressed: _confirmWithdraw,
            child: const Text(
              '회원탈퇴',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: SoriTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoriTokens.outlinePurple),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
