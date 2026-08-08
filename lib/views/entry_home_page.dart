import 'package:flutter/material.dart';

import '../routing/app_router.dart';
import '../services/sori_store.dart';
import 'my_app.dart';
import 'shop_settings_page.dart';

/// 단일 엔트리 홈: 원장 / 고객 진입 분리.
class EntryHomePage extends StatefulWidget {
  const EntryHomePage({super.key, this.initialToken});

  final String? initialToken;

  @override
  State<EntryHomePage> createState() => _EntryHomePageState();
}

class _EntryHomePageState extends State<EntryHomePage> {
  final _store = SoriStore.instance;

  @override
  void initState() {
    super.initState();
    final token = widget.initialToken?.trim();
    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '${AppRouter.review}?token=${Uri.encodeQueryComponent(token)}',
        );
      });
    }
  }

  Future<void> _startDirector() async {
    final result = await _showAuthDialog(
      title: '원장님으로 시작하기',
      subtitle: '이름과 연락처로 간편 로그인합니다.',
    );
    if (result == null || !mounted) return;

    _store.loginDirector(name: result.$1, phone: result.$2);

    if (!_store.shop.hasNaverPlace) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ShopSettingsPage(requireNaver: true),
        ),
      );
      if (!_store.shop.hasNaverPlace) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('네이버 플레이스 URL을 등록해야 원장 모드를 사용할 수 있습니다.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRouter.admin);
  }

  Future<void> _startCustomer() async {
    final result = await _showAuthDialog(
      title: '고객 1:1 피부 일지',
      subtitle: '이름·전화번호로 시술 차트와 자동 매칭됩니다.',
    );
    if (result == null || !mounted) return;

    final session = _store.loginCustomer(name: result.$1, phone: result.$2);
    final charts = _store.chartsForCustomer(session.customerId!);
    final openCharts = charts.where((c) => c.hasFeedbackLine).toList();

    if (!mounted) return;

    if (openCharts.isNotEmpty) {
      final token = openCharts.first.feedbackToken!;
      Navigator.of(context).pushReplacementNamed(
        '${AppRouter.review}?token=${Uri.encodeQueryComponent(token)}',
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${session.name}님, 매칭된 시술 차트를 확인했습니다. '
          '원장님이 방문 확인 후 보내 준 링크로 후기를 작성할 수 있어요.',
        ),
        backgroundColor: MyApp.soriPurple,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<(String, String)?> _showAuthDialog({
    required String title,
    required String subtitle,
  }) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '이름 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '전화번호 *',
                    hintText: '010-0000-0000',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    SoriStore.normalizePhone(phoneController.text).length < 10) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(backgroundColor: MyApp.soriPurple),
              child: const Text('시작하기'),
            ),
          ],
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
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: MyApp.soriPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'SORI',
                  style: TextStyle(
                    color: MyApp.soriPurple,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '소리와 함께\n오늘의 피부 여정을\n이어가세요',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.35,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'B2B 에스테틱 1:1 CRM · 시술 차트와 후기 소통을 한곳에서',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _startDirector,
                  style: FilledButton.styleFrom(
                    backgroundColor: MyApp.soriPurple,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '원장님으로 시작하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _startCustomer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MyApp.soriPurple,
                    side: const BorderSide(color: MyApp.soriPurple, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '고객 1:1 피부 일지',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
