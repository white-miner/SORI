import 'package:flutter/material.dart';

import '../routing/app_router.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color soriPurple = SoriTokens.primary;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SORI',
      debugShowCheckedModeBanner: false,
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
      initialRoute: AppRouter.home,
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
    if (err != null && err.isNotEmpty && err != _shownError) {
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
      children: [
        widget.child,
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
