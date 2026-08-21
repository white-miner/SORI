import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';
import '../models/customer_chart.dart';
import '../services/pending_review_return.dart';
import '../services/sori_auth_service.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'ikea_review_composer_page.dart';

/// 고객용 독립 모바일 웹 (`/#/review?token=...`).
/// 카카오 로그인 후 이케아형 AI 리뷰 컴포저로 직행합니다.
class CustomerReviewPage extends StatefulWidget {
  const CustomerReviewPage({
    super.key,
    required this.store,
    required this.token,
  });

  final SoriStore store;
  final String token;

  @override
  State<CustomerReviewPage> createState() => _CustomerReviewPageState();
}

class _CustomerReviewPageState extends State<CustomerReviewPage> {
  final _auth = SoriAuthService.instance;
  StreamSubscription<AuthState>? _authSub;
  bool _busy = false;
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    final token = widget.token.trim();
    if (token.isNotEmpty) PendingReviewReturn.save(token);
    widget.store.addListener(_onStoreChanged);
    _authSub = _auth.onAuthStateChange.listen(_onAuthState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrateIfNeeded());
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _onAuthState(AuthState data) {
    final session = data.session;
    if (session == null) {
      if (mounted) setState(() {});
      return;
    }
    if (data.event == AuthChangeEvent.signedIn ||
        data.event == AuthChangeEvent.initialSession ||
        data.event == AuthChangeEvent.tokenRefreshed) {
      unawaited(_hydrateIfNeeded());
    }
  }

  bool get _isSignedIn =>
      _auth.currentSession != null || widget.store.session != null;

  CustomerChart? get _chart => widget.store.findChartByToken(widget.token);

  Customer? get _customer {
    final chart = _chart;
    if (chart == null) return null;
    return widget.store.findCustomer(chart.customerId);
  }

  Future<void> _hydrateIfNeeded() async {
    if (_hydrating || !mounted) return;
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() {});
      return;
    }
    _hydrating = true;
    try {
      await widget.store.hydrateSessionFromAuth(user);
    } catch (e) {
      debugPrint('review hydrate skipped: $e');
    } finally {
      _hydrating = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _kakaoLogin() async {
    if (_busy) return;
    setState(() => _busy = true);
    final token = widget.token.trim();
    try {
      PendingReviewReturn.save(token);
      await _auth.signInWithKakao(reviewToken: token);
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

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    final customer = _customer;

    if (widget.token.trim().isEmpty || chart == null || customer == null) {
      return const Scaffold(
        backgroundColor: SoriTokens.background,
        body: Center(child: Text('유효하지 않은 고객 링크입니다')),
      );
    }

    if (_isSignedIn) {
      return Scaffold(
        backgroundColor: SoriTokens.background,
        body: IkeaReviewComposerPage(
          store: widget.store,
          chart: chart,
        ),
      );
    }

    return Scaffold(
      backgroundColor: SoriTokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text(
                '${customer.name}님,',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SoriTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '카카오 로그인 후\n오늘 케어 후기를 바로 작성해요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: SoriTokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 3),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: SoriTokens.primary),
                  ),
                ),
              SizedBox(
                height: 54,
                child: Material(
                  color: const Color(0xFFFEE500),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _busy ? null : _kakaoLogin,
                    borderRadius: BorderRadius.circular(14),
                    child: const Center(
                      child: Text(
                        '카카오로 1초 로그인',
                        style: TextStyle(
                          color: Color(0xFF191919),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '로그인 후 AI 후기 작성으로 바로 이동합니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: SoriTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
