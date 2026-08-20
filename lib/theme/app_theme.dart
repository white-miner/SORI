import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sori_date_picker.dart';
import 'sori_tokens.dart';

/// Global dark theme for SORI (black base + purple accents).
abstract final class AppTheme {
  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      seedColor: SoriTokens.primary,
      brightness: Brightness.dark,
      primary: SoriTokens.primary,
      surface: SoriTokens.surface,
      onSurface: SoriTokens.textPrimary,
      onPrimary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base,
      scaffoldBackgroundColor: SoriTokens.background,
      canvasColor: SoriTokens.background,
      cardColor: SoriTokens.surface,
      dividerColor: SoriTokens.border,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: SoriTokens.textPrimary,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SoriTokens.background,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: SoriTokens.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: SoriTokens.surfaceElevated,
        selectedItemColor: SoriTokens.primary,
        unselectedItemColor: SoriTokens.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: SoriTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoriTokens.radiusLg),
          side: const BorderSide(
            color: SoriTokens.outlinePurple,
            width: SoriTokens.outlineWidth,
          ),
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
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: SoriTokens.textPrimary),
        bodyMedium: TextStyle(color: SoriTokens.textPrimary),
        bodySmall: TextStyle(color: SoriTokens.textSecondary),
        titleLarge: TextStyle(color: SoriTokens.textPrimary),
        titleMedium: TextStyle(color: SoriTokens.textPrimary),
        titleSmall: TextStyle(color: SoriTokens.textPrimary),
        labelLarge: TextStyle(color: SoriTokens.textPrimary),
      ),
      datePickerTheme: SoriDatePickerTheme.data,
    );
  }
}
