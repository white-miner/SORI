import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../routing/app_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import '../widgets/app_scroll_behavior.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color soriPurple = SoriTokens.primary;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '소통하는 리뷰, SORI',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: SoriTokens.primary,
          primary: SoriTokens.primary,
          surface: SoriTokens.surface,
        ),
        scaffoldBackgroundColor: SoriTokens.background,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: SoriTokens.surface,
          foregroundColor: SoriTokens.textPrimary,
          elevation: 0,
          centerTitle: false,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: SoriTokens.surface,
          selectedItemColor: SoriTokens.primary,
          unselectedItemColor: SoriTokens.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        cardTheme: CardThemeData(
          color: SoriTokens.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SoriTokens.radiusLg),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: SoriTokens.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return _StoreErrorHost(child: child ?? const SizedBox.shrink());
      },
      initialRoute: AppRouter.resolveInitialRoute(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

/// Store의 lastError / isLoading을 SnackBar로 노출.
class _StoreErrorHost extends StatefulWidget {
  const _StoreErrorHost({required this.child});

  final Widget child;

  @override
  State<_StoreErrorHost> createState() => _StoreErrorHostState();
}

class _StoreErrorHostState extends State<_StoreErrorHost> {
  final _store = SoriStore.instance;
  String? _shownError;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    final err = _store.lastError;
    if (err != null &&
        err.isNotEmpty &&
        err != _shownError &&
        !SoriStore.isNonFatalRemoteNoise(err)) {
      _shownError = err;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: '닫기',
              textColor: Colors.white,
              onPressed: () => _store.clearError(),
            ),
          ),
        );
        _store.clearError();
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_store.bootstrapFailed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: const Color(0xFFFFF4E5),
              elevation: 2,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: SoriTokens.warningText,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '서버 연결에 실패했어요. 네트워크를 확인한 뒤 다시 시도해 주세요.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SoriTokens.warningText,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _store.isLoading
                            ? null
                            : () async {
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                await _store.retryBootstrap();
                                if (!mounted) return;
                                if (!_store.bootstrapFailed) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('연결이 복구되었어요'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: SoriTokens.primary,
                                    ),
                                  );
                                }
                              },
                        child: const Text(
                          '다시 시도',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: SoriTokens.warningText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_store.isLoading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: SoriTokens.primary,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}
