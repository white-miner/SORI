import 'package:flutter/material.dart';

import '../routing/app_router.dart';
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
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
